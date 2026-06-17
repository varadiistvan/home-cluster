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

    echo "   Restoring $target_file"

    (cd "$dir" && sops --decrypt "$base_enc" >"$base_target")

  done

echo "Restoration complete."
