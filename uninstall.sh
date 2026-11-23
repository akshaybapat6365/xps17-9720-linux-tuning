#!/usr/bin/env bash
# uninstall.sh — Cleanly remove installed Dell XPS 17 9720 tuning modules.
set -euo pipefail

DO_FANS=0
DO_BATTERY=0
DO_INPUT=0
DO_GPU=0
DO_WIFI=0
DO_SCHED=0
DO_ICC=0
ROOT_PREFIX=""
USER_HOME="$HOME"

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [MODULES...] [--root DIR]

Remove installed XPS 17 9720 tuning modules (defaults to --all if no module flag is given).

Modules: --fans, --battery, --input, --gpu, --wifi, --sched, --icc, --all
Options: --root DIR   Remove system files under DIR instead of /
EOF
}

ANY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fans)    DO_FANS=1; ANY=1; shift ;;
    --battery) DO_BATTERY=1; ANY=1; shift ;;
    --input)   DO_INPUT=1; ANY=1; shift ;;
    --gpu)     DO_GPU=1; ANY=1; shift ;;
    --wifi)    DO_WIFI=1; ANY=1; shift ;;
    --sched)   DO_SCHED=1; ANY=1; shift ;;
    --icc)     DO_ICC=1; ANY=1; shift ;;
    --all)     DO_FANS=1; DO_BATTERY=1; DO_INPUT=1; DO_GPU=1; DO_WIFI=1; DO_SCHED=1; DO_ICC=1; ANY=1; shift ;;
    --root)    ROOT_PREFIX="${2%/}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if (( ANY == 0 )); then
  DO_FANS=1; DO_BATTERY=1; DO_INPUT=1; DO_GPU=1; DO_WIFI=1; DO_SCHED=1; DO_ICC=1
fi

RUN_ROOT=()
if [[ -z "$ROOT_PREFIX" ]] && [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 && RUN_ROOT=(sudo)
fi

rm_sys() {
  local p="${ROOT_PREFIX}$1"
  if [[ -e "$p" ]]; then
    "${RUN_ROOT[@]}" rm -f "$p"
    echo "Removed: $p"
  fi
}

if (( DO_FANS == 1 )); then
  if [[ -z "$ROOT_PREFIX" ]] && command -v systemctl >/dev/null 2>&1; then
    "${RUN_ROOT[@]}" systemctl disable --now xps17-fan-governor.service 2>/dev/null || true
  fi
  rm_sys "/etc/systemd/system/xps17-fan-governor.service.d/10-quiet-sustained.conf"
  rm_sys "/etc/systemd/system/xps17-fan-governor.service"
  rm_sys "/usr/local/lib/xps17-fan-control/xps17-fan-governor"
  rm_sys "/etc/modprobe.d/dell-smm-hwmon-xps17.conf"
fi

if (( DO_BATTERY == 1 )); then
  rm -f "$USER_HOME/.local/bin/omarchy-battery-cap"
  rm_sys "/etc/udev/rules.d/82-xps17-battery-cap.rules"
fi

if (( DO_INPUT == 1 )); then
  rm_sys "/etc/udev/rules.d/81-xps17-touchscreen-power.rules"
  rm_sys "/etc/udev/rules.d/99-i2c-touchpad-controller-awake.rules"
fi

(( DO_GPU == 1 ))   && rm_sys "/etc/modprobe.d/nvidia-power.conf"
(( DO_WIFI == 1 ))  && rm_sys "/etc/modprobe.d/iwlwifi.conf"
(( DO_SCHED == 1 )) && rm_sys "/etc/scx_loader/config.toml"

if (( DO_ICC == 1 )); then
  icc="${XDG_DATA_HOME:-$USER_HOME/.local/share}/icc/SHP1517-d65.icc"
  [[ -f "$icc" ]] && rm -f "$icc" && echo "Removed: $icc"
fi

if [[ -z "$ROOT_PREFIX" ]]; then
  command -v systemctl >/dev/null 2>&1 && "${RUN_ROOT[@]}" systemctl daemon-reload 2>/dev/null || true
  command -v udevadm >/dev/null 2>&1 && "${RUN_ROOT[@]}" udevadm control --reload-rules 2>/dev/null || true
fi

echo "Uninstall complete."
