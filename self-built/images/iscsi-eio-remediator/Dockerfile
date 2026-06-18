FROM alpine:3.24

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.33.4

RUN apk add --no-cache ca-certificates curl \
  && curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
  && chmod +x /usr/local/bin/kubectl \
  && kubectl version --client=true

ENTRYPOINT ["/bin/sh"]
