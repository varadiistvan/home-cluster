ARG CNPG_IMAGE=ghcr.io/cloudnative-pg/postgresql:18-standard-bookworm
# renovate: versioning=regex:^pg18-v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
FROM docker.io/tensorchord/vchord-postgres:pg18-v1.1.1 AS vchord
FROM ${CNPG_IMAGE}

USER root
# VectorChord + pgvector
COPY --from=vchord /usr/lib/postgresql/18/lib/vchord.so /usr/lib/postgresql/18/lib/
COPY --from=vchord /usr/lib/postgresql/18/lib/vector.so /usr/lib/postgresql/18/lib/
COPY --from=vchord /usr/share/postgresql/18/extension/vchord* /usr/share/postgresql/18/extension/
COPY --from=vchord /usr/share/postgresql/18/extension/vector* /usr/share/postgresql/18/extension/

RUN chown -R 26:26 /usr/lib/postgresql/18/lib /usr/share/postgresql/18/extension
USER 26
