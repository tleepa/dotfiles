#!/bin/bash

set -euo pipefail

DEST="$HOME/Videos"
DEST_SUB="$HOME/Videos/subs_remuxed"
POSITIONAL_ARGS=()
DEPS=("mkvmerge")
LANGUAGE='--language 0:pol'
CHARSET='--sub-charset 0:UTF8'

ESC="$(printf '\033')"
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD="${ESC}[1m" DIM="${ESC}[2m" RED="${ESC}[31m" GREEN="${ESC}[32m"
  YELLOW="${ESC}[33m" RESET="${ESC}[0m"
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" RESET=""
fi

title() { printf '%s\n' "${BOLD}$*${RESET}"; }
say() { printf '%s\n' "$*"; }
ok() { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}!${RESET} $*"; }
fail() { printf '%s\n' "${RED}error:${RESET} $*" >&2; }
die() {
  fail "$@"
  exit 1
}

usage() {
  cat 1>&2 <<EOF
Finds subtitle files and remuxes them with the matching video files (mp4/mkv)
stripping existing subtitles and copying other parts (video/udio/chapters) untouched.

USAGE:
    ${0##*/} [OPTIONS] [FILE/DIRECTORY...]

OPTIONS:
    -h, --help          Show this help message
    -d, --dest          Destination directory, defaults to \$HOME/Videos
    -s, --dest-sub      Destination directory for subtitles,
                        defaults to \$HOME/Videos/subs_remuxed

NOTES:
    This script requires: ${DEPS[@]}
EOF
}

parse_commandline() {
  if [ $# == 0 ]; then
    usage
    exit 0
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -d | --dest)
        if [[ -n $2 && $2 != -* ]]; then
          DEST=$(realpath "$2")
          shift 2
        else
          die "'-d/--dest' requires an argument"
        fi
        ;;
      -s | --dest-sub)
        if [[ -n $2 && $2 != -* ]]; then
          DEST_SUB="$2"
          shift 2
        else
          die "'-s/--dest-sub' requires an argument"
        fi
        ;;
      -*)
        die "Unknown option '$1'"
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
      fail "dependency '$DEP' not found"
      CHECK_DEPS=false
    fi
  done

  if [[ $CHECK_DEPS == false ]]; then
    exit 1
  fi
}

remuxSRT() {
  FILE="${1%.*}"
  FILEDIR="${1%/*}"
  FILENAME="${FILE##*/}"
  SUBEXT="${1##*.}"
  VIDEXT=""

  if [[ "$FILEDIR" == "$DEST" ]]; then
    FILEREMUX="${FILE}_remux.mkv"
  else
    FILEREMUX="${DEST}/${FILENAME}.mkv"
  fi

  if [[ -f "$FILE.mp4" ]]; then
    VIDEXT="mp4"
  elif [[ -f "$FILE.mkv" ]]; then
    VIDEXT="mkv"
  else
    fail "No files to remux"
  fi

  if [[ -n $VIDEXT ]]; then
    MKVMERGE_CMD="mkvmerge -o \"$FILEREMUX\" -S \"$FILE.mkv\" $LANGUAGE $CHARSET"
    MKVMERGE_CMD+=" \"$FILE.$SUBEXT\""

    if ! eval "${MKVMERGE_CMD}"; then
      rm -f "$FILEREMUX"
    fi

    cleanup "$1"
  fi
}

cleanup() {
  if [[ -d $DEST_SUB ]]; then
    mv -f "$1" $DEST_SUB
  # else
  #     rm -f "$1"
  fi
}

main() {
  check_deps
  parse_commandline "$@"

  say
  say "Remuxing:"
  for ITEM in "${POSITIONAL_ARGS[@]}"; do
    if [[ -d $ITEM ]]; then
      say "directory $ITEM"
      SEARCHBASE=$(realpath $ITEM)
      SEARCHFILE='-name "*.srt" -or -name "*.ass"'
    else
      SEARCHBASE="$(realpath "${ITEM%/*}")"
      SEARCHFILE="-name \"${ITEM##*/}\" -and \( -name \"*.srt\" -or -name \"*.ass\" \)"
    fi
    FINDCMD="find \"$SEARCHBASE\" $SEARCHFILE"
    eval "${FINDCMD}" | sort | while read -r fname; do
      say "file $fname"
      remuxSRT "$fname"
    done
  done

  exit 0
}

main "$@"
