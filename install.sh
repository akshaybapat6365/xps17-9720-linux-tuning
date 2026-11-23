#!/usr/bin/env bash
# install.sh — Modular, DMI-guarded hardware tuning installer for Dell XPS 17 9720 (Linux / Omarchy).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DO_FANS=0
DO_BATTERY=0
DO_INPUT=0
DO_GPU=0
DO_WIFI=0
DO_SCHED=0
DO_ICC=0
FORCE=0
DRY_RUN=0
ROOT_PREFIX=""
USER_HOME="$HOME"
DMI_PRODUCT_PATH="/sys/class/dmi/id/product_name"

usage() {
  cat <<'EOF'
Usage: ./install.sh [MODULES...] [OPTIONS]

Safely install Dell XPS 17 9720 hardware tuning modules.
Enforces a mandatory DMI product-name check ("XPS 17 9720") before writing
hardware-specific configs unless --force is explicitly passed.

Modules (select one or more, or --all):
  --fans       Install xps17-fan-governor, systemd unit, 10-quiet-sustained.conf drop-in,
               and dell-smm-hwmon modprobe option
  --battery    Install omarchy-battery-cap CLI and 82-xps17-battery-cap.rules (55-80% cap)
  --input      Install LPSS I2C power rules for ELAN touchscreen & touchpad awake guards
  --gpu        Install NVIDIA S0ix / D3cold power management modprobe config
  --wifi       Install Intel AX211 iwlmvm active power_scheme=1 modprobe config
  --sched      Install scx_loader config.toml (scx_lavd for hybrid i9-12900HK P+E cores)
  --icc        Install Sharp SHP1517 D65 wide-gamut ICC profile to ~/.local/share/icc/
  --all        Enable all modules above

Options:
  --dry-run    Print planned actions without writing files or reloading services
  --force      Override the Dell XPS 17 9720 DMI hardware guard (USE WITH CAUTION)
  --root DIR   Install system files under DIR instead of / (for packaging / sandbox tests)
  -h, --help   Show this help message
EOF
}

ANY_MODULE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fans)    DO_FANS=1; ANY_MODULE=1; shift ;;
    --battery) DO_BATTERY=1; ANY_MODULE=1; shift ;;
    --input)   DO_INPUT=1; ANY_MODULE=1; shift ;;
    --gpu)     DO_GPU=1; ANY_MODULE=1; shift ;;
    --wifi)    DO_WIFI=1; ANY_MODULE=1; shift ;;
    --sched)   DO_SCHED=1; ANY_MODULE=1; shift ;;
    --icc)     DO_ICC=1; ANY_MODULE=1; shift ;;
    --all)
      DO_FANS=1; DO_BATTERY=1; DO_INPUT=1; DO_GPU=1; DO_WIFI=1; DO_SCHED=1; DO_ICC=1
      ANY_MODULE=1; shift
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1; shift ;;
    --root)
      [[ $# -ge 2 ]] || { echo "error: --root requires a directory" >&2; exit 2; }
      ROOT_PREFIX="${2%/}"; shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if (( ANY_MODULE == 0 )); then
  echo "error: specify at least one module (--fans, --battery, --input, --gpu, --wifi, --sched, --icc, or --all)" >&2
  echo >&2
  usage >&2
  exit 2
fi

# ---- Mandatory Hardware DMI Guard -------------------------------------------
DETECTED_PRODUCT="unknown"
if [[ -r "$DMI_PRODUCT_PATH" ]]; then
  DETECTED_PRODUCT="$(tr -d '\r\n' < "$DMI_PRODUCT_PATH" 2>/dev/null || echo unknown)"
fi

if [[ "$DETECTED_PRODUCT" != *"XPS 17 9720"* ]]; then
  if (( FORCE == 1 )); then
    echo "WARNING: Hardware DMI guard overridden via --force (detected: '$DETECTED_PRODUCT', expected: 'XPS 17 9720')." >&2
  else
    echo "ERROR: Refusing to install Dell XPS 17 9720 hardware configs on unrecognized hardware." >&2
    echo "       Detected /sys/class/dmi/id/product_name: '$DETECTED_PRODUCT'" >&2
    echo "       Expected product name containing:        'XPS 17 9720'" >&2
    echo "       Pass --force ONLY if you have audited PCI IDs, SMM opcodes, and panel ICC for your hardware." >&2
    exit 1
  fi
else
  echo "==> DMI hardware guard passed: $DETECTED_PRODUCT"
fi

# Determine privilege escalation for real system root (skip sudo when --root or --dry-run or root)
NEEDS_SYSTEM=$(( DO_FANS | DO_BATTERY | DO_INPUT | DO_GPU | DO_WIFI | DO_SCHED ))
RUN_ROOT=()
if (( NEEDS_SYSTEM == 1 && DRY_RUN == 0 )) && [[ -z "$ROOT_PREFIX" ]] && [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    RUN_ROOT=(sudo)
  else
    echo "error: root privileges required to write under /etc and /usr/local (run as root or install sudo)" >&2
    exit 1
  fi
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
install_sys() {
  local mode="$1" src="$2" dst="${ROOT_PREFIX}$3"
  if (( DRY_RUN == 1 )); then
    echo "  [dry-run] install -m $mode $src -> $dst"
    return 0
  fi
  "${RUN_ROOT[@]}" mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    "${RUN_ROOT[@]}" cp -p "$dst" "${dst}.bak.${STAMP}"
    echo "  [backup]  ${dst}.bak.${STAMP}"
  fi
  "${RUN_ROOT[@]}" install -m "$mode" "$src" "$dst"
  echo "  [install] $dst"
}

install_user() {
  local mode="$1" src="$2" dst="$3"
  if (( DRY_RUN == 1 )); then
    echo "  [dry-run] install -m $mode $src -> $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  install -m "$mode" "$src" "$dst"
  echo "  [install] $dst"
}

RELOAD_SYSTEMD=0
RELOAD_UDEV=0

if (( DO_FANS == 1 )); then
  echo "==> Module: Sustained-heat fan governor (--fans)"
  install_sys 0755 "$SCRIPT_DIR/governor/xps17-fan-governor" "/usr/local/lib/xps17-fan-control/xps17-fan-governor"
  install_sys 0644 "$SCRIPT_DIR/systemd/xps17-fan-governor.service" "/etc/systemd/system/xps17-fan-governor.service"
  install_sys 0644 "$SCRIPT_DIR/systemd/10-quiet-sustained.conf" "/etc/systemd/system/xps17-fan-governor.service.d/10-quiet-sustained.conf"
  install_sys 0644 "$SCRIPT_DIR/modprobe/dell-smm-hwmon-xps17.conf" "/etc/modprobe.d/dell-smm-hwmon-xps17.conf"
  RELOAD_SYSTEMD=1
fi

if (( DO_BATTERY == 1 )); then
  echo "==> Module: Battery 55-80% desk charge cap (--battery)"
  install_user 0755 "$SCRIPT_DIR/bin/omarchy-battery-cap" "$USER_HOME/.local/bin/omarchy-battery-cap"
  install_sys 0644 "$SCRIPT_DIR/udev/82-xps17-battery-cap.rules" "/etc/udev/rules.d/82-xps17-battery-cap.rules"
  RELOAD_UDEV=1
fi

if (( DO_INPUT == 1 )); then
  echo "==> Module: LPSS I2C touchscreen & touchpad awake guards (--input)"
  install_sys 0644 "$SCRIPT_DIR/udev/81-xps17-touchscreen-power.rules" "/etc/udev/rules.d/81-xps17-touchscreen-power.rules"
  install_sys 0644 "$SCRIPT_DIR/udev/99-i2c-touchpad-controller-awake.rules" "/etc/udev/rules.d/99-i2c-touchpad-controller-awake.rules"
  RELOAD_UDEV=1
fi

if (( DO_GPU == 1 )); then
  echo "==> Module: NVIDIA RTX 3060 S0ix / D3cold power management (--gpu)"
  install_sys 0644 "$SCRIPT_DIR/modprobe/nvidia-power.conf" "/etc/modprobe.d/nvidia-power.conf"
fi

if (( DO_WIFI == 1 )); then
  echo "==> Module: Intel AX211 low-latency Wi-Fi power_scheme=1 (--wifi)"
  install_sys 0644 "$SCRIPT_DIR/modprobe/iwlwifi.conf" "/etc/modprobe.d/iwlwifi.conf"
fi

if (( DO_SCHED == 1 )); then
  echo "==> Module: scx_lavd hybrid P+E core scheduler (--sched)"
  install_sys 0644 "$SCRIPT_DIR/scx/config.toml" "/etc/scx_loader/config.toml"
fi

if (( DO_ICC == 1 )); then
  echo "==> Module: Sharp SHP1517 D65 wide-gamut ICC clamp (--icc)"
  install_user 0644 "$SCRIPT_DIR/icc/SHP1517-d65.icc" "${XDG_DATA_HOME:-$USER_HOME/.local/share}/icc/SHP1517-d65.icc"
  echo "  [info]    See hypr/monitors.xps17.lua.example to wire the ICC clamp in Hyprland."
fi

if (( DRY_RUN == 0 )) && [[ -z "$ROOT_PREFIX" ]]; then
  if (( RELOAD_SYSTEMD == 1 )) && command -v systemctl >/dev/null 2>&1; then
    "${RUN_ROOT[@]}" systemctl daemon-reload
    echo "==> Reloaded systemd daemon (enable with: sudo systemctl enable --now xps17-fan-governor.service)"
  fi
  if (( RELOAD_UDEV == 1 )) && command -v udevadm >/dev/null 2>&1; then
    "${RUN_ROOT[@]}" udevadm control --reload-rules
    "${RUN_ROOT[@]}" udevadm trigger --subsystem-match=power_supply --subsystem-match=pci 2>/dev/null || true
    echo "==> Reloaded udev rules"
  fi
fi

echo
echo "Done! Modprobe changes (--gpu, --wifi, --fans) take full effect after reboot / initramfs refresh."
