FROM tensorchord/pgvecto-rs:pg16-v0.3.0 AS builder

FROM bitnami/postgresql:16

COPY --from=builder /usr/lib/postgresql/*/lib/vectors.so /opt/bitnami/postgresql/lib/
COPY --from=builder /usr/share/postgresql/*/extension/vectors* /opt/bitnami/postgresql/share/extension/
