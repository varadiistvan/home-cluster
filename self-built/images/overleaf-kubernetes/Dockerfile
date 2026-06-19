FROM harbor.stevevaradi.me/stevevaradi/overleaf:latest

ARG TEXLIVE_SCHEME=scheme-full
ARG TEXLIVE_REPOSITORY=https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2025/tlnet-final

RUN rm /etc/my_init.d/000_check_for_old_env_vars_5.sh \
  && rm /etc/my_init.d/100_make_overleaf_data_dirs.sh

COPY ./texlive-packages.txt /tmp/texlive-packages.txt
COPY ./init_scripts/100_make_overleaf_data_dirs.sh /etc/my_init.d/100_make_overleaf_data_dirs.sh
COPY ./nginx/nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY ./runit/chat-overleaf/run /etc/service/chat-overleaf/run
COPY ./runit/clsi-overleaf/run /etc/service/clsi-overleaf/run
COPY ./runit/contacts-overleaf/run /etc/service/contacts-overleaf/run
COPY ./runit/docstore-overleaf/run /etc/service/docstore-overleaf/run
COPY ./runit/document-updater-overleaf/run /etc/service/document-updater-overleaf/run
COPY ./runit/filestore-overleaf/run /etc/service/filestore-overleaf/run
COPY ./runit/history-v1-overleaf/run /etc/service/history-v1-overleaf/run
COPY ./runit/notifications-overleaf/run /etc/service/notifications-overleaf/run
COPY ./runit/project-history-overleaf/run /etc/service/project-history-overleaf/run
COPY ./runit/real-time-overleaf/run /etc/service/real-time-overleaf/run
COPY ./runit/web-api-overleaf/run /etc/service/web-api-overleaf/run
COPY ./runit/web-overleaf/run /etc/service/web-overleaf/run

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ghostscript \
    python3-pygments \
    rsync \
  && rm -rf /var/lib/apt/lists/*

RUN tlmgr option repository "${TEXLIVE_REPOSITORY}" \
  && tlmgr update --self \
  && tlmgr install --no-execute-actions "${TEXLIVE_SCHEME}" \
  && grep -vE '^[[:space:]]*(#|$)' /tmp/texlive-packages.txt | xargs -r tlmgr install --no-execute-actions \
  && (fmtutil-sys --disablefmt dvilualatex-dev || true) \
  && (fmtutil-sys --disablefmt lualatex-dev || true) \
  && mktexlsr \
  && updmap-sys \
  && (fmtutil-sys --all || true) \
  && (luaotfload-tool --update || true)

RUN tlmgr path add \
  && command -v latexminted

COPY ./texlive-smoke-test.tex /tmp/texlive-smoke-test.tex

RUN mkdir -p /tmp/texlive-smoke \
  && cp /tmp/texlive-smoke-test.tex /tmp/texlive-smoke/main.tex \
  && cd /tmp/texlive-smoke \
  && latexmk -lualatex -shell-escape -interaction=nonstopmode -halt-on-error main.tex \
  && cd / \
  && rm -rf /tmp/texlive-smoke

RUN tlmgr list --only-installed | sha256sum | awk '{print $1}' > /usr/local/texlive/2025/.tlmgr-image-checksum

RUN chmod +x /etc/my_init.d/100_make_overleaf_data_dirs.sh \
  /etc/service/chat-overleaf/run \
  /etc/service/clsi-overleaf/run \
  /etc/service/contacts-overleaf/run \
  /etc/service/docstore-overleaf/run \
  /etc/service/document-updater-overleaf/run \
  /etc/service/filestore-overleaf/run \
  /etc/service/history-v1-overleaf/run \
  /etc/service/notifications-overleaf/run \
  /etc/service/project-history-overleaf/run \
  /etc/service/real-time-overleaf/run \
  /etc/service/web-api-overleaf/run \
  /etc/service/web-overleaf/run
