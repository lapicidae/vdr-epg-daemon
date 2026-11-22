ARG baseIMAGE=debian \
    baseTAG=stable-slim

# --- Stage 1: s6-overlay & syslogd-overlay ---
FROM ${baseIMAGE}:${baseTAG} AS s6

ARG S6VER=3.2.3.2
ARG DEBIAN_FRONTEND="noninteractive"

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6VER}/s6-overlay-noarch.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6VER}/s6-overlay-x86_64.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6VER}/syslogd-overlay-noarch.tar.xz /tmp/

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    --mount=type=bind,source=root/build,target=/tmp/build \
    /usr/bin/bash /tmp/install.sh s6

# --- Stage 2: compile epgd, plugins, channellogos & tvs-scraper ---
FROM ${baseIMAGE}:${baseTAG} AS builder

ARG baseIMAGE \
    baseTAG \
    DEBIAN_FRONTEND="noninteractive"

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    /usr/bin/bash /tmp/install.sh build-deps

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    /usr/bin/bash /tmp/install.sh logos

ARG EPGD_DEV="true" \
    epgdVersion="unknown" \
    epgdRevision \
    pluginSngtvRevision \
    pluginTvmRevision \
    pluginXmltvRevision

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    --mount=type=bind,source=root/build,target=/tmp/build \
    --mount=type=bind,source=root/defaults/config/channelmap.conf.sngtv,target=/tmp/channelmap.conf.sngtv \
    /usr/bin/bash /tmp/install.sh build

ARG tvsScraperVersion

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    /usr/bin/bash /tmp/install.sh scraper

# --- Stage 3: minimal runtime image ---
FROM ${baseIMAGE}:${baseTAG}

ARG baseIMAGE \
    baseTAG \
    baseDIGEST \
    DEBIAN_FRONTEND="noninteractive"

ENV PATH="$PATH:/command"
ENV LANG="de_DE.UTF-8" \
    S6_VERBOSITY="1"

RUN --mount=type=bind,source=root/install.sh,target=/tmp/install.sh \
    /usr/bin/bash /tmp/install.sh runtime

COPY --from=s6 /s6-root/ /
COPY --from=builder --chown=epgd:epgd /out-logos/channellogos.tar.xz /defaults/
COPY --from=builder /out-epgd/usr/local/ /usr/local/
COPY --from=builder /out-epgd/var/epgd/www/ /var/epgd/www/
COPY --from=builder --chown=epgd:epgd /out-epgd/defaults/config/ /defaults/config/
COPY --from=builder /out-scraper/usr/local/bin/ /usr/local/bin/
COPY --from=builder --chown=epgd:epgd /out-scraper/defaults/config/ /defaults/config/
COPY root/etc/ /etc/
COPY --chown=epgd:epgd root/defaults/ /defaults/
COPY --from=builder --chown=epgd:epgd /out-sngtv/ /defaults/config/
COPY --chmod=755 root/usr/local/bin/ /usr/local/bin/
COPY --chmod=644 root/usr/local/etc/ /usr/local/etc/

WORKDIR /epgd

ARG authors="A. Hemmerle <github.com/lapicidae>" \
    dateTime \
    epgdRevision \
    epgdVersion \
    pluginSngtvRevision \
    pluginTvmRevision \
    pluginXmltvRevision \
    tvsScraperVersion

LABEL org.opencontainers.image.authors="${authors}" \
      org.opencontainers.image.base.digest="${baseDIGEST}" \
      org.opencontainers.image.base.name="docker.io/library/${baseIMAGE}:${baseTAG}" \
      org.opencontainers.image.created="${dateTime}" \
      org.opencontainers.image.description="Download EPG data from the internet and manage it in a MariaDB/MySQL database" \
      org.opencontainers.image.documentation="https://github.com/lapicidae/vdr-epg-daemon/blob/master/README.md" \
      org.opencontainers.image.licenses="GPL-2.0-only AND GPL-3.0-only AND GPL-3.0-or-later" \
      org.opencontainers.image.revision="${epgdRevision}" \
      org.opencontainers.image.source="https://github.com/lapicidae/vdr-epg-daemon" \
      org.opencontainers.image.title="epgd" \
      org.opencontainers.image.url="https://github.com/lapicidae/vdr-epg-daemon" \
      org.opencontainers.image.vendor="lapicidae" \
      org.opencontainers.image.version="${epgdVersion}" \
      io.github.lapicidae.plugin.sngtv.revision="${pluginSngtvRevision}" \
      io.github.lapicidae.plugin.tvm.revision="${pluginTvmRevision}" \
      io.github.lapicidae.plugin.xmltv.revision="${pluginXmltvRevision}" \
      io.github.lapicidae.tvs-scraper.version="${tvsScraperVersion}"

EXPOSE 9999

VOLUME ["/epgd/cache", "/epgd/config", "/epgd/epgimages"]

HEALTHCHECK --interval=20s --timeout=3s \
    CMD /usr/local/bin/healthcheck

ENTRYPOINT ["/init"]
