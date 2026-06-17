#!/bin/bash
set -u

find . -type f \
  -name "*.enc.*" \
  -not -path '*/.git/*' \
  -not -path '*/.terraform/*' \
  -print0 |
  while IFS= read -r -d '' enc_file; do

    dir=$(dirname "$enc_file")
    base_enc=$(basename "$enc_file")

    base_target="${base_enc/.enc./.}"

    target_file="$dir/$base_target"

    if [[ -f $target_file ]]; then
      echo "   Deleting $target_file"

      rm "${target_file}"
    fi

  done

echo "Purge complete."
