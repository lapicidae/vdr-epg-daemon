ARG baseIMAGE=debian \
    baseTAG=stable-slim

FROM ${baseIMAGE}:${baseTAG}

COPY root/ /

ARG authors="A. Hemmerle <github.com/lapicidae>" \
    DEBIAN_FRONTEND="noninteractive" \
    EPGD_DEV="true" \
    inVM="true" \
    S6VER="3.2.0.2" \
    baseDIGEST \
    baseIMAGE \
    baseTAG \
    dateTime \
    epgdRevision \
    epgdVersion

ENV PATH="$PATH:/command"
ENV LANG="de_DE.UTF-8" \
    S6_VERBOSITY="1"

ADD https://github.com/just-containers/s6-overlay/releases/download/v$S6VER/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v$S6VER/s6-overlay-x86_64.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v$S6VER/syslogd-overlay-noarch.tar.xz /tmp

RUN /usr/bin/bash -c '/install.sh'

WORKDIR /epgd

LABEL org.opencontainers.image.authors=${authors} \
      org.opencontainers.image.base.digest=${baseDIGEST} \
      org.opencontainers.image.base.name="docker.io/${baseIMAGE}:${baseTAG}" \
      org.opencontainers.image.created=${dateTime} \
      org.opencontainers.image.description="Download EPG data from the internet and manage it in a maria database" \
      org.opencontainers.image.documentation="https://github.com/lapicidae/vdr-epg-daemon/blob/master/README.md" \
      org.opencontainers.image.licenses="GPL-2.0-only AND GPL-3.0-only AND GPL-3.0-or-later" \
      org.opencontainers.image.revision=${epgdRevision} \
      org.opencontainers.image.source="https://github.com/lapicidae/vdr-epg-daemon/" \
      org.opencontainers.image.title="epgd" \
      org.opencontainers.image.url="https://github.com/lapicidae/vdr-epg-daemon/blob/master/README.md" \
      org.opencontainers.image.version=${epgdVersion}

EXPOSE 9999

VOLUME ["/epgd/cache", "/epgd/config", "/epgd/epgimages"]

HEALTHCHECK --interval=20s --timeout=3s \
    CMD /usr/local/bin/healthcheck

ENTRYPOINT ["/init"]
