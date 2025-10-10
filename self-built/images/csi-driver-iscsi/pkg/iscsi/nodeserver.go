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
	"golang.org/x/net/context"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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

	// 2) Best-effort rescan so the kernel sees the larger LUN
	_ = rescanDevice(devicePath) // ignore error; resizefs will fail if truly not bigger

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

func rescanDevice(devPath string) error {
	// Follow symlinks: /dev/disk/by-id/… -> /dev/sdX or /dev/dm-*
	real, err := filepath.EvalSymlinks(devPath)
	if err != nil {
		real = devPath
	}
	base := filepath.Base(real)

	// If this is a partition (e.g., sdb1), rescan the parent (sdb).
	// For simplicity, avoid partitions in your design if you can.
	parent := base
	if strings.HasPrefix(base, "sd") || strings.HasPrefix(base, "vd") || strings.HasPrefix(base, "xvd") {
		// crude partition detection: sdX1 -> sdX
		parent = strings.TrimRightFunc(base, func(r rune) bool { return r >= '0' && r <= '9' })
	}

	// /sys/class/block/<dev>/device/rescan
	p := fmt.Sprintf("/sys/class/block/%s/device/rescan", parent)
	return os.WriteFile(p, []byte("1\n"), 0o200)
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
