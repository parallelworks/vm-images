#!/usr/bin/env bash
set -euo pipefail

names=(DISK_SIZE_GB ROOT_GB VAR_GB VAR_LOG_GB VAR_LOG_AUDIT_GB VAR_TMP_GB TMP_GB)
for n in "${names[@]}"; do
  v="${!n:-}"
  if [[ ! "$v" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error::${n}='${v}' must be a positive whole number of GiB"
    exit 1
  fi
done

fixed=$((ROOT_GB + VAR_GB + VAR_LOG_GB + VAR_LOG_AUDIT_GB + VAR_TMP_GB + TMP_GB))
reserved=1
home_min=1
min=$((fixed + reserved + home_min))

if ((DISK_SIZE_GB < min)); then
  echo "::error::disk_size_gb=${DISK_SIZE_GB} is too small. Need at least ${min} GiB: ${fixed} GiB of fixed partitions, ${reserved} GiB for EFI and biosboot, ${home_min} GiB minimum for /home."
  exit 1
fi

if ((DISK_SIZE_GB > 1023)); then
  echo "::warning::disk_size_gb=${DISK_SIZE_GB} is above 1023 GiB. Azure rejects VHDs larger than that."
fi

summary=$(cat <<EOF
| Mount | Size (GiB) |
| --- | --- |
| / | ${ROOT_GB} |
| /var | ${VAR_GB} |
| /var/log | ${VAR_LOG_GB} |
| /var/log/audit | ${VAR_LOG_AUDIT_GB} |
| /var/tmp | ${VAR_TMP_GB} |
| /tmp | ${TMP_GB} |
| /home | about $((DISK_SIZE_GB - fixed - reserved)) (remainder) |
| Disk total | ${DISK_SIZE_GB} |
EOF
)

echo "$summary"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "$summary" >> "$GITHUB_STEP_SUMMARY"
fi
