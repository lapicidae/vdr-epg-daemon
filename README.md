[![epgd](epgd-logo.svg)](https://github.com/vdr-projects/vdr-epg-daemon)

epgd - a EPG daemon which fetches the EPG and additional data from various sources (like epgdata, eplists.constabel.net, ...) and provide it to the [epg2vdr](https://github.com/horchi/vdr-plugin-epg2vdr) plugin via a database (MariaDB or MySQL).  
The epgd obtains the EPG from the sources by plugins. A plugin for [epgData](https://www.epgdata.com), [tvm](https://github.com/3PO/epgd-plugin-tvm/) and [xmltv](https://github.com/Zabrimus/epgd-plugin-xmltv) is contained.  
It is designed to handle large amount of data and pictures in a distributed environment with one epg-server and many possible vdr-clients.


# [lapicidae/vdr-epg-daemon](https://github.com/lapicidae/vdr-epg-daemon)

[![GitHub Repo stars](https://img.shields.io/github/stars/lapicidae/vdr-epg-daemon?color=3c0e7b&logo=github&logoColor=fff&style=for-the-badge)](https://github.com/lapicidae/vdr-epg-daemon)
[![Docker Pulls](https://img.shields.io/docker/pulls/lapicidae/vdr-epg-daemon?color=3c0e7b&label=pulls&logo=docker&logoColor=fff&style=for-the-badge)](https://hub.docker.com/r/lapicidae/vdr-epg-daemon)
[![Docker Stars](https://img.shields.io/docker/stars/lapicidae/vdr-epg-daemon?color=3c0e7b&label=stars&logo=docker&logoColor=fff&style=for-the-badge)](https://hub.docker.com/r/lapicidae/vdr-epg-daemon)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/lapicidae/vdr-epg-daemon/docker.yml?logo=github&logoColor=ffffff&style=for-the-badge)](https://github.com/lapicidae/vdr-epg-daemon/actions/workflows/docker.yml)

VDR EPG Daemon docker image based on [debian](https://hub.docker.com/_/debian) or [Ubuntu](https://hub.docker.com/_/ubuntu) and [s6-overlay](https://github.com/just-containers/s6-overlay).


## Features

* regular and timely application updates
* easy user mappings (PGID, PUID)
* integrated [tvm](https://github.com/3PO/epgd-plugin-tvm) and [xmltv](https://github.com/Zabrimus/epgd-plugin-xmltv) plugin
* [scraper](https://github.com/lapicidae/tvs-scraper) for [tvsp](https://m.tvspielfilm.de) mobile website to XMLTV
* epghttpd webinterface (including mostly german station logos)
* eMail notifications via [msmtprc](https://marlam.de/msmtp) - a very simple and easy to use SMTP client
* log to file with built-in log rotation

### *Note*
The images are automatically rebuilt when any of the following sources receive an update:

* [debian](https://hub.docker.com/_/debian) Official Docker Image - stable-slim
* [Ubuntu](https://hub.docker.com/_/ubuntu) Official Docker Image - latest
* [vdr-epg-daemon](https://github.com/horchi/vdr-epg-daemon) GitHub repository
* [epgd-plugin-tvm](https://github.com/3PO/epgd-plugin-tvm) GitHub repository
* [epgd-plugin-xmltv](https://github.com/Zabrimus/epgd-plugin-xmltv) GitHub repository


## Getting Started

### Dependencies

A MariaDB or MySQL server with integrated [epglv](https://github.com/vdr-projects/vdr-epg-daemon/blob/master/epglv/README) is required to store the epg details.  
For example, you can use the [mariadb-epglv](https://github.com/lapicidae/mariadb-epglv) docker image.

### Usage
Here are some example snippets to help you get started creating a container.

#### *docker-compose (recommended)*

Compatible with docker-compose v2 schemas. Take a look at the **[sample file](docker-compose.yml)**.
```yaml
services:
  epgd:
    container_name: vdr-epg-daemon
    environment:
      - LANG=de_DE.UTF-8  #other languages are currently not supported
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    hostname: epgd
    image: ghcr.io/lapicidae/vdr-epg-daemon:latest
    ports:
      - 9999:9999
    restart: unless-stopped
    volumes:
      - /path/to/cache:/epgd/cache
      - /path/to/config:/epgd/config
      - /path/to/epgimages:/epgd/epgimages
      - /path/to/channellogos:/epgd/channellogos  # optional
      - /path/to/log:/epgd/log                    # optional
```

#### *docker cli*

```bash
docker run -d \
  --name=vdr-epg-daemon \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Berlin \
  -e LANG=de_DE.UTF-8 `#other languages are currently not supported` \
  -p 9999:9999 \
  -v /path/to/cache:/epgd/cache \
  -v /path/to/config:/epgd/config \
  -v /path/to/epgimages:/epgd/epgimages \
  -v /path/to/channellogos:/epgd/channellogos `#optional` \
  -v /path/to/log:/epgd/log `#optional` \
  --restart unless-stopped \
  ghcr.io/lapicidae/vdr-epg-daemon:latest
```

### Parameters

Container images are configured using parameters passed at runtime.  
These parameters are separated by a colon and indicate `<external>:<internal>` respectively.  
For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Default | Function |
| :----: | ----- | ----- |
| `-p 9999` | 9999 | epghttpd Webinterface |
| `-e PUID=1000` | 1000 | for UserID - see below for explanation |
| `-e PGID=1000` | 1000 | for GroupID - see below for explanation |
| `-e TZ=Europe/London` | Europe/London | Specify a [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) to use (e.g. Europe/London) |
| `-e LANG=de_DE.UTF-8` | de_DE.UTF-8 | Default locale; see [list](https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=localedata/SUPPORTED;hb=HEAD) (**only `de_DE.UTF-8` is currently supported**) |
| `-e UPDATE_CONF_EVENTSVIEW=false` | true | Optional - Do not keep the provided eventsview sql files up to date |
| `-e UPDATE_CONF_PLUGINS=false` | true | Optional - Do not keep the provided config files of the plugins up to date |
| `-e UPDATE_CONF_USEREXIT=false` | true | Optional - Do not keep the provided file `userexit.sql` up to date |
| `-e UPDATE_CONF_MISC=false` | true | Optional - Do not keep all other provided `.dat`, `.py` and `.sql` files up to date |
| `-e LOGO_INTERNAL=false` | true | Optional - Use your own station logos in `/epgd/channellogos` |
| `-e LOGO_OVERWRITE=false` | true | Optional - Do not overwrite existing logos in `/epgd/channellogos` (only relevant if internal logos are used) |
| `-e START_EPGHTTPD=false` | true | Optional - Disable webinterface (epghttpd) |
| `-e RESTART_EPGD=true` | false | Optional - Restart epgd once at 3:30 AM after the start of the container |
| `-e RESTART_EPGD_AT=3:30` | 3:30 | Optional - Change default restart time ([examples](https://www.ibm.com/docs/en/zos/2.5.0?topic=descriptions-run-command-specified-time)) |
| `-e KNOCK_EPLISTS=false` | true | Optional - Disable the [eplists.de](http://eplists.de) connection check |
| `-e LOG2FILE=true` | false | Optional - Write log to file in `/epgd/log` |
| `-v /epgd/config` | | Config files |
| `-v /epgd/epgimages` | | EPG images for use in other plugins (e.g. [live plugin](https://github.com/MarkusEh/vdr-plugin-live)) |
| `-v /epgd/cache` | | Downloaded, temporary files |
| `-v /epgd/channellogos` | | TV station logos used in Webinterface |
| `-v /epgd/log` | | Logfiles if `LOG2FILE=true` |

### User / Group Identifiers

When using volumes (`-v` flags) permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1234` and `PGID=4321`, to find yours use `id user` as below:

```bash
  $ id username
    uid=1234(dockeruser) gid=4321(dockergroup) groups=4321(dockergroup)
```


## Thanks

* **[VDR EPG Daemon Team](https://github.com/horchi/vdr-epg-daemon)**
* **[Klaus Schmidinger (kls)](http://www.tvdr.de/)**
* **[vdr-portal.de](https://www.vdr-portal.de/)**
* **[just-containers](https://github.com/just-containers)**
* **[linuxserver.io](https://www.linuxserver.io/)**
* **...and all the forgotten ones**
