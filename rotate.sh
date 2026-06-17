#!/bin/bash
set -u

# Finds all encrypted files, decrypts them to memory, and re-encrypts them in-place.
# This forces SOPS to re-evaluate your .sops.yaml rules (e.g., adding/removing keys).

find . -type f \
  -name "*.enc.*" \
  -not -path '*/.git/*' \
  -not -path '*/.terraform/*' \
  -print0 |
  while IFS= read -r -d '' enc_file; do

    dir=$(dirname "$enc_file")
    base_enc=$(basename "$enc_file")
    
    echo "   [ROTATE] Updating keys for $enc_file"

    # PIPELINE EXPLANATION:
    # 1. (cd "$dir" ...)         -> Ensure we are in the correct relative path context.
    # 2. sops --decrypt          -> Outputs the plain text content to STDOUT.
    # 3. sops --encrypt          -> Reads from STDIN (/dev/stdin).
    # 4. --filename-override     -> CRITICAL: Tells SOPS to use this name to find 
    #                               creation rules in .sops.yaml.

    if (cd "$dir" && sops --decrypt "$base_enc" | sops --encrypt --filename-override "$base_enc" /dev/stdin > "${base_enc}.tmp"); then
        
        # Verify the temp file isn't empty before overwriting
        if [ -s "$dir/${base_enc}.tmp" ]; then
            mv "$dir/${base_enc}.tmp" "$enc_file"
        else
            echo "       [ERR] Re-encryption resulted in empty file. Skipping."
            rm "$dir/${base_enc}.tmp"
            exit 1
        fi
        
    else
        echo "       [ERR] Failed to rotate $base_enc"
        # Cleanup temp file if it exists
        [ -f "$dir/${base_enc}.tmp" ] && rm "$dir/${base_enc}.tmp"
        exit 1
    fi

  done

echo "Key rotation complete."
