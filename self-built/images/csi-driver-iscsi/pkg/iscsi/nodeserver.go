/*
Copyright 2017 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package iscsi

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/container-storage-interface/spec/lib/go/csi"
	iscsiLib "github.com/kubernetes-csi/csi-driver-iscsi/pkg/iscsilib"
	"golang.org/x/net/context"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	klog "k8s.io/klog/v2"
	"k8s.io/mount-utils"
	utilexec "k8s.io/utils/exec"
)

type nodeServer struct {
	Driver *driver
	csi.UnimplementedNodeServer
}

func (ns *nodeServer) NodePublishVolume(ctx context.Context, req *csi.NodePublishVolumeRequest) (*csi.NodePublishVolumeResponse, error) {
	if req.GetVolumeCapability() == nil {
		return nil, status.Error(codes.InvalidArgument, "volume capability missing in request")
	}
	if len(req.GetVolumeId()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "volumeID missing in request")
	}
	if len(req.GetTargetPath()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "targetPath not provided")
	}

	iscsiInfo, err := getISCSIInfo(req)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	diskMounter := getISCSIDiskMounter(iscsiInfo, req)

	util := &ISCSIUtil{}
	if _, err := util.AttachDisk(*diskMounter); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &csi.NodePublishVolumeResponse{}, nil
}

func (ns *nodeServer) NodeUnpublishVolume(ctx context.Context, req *csi.NodeUnpublishVolumeRequest) (*csi.NodeUnpublishVolumeResponse, error) {
	if len(req.GetVolumeId()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
	}
	targetPath := req.GetTargetPath()
	if len(targetPath) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Target path not provided")
	}

	diskUnmounter := getISCSIDiskUnmounter(req)

	iscsiutil := &ISCSIUtil{}
	if err := iscsiutil.DetachDisk(*diskUnmounter, targetPath); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &csi.NodeUnpublishVolumeResponse{}, nil
}

func (ns *nodeServer) NodeUnstageVolume(ctx context.Context, req *csi.NodeUnstageVolumeRequest) (*csi.NodeUnstageVolumeResponse, error) {
	return &csi.NodeUnstageVolumeResponse{}, nil
}

func (ns *nodeServer) NodeStageVolume(ctx context.Context, req *csi.NodeStageVolumeRequest) (*csi.NodeStageVolumeResponse, error) {
	return &csi.NodeStageVolumeResponse{}, nil
}

func (ns *nodeServer) NodeGetInfo(ctx context.Context, req *csi.NodeGetInfoRequest) (*csi.NodeGetInfoResponse, error) {
	return &csi.NodeGetInfoResponse{
		NodeId: ns.Driver.nodeID,
	}, nil
}

func (ns *nodeServer) NodeGetCapabilities(ctx context.Context, req *csi.NodeGetCapabilitiesRequest) (*csi.NodeGetCapabilitiesResponse, error) {
	return &csi.NodeGetCapabilitiesResponse{
		Capabilities: []*csi.NodeServiceCapability{
			{
				Type: &csi.NodeServiceCapability_Rpc{
					Rpc: &csi.NodeServiceCapability_RPC{
						Type: csi.NodeServiceCapability_RPC_EXPAND_VOLUME,
					},
				},
			},
		},
	}, nil
}

func (ns *nodeServer) NodeGetVolumeStats(ctx context.Context, in *csi.NodeGetVolumeStatsRequest) (*csi.NodeGetVolumeStatsResponse, error) {
	return nil, status.Error(codes.Unimplemented, "")
}

func (ns *nodeServer) NodeExpandVolume(ctx context.Context, req *csi.NodeExpandVolumeRequest) (*csi.NodeExpandVolumeResponse, error) {
	volID := req.GetVolumeId()
	volPath := req.GetVolumePath()
	if volID == "" || volPath == "" {
		return nil, status.Error(codes.InvalidArgument, "volume_id and volume_path are required")
	}

	// 1) Resolve the device that backs volPath
	m := mount.New("")
	devicePath, _, err := mount.GetDeviceNameFromMount(m, volPath)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "get device from mount %q: %v", volPath, err)
	}
	if devicePath == "" {
		return nil, status.Errorf(codes.Internal, "no device found for %q", volPath)
	}

	path := req.GetVolumePath()
	if st := req.GetStagingTargetPath(); st != "" {
		if ok, _ := mount.PathExists(st); ok {
			path = st
		}
	}
	dev, _, err := mount.GetDeviceNameFromMount(m, path)

	// 2) Best-effort rescan so the kernel sees the larger LUN
	before, _ := getSizeBytes(dev)
	_ = fullRescanForVolume(dev, req.GetVolumeId()) // see impl below
	_ = utilexec.New().Command("udevadm", "settle").Run()
	after, _ := getSizeBytes(dev)
	klog.Infof("expand %s: size before=%d after=%d want>=%d", dev, before, after, req.GetCapacityRange().GetRequiredBytes())

	// 3) Resize the filesystem using k8s mount-utils (handles ext and xfs)
	resizer := mount.NewResizeFs(utilexec.New())
	need, err := resizer.NeedResize(devicePath, volPath)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "NeedResize(%s,%s): %v", devicePath, volPath, err)
	}
	if need {
		if _, err := resizer.Resize(devicePath, volPath); err != nil {
			return nil, status.Errorf(codes.Internal, "Resize(%s,%s): %v", devicePath, volPath, err)
		}
	}

	// 4) (Optional) report final size
	capBytes, _ := getSizeBytes(devicePath)
	return &csi.NodeExpandVolumeResponse{CapacityBytes: capBytes}, nil
}

// --- helpers ---

func fullRescanForVolume(devPath, volID string) error {
	// 1) Use connector for this vol to rescan sessions + by-path device(s)
	if conn, err := iscsiLib.GetConnectorFromFile(getIscsiInfoPath(volID)); err == nil {
		// Start from the struct's list
		portals := append([]string(nil), conn.TargetPortals...)

		// If the connector had no portals, derive from /dev/disk/by-path
		if len(portals) == 0 && conn.TargetIqn != "" {
			pattern := fmt.Sprintf("/dev/disk/by-path/ip-*-iscsi-%s-lun-%d", conn.TargetIqn, conn.Lun)
			matches, _ := filepath.Glob(pattern)
			for _, by := range matches {
				base := filepath.Base(by) // ip-<portal>-iscsi-<iqn>-lun-<lun>
				// extract <portal> between "ip-" and "-iscsi-"
				const prefix = "ip-"
				const sep = "-iscsi-"
				if strings.HasPrefix(base, prefix) {
					rest := strings.TrimPrefix(base, prefix)
					if i := strings.Index(rest, sep); i > 0 {
						portals = append(portals, rest[:i]) // e.g. "10.0.0.1:3260"
					}
				}
				if real, e := filepath.EvalSymlinks(by); e == nil {
					_ = rescanBlockDevice(real) // also rescan the exact sdX backing this path
				}
			}
		}

		// De-dupe and rescan each portal for this IQN
		seen := map[string]struct{}{}
		for _, p := range portals {
			if p == "" {
				continue
			}
			if _, ok := seen[p]; ok {
				continue
			}
			seen[p] = struct{}{}
			_ = utilexec.New().Command("iscsiadm", "-m", "node", "-T", conn.TargetIqn, "-p", p, "--rescan").Run()
		}
	}

	// 2) Generic rescan of the actual device and its slaves
	_ = rescanBlockDevice(devPath)

	// 3) If multipath, resize only that map
	if real, _ := filepath.EvalSymlinks(devPath); strings.HasPrefix(filepath.Base(real), "dm-") {
		name := readTrim("/sys/class/block/" + filepath.Base(real) + "/dm/name")
		if name != "" {
			_ = utilexec.New().Command("multipathd", "-k", "resize map "+name).Run()
		}
		_ = utilexec.New().Command("multipath", "-r").Run()
	}
	return nil
}

func rescanBlockDevice(devPath string) error {
	real, _ := filepath.EvalSymlinks(devPath)
	base := filepath.Base(real)

	// If partition, find parent via sysfs (don’t guess by trimming digits)
	parent := base
	if _, err := os.Stat("/sys/class/block/" + base + "/partition"); err == nil {
		link, _ := filepath.EvalSymlinks("/sys/class/block/" + base)
		parent = filepath.Base(filepath.Dir(link))
	}

	// Per-disk rescan
	_ = os.WriteFile("/sys/class/block/"+parent+"/device/rescan", []byte("1\n"), 0o200)

	// If dm-*, rescan all slaves too
	if strings.HasPrefix(base, "dm-") {
		entries, _ := os.ReadDir("/sys/class/block/" + base + "/slaves")
		for _, e := range entries {
			_ = os.WriteFile("/sys/class/block/"+e.Name()+"/device/rescan", []byte("1\n"), 0o200)
		}
	}
	return nil
}

func readTrim(p string) string {
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func getSizeBytes(devPath string) (int64, error) {
	// You can call `blockdev --getsize64` via utilexec or read /sys/class/block/<dev>/size * 512.
	real, err := filepath.EvalSymlinks(devPath)
	if err != nil {
		real = devPath
	}
	base := filepath.Base(real)
	data, err := os.ReadFile(fmt.Sprintf("/sys/class/block/%s/size", base))
	if err != nil {
		return 0, err
	}
	// sectors * 512
	var sectors int64
	fmt.Sscanf(string(data), "%d", &sectors)
	return sectors * 512, nil
}
