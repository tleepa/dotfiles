#!/bin/bash

set -euo pipefail

copy_to_clipboard() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    pbcopy
  elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v wl-copy &> /dev/null; then
      wl-copy
    fi
  elif [[ -n "${DISPLAY:-}" ]]; then
    if command -v xclip &> /dev/null; then
      xclip -selection clipboard
    elif command -v xsel &> /dev/null; then
      xsel --clipboard --input
    fi
  fi
}

kroki=${1:-"https://kroki.io"}

input=$(cat)

diagram_type=$(head -n 1 <<< "$input" | tr -d '`')
diagram_content=$(awk '! /```/' <<< "$input")
diagram_encoded=$(echo -n "$diagram_content" | python3 -c "import sys; import base64; import zlib; print(base64.urlsafe_b64encode(zlib.compress(sys.stdin.read().encode('utf-8'), 9)).decode('ascii'))")
echo "![]($kroki/$diagram_type/svg/$diagram_encoded)" | copy_to_clipboard
