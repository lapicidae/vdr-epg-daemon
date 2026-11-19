#!/bin/bash

baseIMAGE=${baseIMAGE:-"debian"}
baseTAG=${baseTAG:-"stable-slim"}
imageTag=${imageTag:-"vdr-epg-daemon"}
EPGD_DEV=${EPGD_DEV:-"false"}
epgdVersion=${epgdVersion:-"${1:-}"}

epgdREPO='https://github.com/horchi/vdr-epg-daemon.git'
epgdHISTORY='https://raw.githubusercontent.com/horchi/vdr-epg-daemon/master/HISTORY.h'

_history_ver() {
    awk -F'"' '/^#define[[:space:]]+_VERSION/ {print $2; exit}' "$@"
}

if [ "$EPGD_DEV" = 'true' ]; then
    gitDIR=$(mktemp -d --suffix '_epgdGIT')
    git clone --quiet "$epgdREPO" "$gitDIR"
    cd "$gitDIR" || exit 1

    ver="$(git describe --tags 2>/dev/null)"
    [ -z "$ver" ] && [ -f HISTORY.h ] && ver="$(_history_ver HISTORY.h)"
    printf -v epgdVersion '%s' "$ver"
    printf -v epgdRevision '%s' "$(git log --pretty=format:'%H' -n 1)"

    cd "$OLDPWD" || exit 1
    rm -rf "$gitDIR"

    dockerTAGS=(--tag "${imageTag}:dev")
else
    remoteTags="$(git ls-remote --tags --sort=-version:refname --refs "$epgdREPO")"
    latestUpstream="$(printf '%s\n' "$remoteTags" | head -n 1 | cut -d/ -f3)"
    [ -z "$latestUpstream" ] && latestUpstream="$(curl -fsSL "$epgdHISTORY" | _history_ver)"

    epgdVersion="${epgdVersion:-$latestUpstream}"
    matchLine="$(printf '%s\n' "$remoteTags" | awk -v ver="${epgdVersion#v}" '$2 == "refs/tags/" ver || $2 == "refs/tags/v" ver {print $1 "\t" $2; exit}')"
    if [ -n "$matchLine" ]; then
        rev="${matchLine%%$'\t'*}"
        epgdVersion="${matchLine##*/}"
    elif [ "${epgdVersion#v}" = "${latestUpstream#v}" ] && [ -n "$latestUpstream" ]; then
        rev="$(git ls-remote "$epgdREPO" HEAD | cut -f 1)"
    else
        printf 'Error: epgd version "%s" not found in %s\n' "$epgdVersion" "$epgdREPO" >&2
        exit 1
    fi
    printf -v epgdRevision '%s' "$rev"

    cleanVer="${epgdVersion#v}"
    IFS='.' read -r vMajor vMinorPart _ <<< "$cleanVer"
    vMinor="${vMajor}.${vMinorPart}"
    vPatch="${cleanVer}"

    tagPrefix=""
    [ "$baseIMAGE" = 'ubuntu' ] && tagPrefix="ubuntu-"
    dockerTAGS=(
        --tag "${imageTag}:${tagPrefix}${vMajor}"
        --tag "${imageTag}:${tagPrefix}${vMinor}"
        --tag "${imageTag}:${tagPrefix}${vPatch}"
        --tag "${imageTag}:${baseIMAGE}"
    )

    if [ "$baseIMAGE" = 'debian' ]; then
        highestVersion="$(
            {
                printf '%s\n' "${latestUpstream#v}" "${vPatch}"
                docker image ls "${imageTag}" --format '{{.Tag}}' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || true
            } | sort -uV | tail -n 1
        )"
        [ "$vPatch" = "$highestVersion" ] && dockerTAGS+=(--tag "${imageTag}:latest")
    fi
fi

dateTime="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf -v baseDIGEST '%s' "$(docker image pull "${baseIMAGE}":"${baseTAG}" | grep -i digest | cut -d ' ' -f 2)"
pluginSngtvRevision="$(git ls-remote 'https://github.com/horchi/epgd-plugin-sngtv.git' HEAD | cut -f 1)"
pluginTvmRevision="$(git ls-remote 'https://github.com/3PO/epgd-plugin-tvm.git' HEAD | cut -f 1)"
pluginXmltvRevision="$(git ls-remote 'https://github.com/Zabrimus/epgd-plugin-xmltv.git' HEAD | cut -f 1)"
tvsScraperVersion="$(git ls-remote --tags --sort=-version:refname --refs 'https://github.com/lapicidae/tvs-scraper.git' | head -n 1 | cut -d/ -f3)"

docker build \
    --progress=plain \
    "${dockerTAGS[@]}" \
    --build-arg baseIMAGE="${baseIMAGE}" \
    --build-arg baseTAG="${baseTAG}" \
    --build-arg baseDIGEST="${baseDIGEST}" \
    --build-arg dateTime="${dateTime}" \
    --build-arg epgdRevision="${epgdRevision}" \
    --build-arg epgdVersion="${epgdVersion}" \
    --build-arg EPGD_DEV="${EPGD_DEV}" \
    --build-arg pluginSngtvRevision="${pluginSngtvRevision}" \
    --build-arg pluginTvmRevision="${pluginTvmRevision}" \
    --build-arg pluginXmltvRevision="${pluginXmltvRevision}" \
    --build-arg tvsScraperVersion="${tvsScraperVersion}" \
    .
