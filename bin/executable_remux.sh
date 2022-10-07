#!/bin/bash

set -euo pipefail

# default flags
sub_dir="${HOME:=$PWD}/Videos/subs_remuxed"
compression='--compression -1:none'
language='--language 0:pol'
charset='--sub-charset 0:UTF8'
forced='--forced-track 0'
force_sub_track=0

remuxSRT() {
    FILE="${1%.*}"
    SUBEXT="${1##*.}"
    VIDEXT=""
    FILEREMUX="${FILE}_remux.mkv"

    if [[ -f "$FILE.mp4" ]]; then
        VIDEXT="mp4"
    elif [[ -f "$FILE.avi" ]]; then
        VIDEXT="avi"
    elif [[ -f "$FILE.mkv" ]]; then
        VIDEXT="mkv"
    else
        echo "No files to remux"
    fi

    if [[ -n $VIDEXT ]]
    then
        MKVMERGE_CMD="mkvmerge -o \"$FILEREMUX\" $compression -S \"$FILE.mkv\" $language $charset"
        if [[ $force_sub_track -eq 1 ]]; then
            MKVMERGE_CMD+=" $forced"
        fi
        MKVMERGE_CMD+=" \"$FILE.$SUBEXT\""

        if eval "${MKVMERGE_CMD}"; then
            mv -f "$FILEREMUX" "$FILE".mkv
        else
            rm -f "$FILEREMUX"
        fi
        cleanup "$1"
    fi
}

cleanup() {
    if [[ -d $sub_dir ]]; then
        mv -f "$1" $sub_dir
    # else
    #     rm -f "$1"
    fi
}

if [[ "$1" == "-f" ]]; then
    force_sub_track=1
    shift
fi

# check arguments; if none print usage
if [[ -z $1 ]]
then
    echo
    echo "Usage: ${0##*/} FILE or DIRECTORY"
    echo
    exit
else
    echo
    echo "Remuxing:"
    for ITEM in "$@"
    do
        if [[ -d $ITEM ]]; then
            echo "directory $ITEM"
            SEARCHBASE=$ITEM
            SEARCHFILE='-name "*.srt" -or -name "*.ass"'
        else
            SEARCHBASE="$(dirname "$ITEM")"
            SEARCHFILE="-name \"${ITEM##*/}\" -and \( -name \"*.srt\" -or -name \"*.ass\" \)"
        fi
        FINDCMD="find \"$SEARCHBASE\" $SEARCHFILE"
        eval "${FINDCMD}" | sort | while read -r fname
        do
            echo "file $fname"
            remuxSRT "$fname"
        done
    done
fi
