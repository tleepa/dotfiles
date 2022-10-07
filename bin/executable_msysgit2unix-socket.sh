#!/bin/bash

set -euo pipefail

exitmsg(){
  local exit_code=$1
  local exit_message="$2"
  echo "$exit_message"
  exit "$exit_code"
}

usage=$(cat << EOF

Usage: ${0##*/} source:destination [source:destination]

  source          path to source msysGit socket file
  destination     path to destination Unix socket file

EOF
)

if ! command -v socat >/dev/null; then
  exitmsg 1 "Package 'socat' needs to be installed!"
fi

[[ -z ${1:-""} ]] && exitmsg 0 "$usage"

pairs=()

while (( "$#" )); do
  key="$1"
  shift
  case "$key" in
    --*|-*)
      exitmsg 0 "$usage"
      exit 1 ;;
    *)
      pairs+=("$key")
  esac
done

for pair in "${pairs[@]}"
do
  source="${pair%%:*}"
  dest="${pair##*:}"
  msysgit_port=$(grep -oE '>([0-9]+)' "$source" | tr -d '>')

  [[ -f "$source" ]] || exitmsg 1 "File $source not found!"

  if (( msysgit_port > 0 )); then
    if pgrep -f "socat.*$dest.*$msysgit_port" >/dev/null; then
      exitmsg 0 "socat already running"
    else
      (&>/dev/null socat UNIX-LISTEN:"$dest",fork,reuseaddr,unlink-early,user="$USER",group=$(id -ng),mode=700 TCP:localhost:"$msysgit_port" &)
    fi
  else
    exitmsg 2 "bad port found in $source: $msysgit_port"
  fi
done
