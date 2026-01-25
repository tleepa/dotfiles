#!/bin/bash

set -euo pipefail

LANG="pl"
DEST="$HOME/Videos"
POSITIONAL_ARGS=()
DEPS=("jq" "mediainfo" "mkvmerge")

usage() {
  cat 1>&2 <<EOF
Strips subtitles other than provided language

USAGE:
    ${0##*/} [OPTIONS] [FILE...]

OPTIONS:
    -h, --help            Show this help message
    -l, --lang LANG       Set language (e.g. pl, en), defaults to pl
    -d, --dest            Destination directory, defaults to \$HOME/Videos

NOTES:
    This script requires: ${DEPS[@]}
EOF
}

output() {
  MESSAGES=()
  NOEXIT=""
  while test $# -gt 0; do
    key="$1"
    case "$key" in
      -t | --type)
        if [[ -n $2 && $2 != -* ]]; then
          TYPE="$2"
          shift 2
        else
          output -t ERRR "'-t/--type' requires an argument" >&2
          exit 1
        fi
        ;;
      -n | --no-exit)
        NOEXIT="yes"
        shift
        ;;
      *)
        MESSAGES+=("$1")
        shift
        ;;
    esac
  done

  for MSG in "${MESSAGES[@]}"; do
    echo "${TYPE}: ${MSG}"
  done
  if [[ -z $NOEXIT ]]; then
    exit 1
  fi
}

parse_commandline() {
  if [ $# == 0 ]; then
    usage
    exit 0
  fi

  while test $# -gt 0; do
    key="$1"
    case "$key" in
      -l | --lang)
        if [[ -n $2 && $2 != -* ]]; then
          LANG="$2"
          shift 2
        else
          output -t ERRR "'-l/--lang' requires an argument" >&2
          exit 1
        fi
        ;;
      -d | --dest)
        if [[ -n $2 && $2 != -* ]]; then
          DEST="$2"
          shift 2
        else
          output -t ERRR "'-d/--dest' requires an argument" >&2
          exit 1
        fi
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        output -t ERRR "Unknown option '$1'" >&2
        exit 1
        ;;
      *)
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

check_deps() {
  CHECK_DEPS=true
  for DEP in "${DEPS[@]}"; do
    if ! command -v "$DEP" >/dev/null; then
      output -t ERRR -n "dependency '$DEP' not found"
      CHECK_DEPS=false
    fi
  done

  if [[ $CHECK_DEPS == false ]]; then
    exit 1
  fi
}

process_files() {
  for ARG in "${POSITIONAL_ARGS[@]}"; do
    [ -e "$ARG" ] || output -t ERRR "file '$ARG' not found"
    FILENAME=${ARG##*/}
    FILE_INFO=$(mediainfo --Output=JSON "$ARG")
    LANG_ALL=$(jq '[.media.track[] | select(.["@type"]=="Text")]' <<<"$FILE_INFO")
    LANG_ITEMS=$(jq --arg LANG "$LANG" '[.[] | select(.Language==$LANG)]' <<<"$LANG_ALL")

    if [ "$LANG_ITEMS" == "[]" ]; then
      output -t ERRR -n "language '$LANG' not found"
      output -t INFO -n "list of available languages:" "$(jq -r '[.[].Language] | sort | unique | join(", ")' <<<"$LANG_ALL")"
      exit 1
    fi
    LANG_IDXS=$(jq -r '[.[].StreamOrder] | join(",")' <<<"$LANG_ITEMS")

    mkvmerge -o "${DEST}/${FILENAME}" -s "$LANG_IDXS" "$ARG"
  done
}

main() {
  check_deps
  parse_commandline "$@"
  process_files
  exit 0
}

main "$@"
