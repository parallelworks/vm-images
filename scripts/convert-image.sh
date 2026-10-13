#!/usr/bin/env bash
set -euo pipefail

: "${CLOUD:?CLOUD is required}"
: "${RAW:?RAW is required}"
: "${OUT:?OUT is required}"
: "${NAME:?NAME is required}"

if [[ ! -f "$RAW" ]]; then
  echo "raw image not found: $RAW" >&2
  exit 1
fi

case "$CLOUD" in
  azure)
    image="${NAME}.vhd"
    qemu-img convert -f raw -O vpc -o subformat=fixed,force_size=on "$RAW" "${OUT}/${image}"
    ;;
  aws|google)
    image="${NAME}.vhd"
    qemu-img convert -f raw -O vpc -o subformat=dynamic,force_size=on "$RAW" "${OUT}/${image}"
    ;;
  oracle)
    image="${NAME}.qcow2"
    qemu-img convert -f raw -O qcow2 -c "$RAW" "${OUT}/${image}"
    ;;
  *)
    echo "unsupported cloud: $CLOUD" >&2
    exit 1
    ;;
esac

qemu-img info "${OUT}/${image}"
rm -f "$RAW"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUT" && sha256sum "$image" > SHA256SUMS)
else
  (cd "$OUT" && shasum -a 256 "$image" > SHA256SUMS)
fi

cat "${OUT}/SHA256SUMS"
