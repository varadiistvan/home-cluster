# Stage 1: The Builder
# This stage compiles the Go binary for the target architecture.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

WORKDIR /app
COPY . .

ARG TARGETARCH TARGETOS
# Compile the binary.
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -o /iscsiplugin ./cmd/iscsiplugin/

# =========================================================================

# Stage 2: The Final Image
# This stage installs dependencies and copies the compiled binary.
FROM registry.k8s.io/build-image/debian-base:bookworm-v1.0.4

# Install iSCSI tools
RUN apt update && apt upgrade -y && apt-mark unhold libcap2
RUN clean-install util-linux e2fsprogs mount ca-certificates udev xfsprogs btrfs-progs open-iscsi

CMD service iscsid start
# Copy the compiled binary from the builder stage.
COPY --from=builder /iscsiplugin /iscsiplugin

# Copy and set up the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run the entrypoint script when the container starts
ENTRYPOINT ["/entrypoint.sh"]
