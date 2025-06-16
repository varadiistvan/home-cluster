package main

import (
	"flag"
	"log"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/container-storage-interface/spec/lib/go/csi"
	"google.golang.org/grpc"
)

const (
	DriverName    = "iscsi.stevevaradi.me" // Your unique driver name
	DriverVersion = "0.4.0"
)

// main is the entry point of the application. It sets up and starts the gRPC server
// for the CSI driver.
func main() {
	// Setup command line flags for the CSI endpoint.
	endpoint := flag.String("endpoint", "unix:///csi/csi.sock", "CSI endpoint")
	flag.Parse()

	// --- FIX: Ensure the directory for the Unix socket exists before listening ---
	// This prevents the "bind: no such file or directory" error when the container starts.

	// 1. We only handle unix domain sockets.
	if !strings.HasPrefix(*endpoint, "unix://") {
		log.Fatalf("Endpoint must be a unix socket (e.g., unix:///path/to/socket.sock), but got %s", *endpoint)
	}

	// 2. Strip the 'unix://' prefix to get the actual filesystem path for the socket.
	sockPath := strings.TrimPrefix(*endpoint, "unix://")

	// 3. Get the directory part of the socket path.
	sockDir := filepath.Dir(sockPath)

	// 4. Create the directory path if it doesn't exist. os.MkdirAll is like `mkdir -p`.
	//    It's safe to run even if the directory already exists.
	if err := os.MkdirAll(sockDir, 0755); err != nil {
		log.Fatalf("Failed to create socket directory %s: %v", sockDir, err)
	}
	// --- End of Fix ---

	// Get the gRPC server options. We don't have any specific options for now.
	serverOptions := []grpc.ServerOption{}
	s := grpc.NewServer(serverOptions...)

	// Create the API client for our iSCSI management server.
	// Environment variables are used for configuration to keep the container flexible.
	apiServerURL := os.Getenv("API_SERVER_URL")
	if apiServerURL == "" {
		log.Fatal("API_SERVER_URL environment variable must be set")
	}
	apiTokenPath := os.Getenv("API_TOKEN_PATH")
	if apiTokenPath == "" {
		apiTokenPath = "/etc/csi-secret/token" // Default path for the mounted secret
	}
	apiClient := NewApiClient(apiServerURL, apiTokenPath)

	// Create and register our CSI driver services.
	// The IdentityServer provides information about the driver itself.
	// The ControllerServer handles volume creation, deletion, and expansion.
	csi.RegisterIdentityServer(s, NewIdentityServer(DriverName, DriverVersion))
	csi.RegisterControllerServer(s, NewControllerServer(apiClient))

	// Start listening on the specified Unix socket. Note we use the cleaned `sockPath`.
	log.Printf("Listening for connections on %s", sockPath)
	lis, err := net.Listen("unix", sockPath)
	if err != nil {
		log.Fatalf("Failed to listen on endpoint %s: %v", sockPath, err)
	}

	// Start the gRPC server.
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve gRPC server: %v", err)
	}
}
