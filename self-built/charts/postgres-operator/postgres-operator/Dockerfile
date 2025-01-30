# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG RUST_VERSION=1.84.0

# (1) this stage will be run always on current arch
# zigbuild & Cargo targets added
FROM --platform=$BUILDPLATFORM rust:$RUST_VERSION-alpine AS chef
WORKDIR /app
ENV PKGCONFIG_SYSROOTDIR=/
RUN apk add --no-cache musl-dev openssl-dev zig
RUN cargo install --locked cargo-zigbuild cargo-chef
RUN rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl

# (2) nothing changed
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# (3) building project deps: need to specify all targets; zigbuild used
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --recipe-path recipe.json --release --zigbuild \
  --target x86_64-unknown-linux-musl --target aarch64-unknown-linux-musl

ARG APP_NAME=postgres-operator
# (4) actuall project build for all targets
# binary renamed to easier copy in runtime stage
COPY . .
RUN cargo zigbuild -r --target x86_64-unknown-linux-musl --target aarch64-unknown-linux-musl && \
  mkdir /app/linux && \
  cp /app/target/aarch64-unknown-linux-musl/release/${APP_NAME} /app/linux/arm64 && \
  cp /app/target/x86_64-unknown-linux-musl/release/${APP_NAME} /app/linux/amd64


FROM alpine:3.18 AS final

ARG TARGETPLATFORM

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
  --disabled-password \
  --gecos "" \
  --home "/nonexistent" \
  --shell "/sbin/nologin" \
  --no-create-home \
  --uid "${UID}" \
  appuser
USER appuser

# Copy the executable from the "build" stage.
COPY --from=builder /app/${TARGETPLATFORM} /bin/server

# What the container should run when it is started.
CMD ["/bin/server"]
