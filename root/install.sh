#!/bin/bash

## exit when any command fails
set -e


## Ideally, change these variables via 'docker build-arg'
# e.g.: docker build --tag vdr-epg-daemon --build-arg EPGD_DEV=true .
inVM=${inVM:-"false"}
S6VER=${S6VER:-"unknown"}
EPGD_DEV=${EPGD_DEV:-"false"}
epgdVersion=${epgdVersion:-"unknown"}
baseIMAGE=${baseIMAGE:-"debian"}
baseTAG=${baseTAG:-"stable-slim"}
LANG=${LANG:-"de_DE.UTF-8"}


## Do not change!
LC_ALL="C"


## colored notifications
_ntfy() {
    printf '\e[36;1;2m**** %-6s ****\e[m\n' "$@"
}


## error messages before exiting
trap 'printf "\n\e[35;1;2m%s\e[m\n" "KILLED!"; exit 130' INT
trap 'printf "\n\e[31;1;2m> %s\nCommand terminated with exit code %s.\e[m\n" "$BASH_COMMAND" "$?"' ERR


## Profit!
_ntfy 'prepare'
runtimePKG=(
    at
    bsd-mailx
    libarchive13
    libcurl4
    libimlib2
    libjansson4
    libmariadb3
    libmicrohttpd12
    '^libpython[3-9]+.\b([0-9]|[1-9][0-9]|999)\b$'
    libxml2
    libxslt1.1
    locales
    passwd
    python3
    python3-cssselect
    python3-requests-cache
    ssmtp
    tzdata
    unzip
    uuid
    xz-utils
    zlib1g
)
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
    python3-dev
    uuid-dev
    wget
    zlib1g-dev
)
if [ "$baseIMAGE" = 'ubuntu' ]; then
    runtimePKG+=(libjpeg8)
    buildPKG+=(libjpeg-dev)
elif [ "$baseIMAGE" = 'debian' ]; then
    runtimePKG+=(
        libjpeg62-turbo
        locales-all
    )
    buildPKG+=(libjpeg62-turbo-dev)
else
  printf '\e[31;1;2m!!! WRONG BASE IMAGE !!!\e[m\n'
  exit 1
fi

_ntfy 'upgrade'
apt-get update -qq
apt-get upgrade -qy

_ntfy 'install runtime packages'
apt-get install -qy "${runtimePKG[@]}"
[ ! -e '/usr/bin/python' ] && ln -sf "$(which python3)" '/usr/bin/python'

_ntfy 'install build packages'
apt-get install -qy "${buildPKG[@]}"
[ ! -e '/usr/bin/python-config' ] && ln -sf "$(which python3-config)" '/usr/bin/python-config'

_ntfy "s6-overlay ($S6VER)"
cd /tmp || exit 1
tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

_ntfy "syslogd-overlay ($S6VER)"
tar -C / -Jxpf /tmp/syslogd-overlay-noarch.tar.xz
patch /etc/s6-overlay/s6-rc.d/syslogd-log/run /build/syslogd-log_run.patch
useradd --system --no-create-home --shell /bin/false syslog
useradd --system --no-create-home --shell /bin/false sysllog

_ntfy 'locale'
localedef -i "$(echo "$LANG" | cut -d "." -f 1)" -c -f "$(echo "$LANG" | cut -d "." -f 2)" -A /usr/share/locale/locale.alias "$LANG"
locale-gen "$LANG"
update-locale LANG="$LANG" LANGUAGE="$(echo "$LANG" | cut -d "." -f 1):$(echo "$LANG" | cut -d "_" -f 1)"

_ntfy 'bash tweaks'
{
    printf '[ -r /usr/local/bin/contenv2env ] && . /usr/local/bin/contenv2env\n'
    printf '[ -r /etc/bash.aliases ] && . /etc/bash.aliases\n'
} >> /etc/bash.bashrc
rm -rf /root/.bashrc

_ntfy 'create epgd user'
useradd --uid 911 --system --no-create-home --shell /bin/false epgd
usermod -a -G users epgd

_ntfy 'folders and symlinks'
mkdir -p /defaults/channellogos
mkdir -p /defaults/config
mkdir -p /epgd/cache
mkdir -p /epgd/epgimages && mkdir -p /var/cache/vdr
ln -s /epgd/epgimages /var/cache/vdr/epgimages
mkdir -p /epgd/channellogos && mkdir -p /var/epgd/www
ln -s /epgd/channellogos /var/epgd/www/channellogos
mkdir -p /epgd/log

_ntfy 'SMTP client'
apt-get install -qy msmtp-mta
wget --quiet -O /etc/msmtprc 'https://raw.githubusercontent.com/marlam/msmtp/refs/heads/master/doc/msmtprc-system.example'
chown root:mail /etc/msmtprc
chmod 640 /etc/msmtprc
usermod -a -G mail epgd

_ntfy "compile ${epgdVersion}"
cd /tmp || exit 1
epgdREPO='https://github.com/horchi/vdr-epg-daemon.git'
if [ "$EPGD_DEV" = 'true' ]; then
    git clone "$epgdREPO" vdr-epg-daemon
else
    git -c advice.detachedHead=false clone "$epgdREPO" --single-branch --branch "$(git ls-remote --tags --sort=-version:refname --refs "$epgdREPO" | head -n 1 | cut -d/ -f3)" vdr-epg-daemon
fi
cd vdr-epg-daemon || exit 1
# shellcheck disable=SC2016
sed -i 's/CONFDEST     = $(DESTDIR)\/etc\/epgd/CONFDEST     = $(DESTDIR)\/defaults\/config/g' Make.config
sed -i 's/INIT_SYSTEM  = systemd/INIT_SYSTEM  = none/g' Make.config
git clone https://github.com/3PO/epgd-plugin-tvm.git ./PLUGINS/tvm
git clone https://github.com/chriszero/epgd-plugin-tvsp.git ./PLUGINS/tvsp
git clone https://github.com/Zabrimus/epgd-plugin-xmltv.git ./PLUGINS/xmltv
patch -d configs -i ../PLUGINS/xmltv/patches/epgd-dat-extend-externalid.diff
#make all install
make install-epgd install-epghttpd

_ntfy 'get alternative eventsview'
wget --quiet -P /defaults/config 'https://raw.githubusercontent.com/MegaV0lt/vdr-plugin-skinflatplus/master/contrib/eventsview-flatplus.sql'

_ntfy 'get channellogos'
cd /tmp || exit 1
git clone https://github.com/lapicidae/svg-channellogos.git chlogo
chmod +x chlogo/tools/install
chlogo/tools/install -c light -p /tmp/channellogos -r
tar -cpJf /defaults/channellogos.tar.xz -C /tmp/channellogos .

_ntfy 'change permissions'
chown -R epgd:epgd /defaults
chown -R epgd:epgd /epgd
chown -R sysllog:sysllog /epgd/log
chown root:root /usr/local/bin/contenv2env
chmod 755 /usr/local/bin/contenv2env
chown root:root /usr/local/bin/healthcheck
chmod 755 /usr/local/bin/healthcheck
chown root:root /usr/local/bin/svdrpsend
chmod 755 /usr/local/bin/svdrpsend
chown root:root /usr/local/bin/run-scraper
chmod 755 /usr/local/bin/run-scraper
chown root:root /usr/local/bin/tvs-scraper
chmod 755 /usr/local/bin/tvs-scraper

_ntfy 'cleanup'
apt-get purge -qy --auto-remove "${buildPKG[@]}"
#dpkg -l | grep "\-dev" | sed 's/ \+ /|/g' | cut -d '|' -f 2 | cut -d ':' -f 1 | xargs apt-get purge --auto-remove -qy
apt-get clean
rm -rf \
    /build \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/bin/python-config


## Delete this script if it is running in a Docker container
if [ -f '/.dockerenv' ] || [ "$inVM" = 'true' ]; then
    _ntfy "delete this installer ($0)"
    rm -- "$0"
fi

_ntfy 'all done'
printf '\e[32;1;2m>>> DONE! <<<\e[m\n'
