package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// Structs matching your server's Rust API request bodies.
type CreateLunRequest struct {
	TargetName string `json:"target_name"`
	SizeBytes  int64  `json:"size_bytes"`
	Initiator  string `json:"initiator"`
}

type ResizeLunRequest struct {
	TargetName   string `json:"target_name"`
	NewSizeBytes int64  `json:"new_size_bytes"`
}

type DeleteLunRequest struct {
	TargetName  string `json:"target_name"`
	DeleteStore bool   `json:"delete_store"`
}

// LunResponse struct to match the JSON object returned by your server's /create endpoint.
type LunResponse struct {
	ID           int    `json:"id"`
	SizeBytes    int64  `json:"size_bytes"`
	Initiator    string `json:"initiator"`
	TargetName   string `json:"target_name"` // This is the IQN
	TargetPortal string `json:"target_portal"`
}

// ApiClient handles all communication with your iSCSI management server.
type ApiClient struct {
	baseURL    string
	tokenPath  string
	httpClient *http.Client
}

// NewApiClient creates a new client for your API.
func NewApiClient(baseURL, tokenPath string) *ApiClient {
	return &ApiClient{
		baseURL:   baseURL,
		tokenPath: tokenPath,
		httpClient: &http.Client{
			Timeout: 20 * time.Second,
		},
	}
}

// makeRequest is a helper function to create and send an authenticated HTTP request.
func (c *ApiClient) makeRequest(method, path string, payload interface{}) (*http.Response, error) {
	// Read bearer token from the secret mounted in the pod.
	token, err := os.ReadFile(c.tokenPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read API token from %s: %w", c.tokenPath, err)
	}

	var body []byte
	if payload != nil {
		body, err = json.Marshal(payload)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request payload: %w", err)
		}
	}

	req, err := http.NewRequest(method, c.baseURL+path, bytes.NewBuffer(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+string(token))

	return c.httpClient.Do(req)
}

// CreateLun calls the /api/v1/create endpoint on your server.
func (c *ApiClient) CreateLun(req CreateLunRequest) (*LunResponse, error) {
	resp, err := c.makeRequest(http.MethodPost, "/api/v1/create", req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API server returned error on create: %s (status %d)", string(body), resp.StatusCode)
	}

	var createResp LunResponse
	if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
		return nil, fmt.Errorf("failed to decode create lun response: %w", err)
	}

	log.Printf("Successfully created LUN via API: IQN=%s, Portal=%s", createResp.TargetName, createResp.TargetPortal)
	return &createResp, nil
}

// DeleteLun calls the /api/v1/delete endpoint on your server.
func (c *ApiClient) DeleteLun(req DeleteLunRequest) error {
	resp, err := c.makeRequest(http.MethodPost, "/api/v1/delete", req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API server returned error on delete: %s (status %d)", string(body), resp.StatusCode)
	}

	log.Printf("Successfully deleted LUN via API: TargetName=%s", req.TargetName)
	return nil
}

// ResizeLun calls the /api/v1/resize endpoint on your server.
func (c *ApiClient) ResizeLun(req ResizeLunRequest) error {
	resp, err := c.makeRequest(http.MethodPost, "/api/v1/resize", req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API server returned error on resize: %s (status %d)", string(body), resp.StatusCode)
	}

	log.Printf("Successfully resized LUN via API: TargetName=%s", req.TargetName)
	return nil
}
