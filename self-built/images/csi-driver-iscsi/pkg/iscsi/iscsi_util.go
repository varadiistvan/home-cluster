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
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	iscsiLib "github.com/kubernetes-csi/csi-driver-iscsi/pkg/iscsilib"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	klog "k8s.io/klog/v2"

	"k8s.io/utils/mount"
)

type ISCSIUtil struct{}

func (util *ISCSIUtil) AttachDisk(b iscsiDiskMounter) (string, error) {
	if b.connector == nil {
		return "", fmt.Errorf("connector is nil")
	}

	devicePath, err := (*b.connector).Connect()
	if err != nil {
		return "", err
	}
	if devicePath == "" {
		return "", fmt.Errorf("connect reported success, but no path returned")
	}
	// Mount device
	mntPath := b.targetPath
	notMnt, err := b.mounter.IsLikelyNotMountPoint(mntPath)
	if err != nil && !os.IsNotExist(err) {
		return "", fmt.Errorf("heuristic determination of mount point failed:%v", err)
	}
	if !notMnt {
		klog.Infof("iscsi: %s already mounted", mntPath)
		return "", nil
	}

	if err := os.MkdirAll(mntPath, 0o750); err != nil {
		klog.Errorf("iscsi: failed to mkdir %s, error", mntPath)
		return "", err
	}

	// Persist iscsi disk config to json file for DetachDisk path
	iscsiInfoPath := getIscsiInfoPath(b.VolName)
	err = iscsiLib.PersistConnector(b.connector, iscsiInfoPath)
	if err != nil {
		klog.Errorf("failed to persist connection info: %v, disconnecting volume and failing the publish request because persistence files are required for reliable Unpublish", err)
		return "", fmt.Errorf("unable to create persistence file for connection")
	}

	var options []string

	if b.readOnly {
		options = append(options, "ro")
	} else {
		options = append(options, "rw")
	}
	options = append(options, b.mountOptions...)

	err = b.mounter.FormatAndMount(devicePath, mntPath, b.fsType, options)
	if err != nil {
		klog.Errorf("iscsi: failed to mount iscsi volume %s [%s] to %s, error %v", devicePath, b.fsType, mntPath, err)
	}

	return devicePath, err
}

func (util *ISCSIUtil) DetachDisk(c iscsiDiskUnmounter, targetPath string) error {
	// If path doesn't exist, nothing to do.
	if pathExists, err := mount.PathExists(targetPath); err != nil {
		return fmt.Errorf("error checking if path exists: %v", err)
	} else if !pathExists {
		klog.Warningf("warning: Unmount skipped because path does not exist: %v", targetPath)
		return nil
	}

	// Get current ref count before unmount.
	_, cnt, err := mount.GetDeviceNameFromMount(c.mounter, targetPath)
	if err != nil {
		klog.Errorf("iscsi detach disk: failed to get device from mnt: %s\nError: %v", targetPath, err)
		return err
	}

	// Unmount (lazy on EBUSY).
	if err := c.mounter.Unmount(targetPath); err != nil {
		// Handle "device or resource busy"
		if errors.Is(err, syscall.EBUSY) || strings.Contains(err.Error(), "device or resource busy") {
			_ = exec.Command("umount", "-l", targetPath).Run()
		} else {
			klog.Errorf("iscsi detach disk: failed to unmount: %s\nError: %v", targetPath, err)
			return err
		}
	}

	// Wait briefly for refs to drop.
	for i := 0; i < 5 && cnt > 0; i++ {
		time.Sleep(1 * time.Second)
		_, cnt2, _ := mount.GetDeviceNameFromMount(c.mounter, targetPath)
		cnt = cnt2
	}

	// Try to load connector state (now persisted under /var/lib/iscsi-csi).
	iscsiInfoPath := getIscsiInfoPath(c.VolName)
	klog.Infof("loading ISCSI connection info from %s", iscsiInfoPath)
	connector, cerr := iscsiLib.GetConnectorFromFile(iscsiInfoPath)
	if cerr != nil {
		if errors.Is(cerr, os.ErrNotExist) {
			// Pod/plugin probably restarted and we lost the JSON.
			// Best-effort: logout & delete DB entry by IQN.
			klog.Warningf("connector state missing, attempting best-effort logout for %s", c.VolName)
			_ = bestEffortLogoutByIQN(c.VolName)
		} else {
			return status.Error(codes.Internal, cerr.Error())
		}
	} else {
		klog.Info("detaching ISCSI device")
		if err := connector.DisconnectVolume(); err != nil {
			klog.Errorf("iscsi detach disk: failed to disconnect volume Error: %v", err)
			return err
		}
		iscsiLib.Disconnect(connector.TargetIqn, connector.TargetPortals)
	}

	// Robust mountpoint cleanup (removes dir if safe).
	if err := mount.CleanupMountPoint(targetPath, c.mounter, false); err != nil {
		return fmt.Errorf("cleanup mountpoint failed: %w", err)
	}

	// Remove connector file (ignore if already gone).
	if err := os.Remove(iscsiInfoPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}

	klog.Info("successfully detached ISCSI device")
	return nil
}

func getIscsiInfoPath(volumeID string) string {
	return fmt.Sprintf("%s/iscsi-%s.json", stateDir(), volumeID)
}

func bestEffortLogoutByIQN(iqn string) error {
	// Enumerate all node records for this IQN and logout/delete.
	// iscsiadm -m node -T <iqn> prints entries for each portal.
	cmd := exec.Command("iscsiadm", "-m", "node", "-T", iqn)
	out, err := cmd.CombinedOutput()
	if err != nil && !strings.Contains(string(out), "No records found") {
		return err
	}
	lines := strings.SplitSeq(string(out), "\n")
	for ln := range lines {
		// lines typically contain: <ip>:<port>,<tpgt> <iqn>
		fields := strings.Fields(strings.TrimSpace(ln))
		if len(fields) < 1 {
			continue
		}
		portal := strings.Split(fields[0], ",")[0]
		_ = exec.Command("iscsiadm", "-m", "node", "-T", iqn, "-p", portal, "-u").Run()
	}
	// Delete the node db entry for IQN
	_ = exec.Command("iscsiadm", "-m", "node", "-T", iqn, "-o", "delete").Run()
	return nil
}
