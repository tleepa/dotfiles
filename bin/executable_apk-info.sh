#!/bin/bash

set -euo pipefail

declare -a files_to_process
GOOGLE_PLAY_URL="https://play.google.com/store/apps/details?id="
APK_PURE_URL="https://apkpure.com/sygic-gps-navigation-maps/"

exitmsg() {
  local exit_code=$1
  local exit_message="$2"
  echo "$exit_message"
  exit "$exit_code"
}

usage() {
  cat <<EOF
Shows basic info on Android apk file.

Usage: ${0##*/} [FLAGS] FILE

  FILE            path to apk file

FLAGS:
  -h, --help                Prints help information
  -r, --rename              Rename apk file to "<application name> <version>"
  -b, --buildid             Include build version in renamed apk file:
                            "<application name> <version>.<build>"
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
    -r|--rename)
      RENAME=1
      ;;
    -b|--buildid)
      INCLUDE_BUILD=1
      ;;
    *)
      files_to_process+=("$1")
      ;;
    esac
    shift
  done
}

if ! command -v aapt2 >/dev/null; then
  exitmsg 1 "'aapt2' is required!"
fi

[[ -f "$1" ]] || exitmsg 1 "$1 not found!"

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
  echo
  echo "Processing file: $currentName"
  echo
  echo "         Package name: $packageName"
  echo "       Play Store URL: $GOOGLE_PLAY_URL$packageName"
  echo "         APK Pure URL: $APK_PURE_URL$packageName"
  echo "    Application label: $appName"
  echo "       Version number: $versionName"
  echo "         Build number: $versionCode"
  echo "            Rename to: $renameTo"
}

rename_apk() {
  fPath=${1%%/*}
  fName=${1##*/}
  mv "$fPath/$fName" "$fPath/$renameTo"
  echo
  echo "Renamed file $fName to $renameTo in $fPath"
}

main() {
  parse_commandline "$@"

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
