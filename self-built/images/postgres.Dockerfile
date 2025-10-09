# FROM tensorchord/pgvecto-rs:pg16-v0.4.0 AS pgvecto
FROM harbor.stevevaradi.me/hub/tensorchord/vchord-postgres:pg16-v0.5.3 AS vchord

FROM harbor.stevevaradi.me/ghcr/cloudnative-pg/postgresql:16-standard-bookworm

USER root
# COPY --from=pgvecto /usr/lib/postgresql/16/lib/vectors.so /usr/lib/postgresql/16/lib/
# COPY --from=pgvecto /usr/share/postgresql/16/extension/vectors* /usr/share/postgresql/16/extension/

COPY --from=vchord  /usr/lib/postgresql/16/lib/vchord.so  /usr/lib/postgresql/16/lib/
COPY --from=vchord  /usr/lib/postgresql/16/lib/vector.so  /usr/lib/postgresql/16/lib/
COPY --from=vchord  /usr/share/postgresql/16/extension/vchord* /usr/share/postgresql/16/extension/
COPY --from=vchord  /usr/share/postgresql/16/extension/vector*  /usr/share/postgresql/16/extension/

RUN chown -R 26:26 /usr/lib/postgresql/16/lib /usr/share/postgresql/16/extension
USER 26

