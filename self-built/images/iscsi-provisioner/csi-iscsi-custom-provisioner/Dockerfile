# Stage 1: Build the Go binary in a dedicated build environment.
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

# Set the working directory inside the container.
WORKDIR /app

# Copy go.mod and go.sum files to download dependencies efficiently.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code.
COPY . .

ARG TARGETARCH TARGETOS
# Build the binary for a Linux environment.
# CGO_ENABLED=0 creates a static binary.
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -o csi-iscsi-custom-provisioner .

# Stage 2: Create the final lean image from scratch.
# This results in a very small and secure final image.
FROM scratch

WORKDIR /

# Copy only the compiled binary from the builder stage.
COPY --from=builder /app/csi-iscsi-custom-provisioner .

# The entrypoint for the container is the binary itself.
ENTRYPOINT [ "/csi-iscsi-custom-provisioner" ]
