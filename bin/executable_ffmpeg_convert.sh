#!/bin/bash

declare -a files_to_process

usage() {
    cat 1>&2 <<EOF
Convert files to mp4 with aac audio using ffmpeg

USAGE:
    $(basename "$0") [FLAGS] [FILE ...]

    FILE ...                  files to process

FLAGS:
    -h, --help                Prints help information
EOF
}

parse_commandline() {
    if [ $# == 0 ]; then
        usage
        exit 0
    fi

    while test $# -gt 0
    do
        key="$1"
        case "$key" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            files_to_process+=("$1")
            ;;
        esac
        shift
    done
}

convert() {
    for file in "${files_to_process[@]}"; do
        ffmpeg -y -i "$file" -s 1280x720 -b:v 4000k -c:v libx264 -b:a 160k -c:a aac -ac 2 -ar 44100 "${file%%.*}_.mp4"
    done
}

main() {
    parse_commandline "$@"
    convert
    exit 0
}

main "$@"
