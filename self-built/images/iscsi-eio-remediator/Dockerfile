FROM alpine:3.24

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.36.2

RUN apk add --no-cache ca-certificates curl jq \
  && curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 120 \
    -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
  && chmod +x /usr/local/bin/kubectl \
  && kubectl version --client=true

ENTRYPOINT ["/bin/sh"]
