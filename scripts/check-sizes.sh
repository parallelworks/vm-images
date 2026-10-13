#!/usr/bin/env bash
set -euo pipefail

names=(ROOT_GB VAR_GB VAR_LOG_GB VAR_LOG_AUDIT_GB VAR_TMP_GB TMP_GB HOME_GB)
for n in "${names[@]}"; do
  v="${!n:-}"
  if [[ ! "$v" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error::${n}='${v}' must be a positive whole number of GiB"
    exit 1
  fi
done

grow="${GROW_PARTITION:-home}"
case "$grow" in
  root | var | var_log | var_log_audit | var_tmp | tmp | home) ;;
  *)
    echo "::error::GROW_PARTITION='${grow}' must be one of: root, var, var_log, var_log_audit, var_tmp, tmp, home"
    exit 1
    ;;
esac

efi=1
disk=$((ROOT_GB + VAR_GB + VAR_LOG_GB + VAR_LOG_AUDIT_GB + VAR_TMP_GB + TMP_GB + HOME_GB + efi))

if ((disk > 1023)); then
  echo "::warning::The disk would be ${disk} GiB. Azure rejects VHDs larger than 1023 GiB."
fi

row() {
  local key=$1 mount=$2 size=$3
  if [[ "$key" == "$grow" ]]; then
    echo "| ${mount} | ${size} (grows) |"
  else
    echo "| ${mount} | ${size} |"
  fi
}

summary=$(
  echo "| Mount | Size (GiB) |"
  echo "| --- | --- |"
  echo "| /boot/efi | 0.6 |"
  row root / "$ROOT_GB"
  row var /var "$VAR_GB"
  row var_log /var/log "$VAR_LOG_GB"
  row var_log_audit /var/log/audit "$VAR_LOG_AUDIT_GB"
  row var_tmp /var/tmp "$VAR_TMP_GB"
  row tmp /tmp "$TMP_GB"
  row home /home "$HOME_GB"
  echo "| Disk total | ${disk} |"
)

echo "$summary"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "$summary" >> "$GITHUB_STEP_SUMMARY"
fi
