#!/bin/bash

set -euo pipefail

usage() {
  cat << EOF
Shows basic info on Android apk file.

Usage: ${0##*/} [FLAGS]

  FILE            path to apk file

FLAGS:
  -h, --help                Prints help information
  -t, --time                How long should screen lock be disabled
                            Use values with units (e.g., 30s, 5m, 1h)
  -d, --debug               Debug info
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
    -d|--debug)
      DEBUG=1 ;;
    -t|--time)
      DURATION=$2
      case ${DURATION: -1:1} in
      s)
        DURATION_SEC=${2: 0:-1}
        DURATION_UNIT="s"
        ;;
      m)
        DURATION_SEC=$((${2: 0:-1} * 60))
        DURATION_UNIT="m"
        ;;
      h)
        DURATION_SEC=$((${2: 0:-1} * 3600))
        DURATION_UNIT="h"
        ;;
      *)
        DURATION_UNIT="s"
        DURATION_SEC=$2
        ;;
      esac
      shift 1
      ;;
    esac
    shift 1
  done
}

main() {
  parse_commandline "$@"

  if [[ ${DEBUG:-0} == 1 ]]; then
    echo "disable lock for          = $DURATION"
    echo "disable lock unit         = $DURATION_UNIT"
    echo "disable lock for seconds  = $DURATION_SEC"
  fi

  SECONDS=0
  INTERVAL=60
  while [[ $SECONDS -lt $DURATION_SEC ]]; do
    qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity >/dev/null
    notify-send -a Reminder "Disabled screen lock in progress!" -i dialog-inormation
    if [[ $((($DURATION_SEC - $SECONDS) % $INTERVAL)) == 0 ]]; then
      SLEEP_MORE=$INTERVAL
    else
      SLEEP_MORE=$((($DURATION_SEC - $SECONDS) % $INTERVAL))
    fi
    if [[ ${DEBUG:-0} == 1 ]]; then
      echo "sleep for next seconds    = $SLEEP_MORE"
    fi
    sleep $SLEEP_MORE
  done

  exit 0
}

main "$@"
