FROM --platform=$BUILDPLATFORM harbor.stevevaradi.me/hub/rust:alpine AS chef
WORKDIR /iscsi-provisioner-server
ENV PKGCONFIG_SYSROOTDIR=/
RUN apk add --no-cache musl-dev openssl-dev zig
RUN cargo install --locked cargo-zigbuild cargo-chef
RUN rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl

FROM chef AS planner
COPY . .
RUN ["cargo", "chef", "prepare", "--recipe-path", "recipe.json"]

FROM chef AS builder
COPY --from=planner /iscsi-provisioner-server/recipe.json recipe.json
WORKDIR /iscsi-provisioner-server
RUN cargo chef cook --recipe-path recipe.json --release --zigbuild \
  --target x86_64-unknown-linux-musl --target aarch64-unknown-linux-musl

COPY . .
RUN cargo zigbuild -r --target x86_64-unknown-linux-musl --target aarch64-unknown-linux-musl && \
  mkdir /iscsi-provisioner-server/linux && \
  cp target/aarch64-unknown-linux-musl/release/iscsi-provisioner-server /iscsi-provisioner-server/linux/arm64 && \
  cp target/x86_64-unknown-linux-musl/release/iscsi-provisioner-server /iscsi-provisioner-server/linux/amd64


FROM debian:bookworm-slim AS deps
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  libssl-dev \
  libudev-dev \
  libsystemd-dev \
  libnuma-dev \
  libaio-dev \
  libibverbs-dev \
  librdmacm-dev \
  lldpd \
  iproute2 \
  iputils-ping \
  procps \
  qemu-utils \
  open-iscsi \
  tgt \
  && rm -rf /var/lib/apt/lists/*

# We do not need the Rust toolchain to run the binary!
FROM deps AS runtime
WORKDIR /iscsi-provisioner-server
ARG TARGETPLATFORM
COPY --from=builder /iscsi-provisioner-server/${TARGETPLATFORM} /iscsi-provisioner-server/prog
CMD ["/iscsi-provisioner-server/prog"]
