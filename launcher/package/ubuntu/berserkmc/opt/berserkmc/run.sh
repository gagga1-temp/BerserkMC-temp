#!/bin/bash

# NOTE: this Linux wrapper currently downloads and runs the upstream MultiMC
# build, because BerserkMC has no standalone Linux artifact of its own yet.
# Only the install location is BerserkMC-branded; the deployed executable is
# the upstream MultiMC binary. Point PACKAGE at a BerserkMC build once one
# exists.

INSTDIR="${XDG_DATA_HOME-$HOME/.local/share}/berserkmc"

if [ `getconf LONG_BIT` = "64" ]
then
    PACKAGE="mmc-stable-lin64.tar.gz"
else
    PACKAGE="mmc-stable-lin32.tar.gz"
fi

deploy() {
    mkdir -p $INSTDIR
    cd ${INSTDIR}

    wget --progress=dot:force "https://files.multimc.org/downloads/${PACKAGE}" 2>&1 | sed -u 's/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading at \2\/s, ETA \3/' | zenity --progress --auto-close --auto-kill --title="Downloading MultiMC..."

    tar -xzf ${PACKAGE} --transform='s,MultiMC/,,'
    rm ${PACKAGE}
    chmod +x MultiMC
}

runmmc() {
    cd ${INSTDIR}
    exec ./MultiMC "$@"
}

if [[ ! -f ${INSTDIR}/MultiMC ]]; then
    deploy
    runmmc "$@"
else
    runmmc "$@"
fi
