#!/bin/bash

## exit when any command fails
set -eE

## Ideally, change these variables via 'docker build-arg'
inVM=${inVM:-"false"}
S6VER=${S6VER:-"unknown"}
EPGD_DEV=${EPGD_DEV:-"false"}
epgdVersion=${epgdVersion:-"unknown"}
tvsScraperVersion=${tvsScraperVersion:-""}
baseIMAGE=${baseIMAGE:-"debian"}
LANG=${LANG:-"de_DE.UTF-8"}

## Do not change!
export LC_ALL="C"

## colored notifications
_ntfy() {
    printf '\e[36;1;2m**** %-6s ****\e[m\n' "$@"
}

## error messages before exiting
trap 'printf "\n\e[35;1;2m%s\e[m\n" "KILLED!"; exit 130' INT
trap 'printf "\n\e[31;1;2m> %s\nCommand terminated with exit code %s.\e[m\n" "$BASH_COMMAND" "$?"' ERR

if [ "$baseIMAGE" != 'debian' ] && [ "$baseIMAGE" != 'ubuntu' ]; then
    printf '\e[31;1;2m!!! WRONG BASE IMAGE !!!\e[m\n'
    exit 1
fi

buildDIR='/tmp/build'
if [ ! -d "$buildDIR" ]; then
    buildDIR='/build'
fi
sngtvTpl='/tmp/channelmap.conf.sngtv'
if [ ! -f "$sngtvTpl" ]; then
    sngtvTpl='/defaults/config/channelmap.conf.sngtv'
fi

buildPKG=(
    build-essential
    git
    libarchive-dev
    libcurl4-openssl-dev
    libimlib2-dev
    libjansson-dev
    libmariadb-dev
    libmicrohttpd-dev
    libssl-dev
    libtiff-dev
    libxml2-dev
    libxslt1-dev
    patch
    python3-dev
    uuid-dev
    zlib1g-dev
)
if [ "$baseIMAGE" = 'ubuntu' ]; then
    buildPKG+=(libjpeg-dev)
else
    buildPKG+=(libjpeg62-turbo-dev)
fi

phase_s6() {
    _ntfy "s6-overlay ($S6VER)"
    apt-get update -qq
    apt-get install -qy --no-install-recommends patch xz-utils
    mkdir -p /s6-root
    tar -C /s6-root -Jxpf /tmp/s6-overlay-noarch.tar.xz
    tar -C /s6-root -Jxpf /tmp/s6-overlay-x86_64.tar.xz

    _ntfy "syslogd-overlay ($S6VER)"
    tar -C /s6-root -Jxpf /tmp/syslogd-overlay-noarch.tar.xz
    patch /s6-root/etc/s6-overlay/s6-rc.d/syslogd-log/run "${buildDIR}/syslogd-log_run.patch"

    if [ -d /s6-root/etc/s6-overlay/s6-rc.d/user ]; then
        mkdir -p /s6-root/etc/s6-overlay/user-bundles.d/user
        cp -a /s6-root/etc/s6-overlay/s6-rc.d/user/. /s6-root/etc/s6-overlay/user-bundles.d/user/ || true
        rm -rf /s6-root/etc/s6-overlay/s6-rc.d/user
    fi
    rm -rf /s6-root/etc/s6-overlay/s6-rc.d/user2
    find /s6-root -exec touch -h -d '@0' {} +
}

phase_build_deps() {
    _ntfy 'install build packages'
    apt-get update -qq
    apt-get upgrade -qy
    apt-get install -qy --no-install-recommends "${buildPKG[@]}" ca-certificates python3 xz-utils
    if [ ! -e '/usr/bin/python-config' ]; then
        ln -sf "$(command -v python3-config)" '/usr/bin/python-config'
    fi
}

phase_logos() {
    _ntfy 'get channellogos'
    mkdir -p /out-logos
    git clone --depth 1 https://github.com/lapicidae/svg-channellogos.git /tmp/chlogo
    chmod +x /tmp/chlogo/tools/install
    /tmp/chlogo/tools/install -c light -p /tmp/channellogos -r

    local commitTs
    commitTs="$(git -C /tmp/chlogo log -1 --format='@%ct')"
    tar --sort=name --mtime="$commitTs" --owner=0 --group=0 --numeric-owner \
        -cpJf /out-logos/channellogos.tar.xz -C /tmp/channellogos .
    touch -d "$commitTs" /out-logos/channellogos.tar.xz
    rm -rf /tmp/chlogo /tmp/channellogos
}

phase_build() {
    local epgdREPO='https://github.com/horchi/vdr-epg-daemon.git'
    if [ "$EPGD_DEV" != 'true' ] && { [ -z "$epgdVersion" ] || [ "$epgdVersion" = 'unknown' ]; }; then
        epgdVersion="$(git ls-remote --tags --sort=-version:refname --refs "$epgdREPO" | head -n 1 | cut -d/ -f3)"
    fi

    _ntfy "compile EPGd ${epgdVersion}"
    mkdir -p /defaults/config /var/epgd/www /usr/local/bin /usr/local/lib/epgd/plugins
    if [ "$EPGD_DEV" = 'true' ] || [ -z "$epgdVersion" ] || [ "$epgdVersion" = 'unknown' ]; then
        git clone "$epgdREPO" /tmp/vdr-epg-daemon
    else
        git -c advice.detachedHead=false clone "$epgdREPO" --single-branch --branch "$epgdVersion" /tmp/vdr-epg-daemon || \
            git clone "$epgdREPO" /tmp/vdr-epg-daemon
    fi
    cd /tmp/vdr-epg-daemon || exit 1
    # shellcheck disable=SC2016
    sed -i 's/CONFDEST     = $(DESTDIR)\/etc\/epgd/CONFDEST     = $(DESTDIR)\/defaults\/config/g' Make.config
    sed -i 's/INIT_SYSTEM  = systemd/INIT_SYSTEM  = none/g' Make.config

    ## Plugins
    git clone https://github.com/horchi/epgd-plugin-sngtv.git ./PLUGINS/sngtv
    git clone https://github.com/3PO/epgd-plugin-tvm.git ./PLUGINS/tvm
    git clone https://github.com/Zabrimus/epgd-plugin-xmltv.git ./PLUGINS/xmltv
    patch PLUGINS/xmltv/Makefile "${buildDIR}/plugin-xmltv_no-clobber.patch"

    patch Makefile "${buildDIR}/epgd-scripts_no_clobber.patch"
    patch configs/epg.dat "${buildDIR}/epgd-dat-extend-txtrating.patch"
    make install-epgd install-epghttpd

    local _bin
    for _bin in /usr/local/bin/epgd /usr/local/bin/epghttpd /usr/local/lib/epgd/plugins/*.so; do
        if [ -f "$_bin" ]; then
            strip --strip-unneeded "$_bin"
        fi
    done

    mkdir -p /out-sngtv
    if command -v sngtv-channels >/dev/null 2>&1; then
        _ntfy 'prepare sngtv channelmap template'
        local sngtvSortByID='false' # true = sort by ID, false = original order (by name)
        local sngtvOut id name
        cp "$sngtvTpl" /out-sngtv/channelmap.conf.sngtv
        if sngtvOut="$(sngtv-channels 2>/dev/null)" && [ -n "$sngtvOut" ]; then
            if [ "$sngtvSortByID" = 'true' ]; then
                sngtvOut="$(printf '%s\n' "$sngtvOut" | LC_ALL=C sort -n)"
            fi
            while IFS=$' \t\r' read -r id name; do
                if [[ "$id" =~ ^[0-9]+$ ]]; then
                    printf '// sngtv:%s\t\t=\t//\t%s\n' "$id" "$name"
                fi
            done <<< "$sngtvOut" >> /out-sngtv/channelmap.conf.sngtv
        fi
    fi

    mkdir -p /out-epgd/usr/local/lib /out-epgd/var/epgd/www /out-epgd/defaults/config
    cp -a /usr/local/bin /out-epgd/usr/local/
    cp -a /usr/local/lib/epgd /out-epgd/usr/local/lib/
    cp -a /var/epgd/www/. /out-epgd/var/epgd/www/
    rm -rf /out-epgd/var/epgd/www/channellogos
    cp -a /defaults/config/. /out-epgd/defaults/config/
    cd /tmp || exit 1
    rm -rf /tmp/vdr-epg-daemon
}

phase_scraper() {
    _ntfy 'get tvs-scraper'
    local tvsscraperURL='https://github.com/lapicidae/tvs-scraper/'
    local tvsscraperTag="$tvsScraperVersion"
    if [ -z "$tvsscraperTag" ] || [ "$tvsscraperTag" = 'unknown' ]; then
        tvsscraperTag=$(git ls-remote --tags --sort='v:refname' "$tvsscraperURL" | tail -n 1 | sed 's/.*\///; s/\^{}//')
    fi

    git clone --quiet --depth 1 -c advice.detachedHead=false --branch "$tvsscraperTag" --single-branch "$tvsscraperURL" /tmp/tvs-scraper
    local commitTs
    commitTs="$(git -C /tmp/tvs-scraper log -1 --format='@%ct')"

    mkdir -p /out-scraper/usr/local/bin /out-scraper/defaults/config
    cp /tmp/tvs-scraper/tvs-scraper /tmp/tvs-scraper/contrib/vdr-epg-daemon/run-tvs-scraper /out-scraper/usr/local/bin/
    chmod 755 /out-scraper/usr/local/bin/tvs-scraper /out-scraper/usr/local/bin/run-tvs-scraper
    cp -rf /tmp/tvs-scraper/contrib/vdr-epg-daemon/config/{xmltv.xsl,xmltv-category.xml} /out-scraper/defaults/config/
    chmod 644 /out-scraper/defaults/config/xmltv.xsl /out-scraper/defaults/config/xmltv-category.xml
    find /out-scraper -exec touch -h -d "$commitTs" {} +
    rm -rf /tmp/tvs-scraper
}

phase_runtime() {
    _ntfy 'prepare'
    local runtimePKG=(
        at
        bsd-mailx
        curl
        libarchive13
        libcurl4
        libimlib2
        libjansson4
        libmariadb3
        libmicrohttpd12
        '^libpython[3-9]+.\b([0-9]|[1-9][0-9]|999)\b$'
        libxslt1.1
        locales
        mariadb-client-core
        msmtp-mta
        passwd
        python3
        python3-cssselect
        python3-lxml
        python3-platformdirs
        python3-portalocker
        python3-requests
        tzdata
        unzip
        uuid
        xz-utils
        zlib1g
    )
    if [ "$baseIMAGE" = 'ubuntu' ]; then
        runtimePKG+=(
            libjpeg8
            '^libxml2-[0-9]+$'
        )
    else
        runtimePKG+=(
            libjpeg62-turbo
            libxml2
        )
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
        fi
        printf 'locales locales/locales_to_be_generated multiselect %s UTF-8\n' "$LANG" | debconf-set-selections
        printf 'locales locales/default_environment_locale select %s\n' "$LANG" | debconf-set-selections
    fi

    _ntfy 'upgrade'
    apt-get update -qq
    apt-get upgrade -qy

    _ntfy 'install runtime packages'
    apt-get install -qy --no-install-recommends "${runtimePKG[@]}"
    if [ ! -e '/usr/bin/python' ]; then
        ln -sf "$(command -v python3)" '/usr/bin/python'
    fi

    _ntfy 'locale'
    if [ "$baseIMAGE" = 'debian' ]; then
        dpkg-reconfigure -f noninteractive locales
    else
        locale-gen "$LANG"
    fi
    update-locale LANG="$LANG" LANGUAGE="${LANG%_*}:${LANG%%_*}"

    _ntfy 'bash tweaks'
    {
        printf '[ -r /usr/local/bin/contenv2env ] && . /usr/local/bin/contenv2env\n'
        printf '[ -r /etc/bash.aliases ] && . /etc/bash.aliases\n'
    } >> /etc/bash.bashrc
    rm -rf /root/.bashrc

    _ntfy 'users, folders and symlinks'
    useradd --system --no-create-home --shell /bin/false syslog
    useradd --system --no-create-home --shell /bin/false sysllog
    useradd --uid 911 --system --no-create-home --shell /bin/false epgd
    usermod -a -G users,mail epgd

    curl -fsSL -o /etc/msmtprc 'https://raw.githubusercontent.com/marlam/msmtp/refs/heads/master/doc/msmtprc-system.example'
    chown root:mail /etc/msmtprc
    chmod 640 /etc/msmtprc

    mkdir -p \
        /defaults/channellogos \
        /defaults/config \
        /epgd/cache \
        /epgd/epgimages \
        /epgd/channellogos \
        /epgd/log \
        /usr/local/bin \
        /usr/local/etc \
        /usr/local/lib/epgd/plugins \
        /var/cache/vdr \
        /var/epgd/www
    ln -sfn /epgd/config /etc/epgd
    ln -sfn /epgd/epgimages /var/cache/vdr/epgimages
    ln -sfn /epgd/channellogos /var/epgd/www/channellogos
    ln -sfn /epgd/config/run-tvs-scraper.conf /etc/run-tvs-scraper.conf
    chown -R epgd:epgd /defaults /epgd
    chown -R sysllog:sysllog /epgd/log

    _ntfy 'cleanup'
    apt-get clean
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/* /var/tmp/*
    find /tmp -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec rm -rf {} +
}

phase_all() {
    phase_s6
    cp -a /s6-root/. /
    rm -rf /s6-root

    phase_runtime
    phase_build_deps
    phase_build

    if [ -f /out-sngtv/channelmap.conf.sngtv ]; then
        cp -f /out-sngtv/channelmap.conf.sngtv /defaults/config/channelmap.conf.sngtv
    else
        rm -f /defaults/config/channelmap.conf.sngtv
    fi

    phase_scraper
    cp -a /out-scraper/usr/local/bin/. /usr/local/bin/
    cp -a /out-scraper/defaults/config/. /defaults/config/

    phase_logos
    cp -a /out-logos/channellogos.tar.xz /defaults/

    chown -R epgd:epgd /defaults /epgd
    chown -R sysllog:sysllog /epgd/log
    if [ -f /usr/local/etc/epgd-common.sh ]; then
        chown root:root /usr/local/etc/epgd-common.sh
        chmod 644 /usr/local/etc/epgd-common.sh
    fi
    chown root:root /usr/local/bin/*
    chmod 755 /usr/local/bin/*

    _ntfy 'cleanup'
    apt-get purge -qy --auto-remove "${buildPKG[@]}"
    apt-get clean
    rm -rf \
        /out-epgd \
        /out-sngtv \
        /out-scraper \
        /out-logos \
        /build \
        /usr/bin/python-config \
        /var/lib/apt/lists/* \
        /usr/share/doc/* \
        /usr/share/man/* \
        /var/tmp/*
    find /tmp -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec rm -rf {} +

    if [ "$0" = '/install.sh' ] && { [ -f '/.dockerenv' ] || [ "$inVM" = 'true' ]; }; then
        _ntfy "delete this installer ($0)"
        rm -f -- "$0"
    fi
}

_usage() {
    cat <<EOF
Usage: $0 [phase]

Phases:
  all (default)     Run all phases for single-stage / VM install
  s6                Unpack and patch s6-overlay & syslogd-overlay
  build-deps        Install build packages
  logos             Clone and package svg-channellogos
  build             Compile and strip epgd + plugins
  scraper           Fetch tvs-scraper and its configs
  runtime           Install runtime packages, locale, users and symlinks
  -h, --help, help  Show this help
EOF
}

case "${1:-}" in
    ""|all)         phase_all ;;
    s6)             phase_s6 ;;
    build-deps)     phase_build_deps ;;
    logos)          phase_logos ;;
    build)          phase_build ;;
    scraper)        phase_scraper ;;
    runtime)        phase_runtime ;;
    -h|--help|help) _usage; exit 0 ;;
    *)              _usage >&2; exit 1 ;;
esac

_ntfy "all done (${1:-all})"

# vim: ts=4 sw=4 et:
# kate: space-indent on; indent-width 4; mixed-indent off;
