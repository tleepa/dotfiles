#!/bin/bash

set -euo pipefail

LANG="pl"
DEST="$HOME/Videos"
POSITIONAL_ARGS=()
DEPS=("jq" "mediainfo" "mkvmerge")

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
      -l | --lang)
        if [[ -n $2 && $2 != -* ]]; then
          LANG="$2"
          shift 2
        else
          die "'-l/--lang' requires an argument"
        fi
        ;;
      -d | --dest)
        if [[ -n $2 && $2 != -* ]]; then
          DEST="$2"
          shift 2
        else
          die "'-d/--dest' requires an argument"
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

process_files() {
  for ARG in "${POSITIONAL_ARGS[@]}"; do
    [ -e "$ARG" ] || die "file '$ARG' not found"
    FILENAME=${ARG##*/}
    FILE_INFO=$(mediainfo --Output=JSON "$ARG")
    LANG_ALL=$(jq '[.media.track[] | select(.["@type"]=="Text")]' <<<"$FILE_INFO")
    LANG_ITEMS=$(jq --arg LANG "$LANG" '[.[] | select(.Language==$LANG)]' <<<"$LANG_ALL")

    if [ "$LANG_ITEMS" == "[]" ]; then
      fail "language '$LANG' not found"
      say "list of available languages:" "$(jq -r '[.[].Language] | sort | unique | join(", ")' <<<"$LANG_ALL")"
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
