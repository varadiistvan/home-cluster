package main

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/container-storage-interface/spec/lib/go/csi"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// IdentityServer implements the CSI Identity service.
type IdentityServer struct {
	csi.UnimplementedIdentityServer // <<< FIX: Embed the unimplemented server
	name                            string
	version                         string
}

func NewIdentityServer(name, version string) *IdentityServer {
	return &IdentityServer{
		name:    name,
		version: version,
	}
}

func (s *IdentityServer) GetPluginInfo(ctx context.Context, req *csi.GetPluginInfoRequest) (*csi.GetPluginInfoResponse, error) {
	return &csi.GetPluginInfoResponse{
		Name:          s.name,
		VendorVersion: s.version,
	}, nil
}

func (s *IdentityServer) GetPluginCapabilities(ctx context.Context, req *csi.GetPluginCapabilitiesRequest) (*csi.GetPluginCapabilitiesResponse, error) {
	return &csi.GetPluginCapabilitiesResponse{
		Capabilities: []*csi.PluginCapability{
			{
				Type: &csi.PluginCapability_Service_{
					Service: &csi.PluginCapability_Service{
						Type: csi.PluginCapability_Service_CONTROLLER_SERVICE,
					},
				},
			},
		},
	}, nil
}

func (s *IdentityServer) Probe(ctx context.Context, req *csi.ProbeRequest) (*csi.ProbeResponse, error) {
	return &csi.ProbeResponse{}, nil
}

// ControllerServer implements the CSI Controller service.
type ControllerServer struct {
	apiClient *ApiClient
	csi.UnimplementedControllerServer
}

func NewControllerServer(client *ApiClient) *ControllerServer {
	return &ControllerServer{
		apiClient: client,
	}
}

// CreateVolume is called by Kubernetes to provision a new volume.
func (s *ControllerServer) CreateVolume(ctx context.Context, req *csi.CreateVolumeRequest) (*csi.CreateVolumeResponse, error) {
	// 1. Validate request arguments.
	volumeName := req.GetName()
	if volumeName == "" {
		return nil, status.Error(codes.InvalidArgument, "Volume name is required")
	}
	if req.GetVolumeCapabilities() == nil {
		return nil, status.Error(codes.InvalidArgument, "Volume capabilities are required")
	}
	sizeBytes := req.GetCapacityRange().GetRequiredBytes()
	if sizeBytes == 0 {
		sizeBytes = 1 * 1024 * 1024 * 1024 // Default to 1 GiB if not specified.
	}

	// 2. Extract parameters from the StorageClass.
	params := req.GetParameters()
	allowedCIDR := params["allowedCIDR"]
	if allowedCIDR == "" {
		return nil, status.Error(codes.InvalidArgument, "'allowedCIDR' is a required StorageClass parameter")
	}
	iscsiServerAddress := params["iscsiServerAddress"]
	if iscsiServerAddress == "" {
		return nil, status.Error(codes.InvalidArgument, "'iscsiServerAddress' is a required StorageClass parameter")
	}

	// 3. Call your API server to provision the LUN.
	log.Printf("Requesting LUN creation for volume %s", volumeName)
	createReq := CreateLunRequest{
		TargetName: volumeName,
		SizeBytes:  sizeBytes,
		Initiator:  allowedCIDR,
	}

	apiResp, err := s.apiClient.CreateLun(createReq)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "Failed to provision LUN via API: %v", err)
	}

	fullTargetPortal := fmt.Sprintf("%s:%s", iscsiServerAddress, apiResp.TargetPortal)
	log.Printf("Constructed full target portal: %s", fullTargetPortal)

	// 4. Construct the response for Kubernetes.
	// This context is passed directly to the node plugin (`csi-driver-iscsi`).
	volumeContext := map[string]string{
		"targetPortal": fullTargetPortal,
		"iqn":          apiResp.TargetName, // Use the IQN returned by your server
		"portals":      "[]",               // Can be left empty
		"lun":          "1",
		"fsType":       params["fsType"],
	}

	return &csi.CreateVolumeResponse{
		Volume: &csi.Volume{
			VolumeId:      apiResp.TargetName, // The unique ID for this volume is its IQN
			CapacityBytes: sizeBytes,
			VolumeContext: volumeContext,
		},
	}, nil
}

// DeleteVolume is called by Kubernetes to deprovision a volume.
func (s *ControllerServer) DeleteVolume(ctx context.Context, req *csi.DeleteVolumeRequest) (*csi.DeleteVolumeResponse, error) {
	volumeID := req.GetVolumeId() // This will be the full IQN, e.g., "iqn.pvc-1234"
	if volumeID == "" {
		return nil, status.Error(codes.InvalidArgument, "Volume ID is required")
	}

	// Your server expects the base name, so we strip the "iqn." prefix.
	baseTargetName := strings.TrimPrefix(volumeID, "iqn.")

	log.Printf("Requesting LUN deletion for volume %s (base name: %s)", volumeID, baseTargetName)
	deleteReq := DeleteLunRequest{
		TargetName:  baseTargetName,
		DeleteStore: true, // This can be made configurable via StorageClass if needed.
	}

	if err := s.apiClient.DeleteLun(deleteReq); err != nil {
		// Don't return an error if the volume is already gone.
		if strings.Contains(err.Error(), "not found") {
			log.Printf("Volume %s already deleted on backend.", volumeID)
			return &csi.DeleteVolumeResponse{}, nil
		}
		return nil, status.Errorf(codes.Internal, "Failed to delete LUN via API: %v", err)
	}

	return &csi.DeleteVolumeResponse{}, nil
}

// ControllerExpandVolume is called to resize a volume.
func (s *ControllerServer) ControllerExpandVolume(ctx context.Context, req *csi.ControllerExpandVolumeRequest) (*csi.ControllerExpandVolumeResponse, error) {
	volumeID := req.GetVolumeId() // Full IQN
	if volumeID == "" {
		return nil, status.Error(codes.InvalidArgument, "Volume ID is required")
	}

	newSizeBytes := req.GetCapacityRange().GetRequiredBytes()

	// Your server expects the base name.
	baseTargetName := strings.TrimPrefix(volumeID, "iqn.")

	log.Printf("Requesting LUN resize for volume %s (base name: %s) to %d GiB", volumeID, baseTargetName, newSizeBytes)
	resizeReq := ResizeLunRequest{
		TargetName:   baseTargetName,
		NewSizeBytes: newSizeBytes,
	}

	if err := s.apiClient.ResizeLun(resizeReq); err != nil {
		return nil, status.Errorf(codes.Internal, "Failed to resize LUN via API: %v", err)
	}

	return &csi.ControllerExpandVolumeResponse{
		CapacityBytes:         newSizeBytes,
		NodeExpansionRequired: true, // Tells Kubelet that the filesystem on the node also needs to be resized.
	}, nil
}

// --- Unimplemented but required functions ---

func (s *ControllerServer) ControllerPublishVolume(ctx context.Context, req *csi.ControllerPublishVolumeRequest) (*csi.ControllerPublishVolumeResponse, error) {
	// The `csi-driver-iscsi` node plugin handles the attachment, so this can be a no-op.
	return &csi.ControllerPublishVolumeResponse{}, nil
}

func (s *ControllerServer) ControllerUnpublishVolume(ctx context.Context, req *csi.ControllerUnpublishVolumeRequest) (*csi.ControllerUnpublishVolumeResponse, error) {
	// The `csi-driver-iscsi` node plugin handles the detachment, so this can be a no-op.
	return &csi.ControllerUnpublishVolumeResponse{}, nil
}

func (s *ControllerServer) ValidateVolumeCapabilities(ctx context.Context, req *csi.ValidateVolumeCapabilitiesRequest) (*csi.ValidateVolumeCapabilitiesResponse, error) {
	// A basic implementation that checks for SINGLE_NODE_WRITER access mode.
	for _, cap := range req.GetVolumeCapabilities() {
		if cap.GetAccessMode().GetMode() != csi.VolumeCapability_AccessMode_SINGLE_NODE_WRITER {
			return &csi.ValidateVolumeCapabilitiesResponse{}, nil
		}
	}
	return &csi.ValidateVolumeCapabilitiesResponse{
		Confirmed: &csi.ValidateVolumeCapabilitiesResponse_Confirmed{
			VolumeCapabilities: req.GetVolumeCapabilities(),
		},
	}, nil
}

func (s *ControllerServer) ControllerGetCapabilities(ctx context.Context, req *csi.ControllerGetCapabilitiesRequest) (*csi.ControllerGetCapabilitiesResponse, error) {
	log.Println("ControllerGetCapabilities called")
	return &csi.ControllerGetCapabilitiesResponse{
		Capabilities: []*csi.ControllerServiceCapability{
			{
				Type: &csi.ControllerServiceCapability_Rpc{
					Rpc: &csi.ControllerServiceCapability_RPC{
						Type: csi.ControllerServiceCapability_RPC_CREATE_DELETE_VOLUME,
					},
				},
			},
			{
				Type: &csi.ControllerServiceCapability_Rpc{
					Rpc: &csi.ControllerServiceCapability_RPC{
						Type: csi.ControllerServiceCapability_RPC_EXPAND_VOLUME,
					},
				},
			},
			// FIX: Add this capability.
			// The csi-attacher sidecar requires this to be advertised.
			{
				Type: &csi.ControllerServiceCapability_Rpc{
					Rpc: &csi.ControllerServiceCapability_RPC{
						Type: csi.ControllerServiceCapability_RPC_PUBLISH_UNPUBLISH_VOLUME,
					},
				},
			},
		},
	}, nil
}
