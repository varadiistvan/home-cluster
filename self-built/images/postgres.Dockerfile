# Stage 1: Extract pgvecto.rs
FROM tensorchord/pgvecto-rs:pg16-v0.3.0 AS pgvecto_rs_builder

# Stage 2: Build pgvector
FROM tensorchord/vchord-postgres:pg16-v0.4.0 as vchord


# Stage 4: Final image
FROM bitnami/postgresql:16

# Copy pgvecto.rs extension
COPY --from=pgvecto_rs_builder /usr/lib/postgresql/*/lib/vectors.so /opt/bitnami/postgresql/lib/
COPY --from=pgvecto_rs_builder /usr/share/postgresql/*/extension/vectors* /opt/bitnami/postgresql/share/extension/

COPY --from=vchord /usr/lib/postgresql/*/lib/vchord.so /opt/bitnami/postgresql/lib/
COPY --from=vchord /usr/lib/postgresql/*/lib/vector.so /opt/bitnami/postgresql/lib/
COPY --from=vchord /usr/share/postgresql/*/extension/vchord* /opt/bitnami/postgresql/share/extension/
COPY --from=vchord /usr/share/postgresql/*/extension/vector* /opt/bitnami/postgresql/share/extension/
COPY --from=vchord /usr/share/postgresql/*/extension/vector* /opt/bitnami/postgresql/share/extension/
