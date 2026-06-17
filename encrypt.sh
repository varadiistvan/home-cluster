#!/bin/bash
set -u

EXTENSIONS="-secret\.yaml|\.tfstate|\.env\.bin|-secret.yaml.bin"

find . -type f \
  -regextype posix-extended \
  -regex ".*($EXTENSIONS)$" \
  -not -name "*.enc.*" \
  -not -path '*/.git/*' \
  -not -path '*/.terraform/*' \
  -print0 |
  while IFS= read -r -d '' src_file; do

    extension="${src_file##*.}"
    filename_no_ext="${src_file%.*}"
    enc_file="${filename_no_ext}.enc.${extension}"

    dir=$(dirname "$src_file")
    base_src=$(basename "$src_file")
    base_enc=$(basename "$enc_file")

    if [ ! -f "$enc_file" ]; then
      echo "   [NEW] Encrypting $src_file -> $enc_file"
      (cd "$dir" && sops --encrypt "$base_src" >"$base_enc")
      continue
    fi

    decrypted_shadow=$(cd "$dir" && sops --decrypt "$base_enc" 2>/dev/null)

    if [ $? -ne 0 ] || ! echo "$decrypted_shadow" | cmp -s - "$src_file"; then
      echo "   [MOD] Updating $enc_file"
      (cd "$dir" && sops --encrypt "$base_src" >"$base_enc")
    else
      true
    fi

  done

echo "Encryption sync complete."
