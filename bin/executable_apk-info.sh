#!/bin/bash

set -euo pipefail

declare -a files_to_process
GOOGLE_PLAY_URL="https://play.google.com/store/apps/details?id="
APK_PURE_URL="https://apkpure.com/sygic-gps-navigation-maps/"
DEPS=("mkvmerge")

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
  cat <<EOF
Shows basic info on Android apk file.

Usage: ${0##*/} [FLAGS] FILE

  FILE            path to apk file

FLAGS:
  -h, --help                Prints help information
  -r, --rename              Rename apk file to "<application name> <version>"
  -b, --build-id            Include build version in renamed apk file:
                            "<application name> <version>.<build>"
EOF
}

parse_commandline() {
  if [ $# == 0 ]; then
    usage
    exit 0
  fi

  while [ $# -gt 0 ]; do
    key="$1"
    case "$key" in
    -h|--help)
      usage
      exit 0
      ;;
    -r|--rename)
      RENAME=1
      ;;
    -b|--buildid)
      INCLUDE_BUILD=1
      ;;
    *)
      [[ -f "$1" ]] && files_to_process+=("$1") || fail "$1 not found!"
      ;;
    esac
    shift
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

collect_info() {
  currentName=${1##*/}

  badging=$(aapt2 dump badging "$1" 2>/dev/null)

  appName=$(grep -oP "application-label:'\K(.*)(?=')" <<<"$badging")
  packageName=$(grep -oP "package: name='\K(.*?)(?=')" <<<"$badging")
  versionName=$(grep -oP "versionName='\K(.*?)(?=')" <<<"$badging")
  versionCode=$(grep -oP "versionCode='\K([\d]+)(?=')" <<<"$badging")
  renameTo="$appName $versionName.apk"
  if [[ ${INCLUDE_BUILD:-0} == 1 ]]; then
    renameTo="${renameTo%.*}.$versionCode.apk"
  fi
}

print_info() {
  say
  say "Processing file: $currentName"
  say
  say "         Package name: $packageName"
  say "       Play Store URL: $GOOGLE_PLAY_URL$packageName"
  say "         APK Pure URL: $APK_PURE_URL$packageName"
  say "    Application label: $appName"
  say "       Version number: $versionName"
  say "         Build number: $versionCode"
  say "            Rename to: $renameTo"
}

rename_apk() {
  fPath=${1%%/*}
  fName=${1##*/}
  mv "$fPath/$fName" "$fPath/$renameTo"
  say
  ok "Renamed file $fName to $renameTo in $fPath"
}

main() {
  parse_commandline "$@"
	check_deps

  for file in "${files_to_process[@]}"; do
    collect_info "$file"
    if [[ ${RENAME:-0} == 1 ]]; then
      rename_apk "$file"
    else
      print_info
    fi
  done
  exit 0
}

main "$@"
