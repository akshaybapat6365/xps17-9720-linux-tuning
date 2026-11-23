# Maintainer: Akshay Bapat <https://github.com/akshaybapat6365>
pkgname=xps17-9720-linux-tuning
pkgver=0.1.0
pkgrel=1
pkgdesc='Sustained-heat fan governor, battery cap, NVIDIA D3cold, scx_lavd, Wi-Fi, I2C awake & D65 ICC tuning for Dell XPS 17 9720'
arch=('any')
url='https://github.com/akshaybapat6365/xps17-9720-linux-tuning'
license=('MIT')
depends=('python' 'systemd' 'bash')
optdepends=(
  'scx-scheds: scx_lavd BPF scheduler for hybrid P+E cores'
  'hyprland: SHP1517 D65 wide-gamut ICC clamp'
)
source=()

package() {
  local srcroot="${startdir}"
  local share="$pkgdir/usr/share/$pkgname"

  install -dm755 "$share"/{governor,kernel,systemd,bin,udev,modprobe,scx,icc,hypr}
  install -Dm755 "$srcroot/governor/xps17-fan-governor" "$share/governor/xps17-fan-governor"
  install -Dm644 "$srcroot/kernel/xps17-9720-fan-control.patch" "$share/kernel/xps17-9720-fan-control.patch"
  install -Dm644 "$srcroot/systemd/xps17-fan-governor.service" "$share/systemd/xps17-fan-governor.service"
  install -Dm644 "$srcroot/systemd/10-quiet-sustained.conf" "$share/systemd/10-quiet-sustained.conf"
  install -Dm755 "$srcroot/bin/omarchy-battery-cap" "$share/bin/omarchy-battery-cap"
  install -Dm755 "$srcroot/bin/omarchy-battery-cap" "$pkgdir/usr/bin/omarchy-battery-cap"
  install -Dm644 "$srcroot/udev/82-xps17-battery-cap.rules" "$share/udev/82-xps17-battery-cap.rules"
  install -Dm644 "$srcroot/udev/81-xps17-touchscreen-power.rules" "$share/udev/81-xps17-touchscreen-power.rules"
  install -Dm644 "$srcroot/udev/99-i2c-touchpad-controller-awake.rules" "$share/udev/99-i2c-touchpad-controller-awake.rules"
  install -Dm644 "$srcroot/modprobe/dell-smm-hwmon-xps17.conf" "$share/modprobe/dell-smm-hwmon-xps17.conf"
  install -Dm644 "$srcroot/modprobe/iwlwifi.conf" "$share/modprobe/iwlwifi.conf"
  install -Dm644 "$srcroot/modprobe/nvidia-power.conf" "$share/modprobe/nvidia-power.conf"
  install -Dm644 "$srcroot/scx/config.toml" "$share/scx/config.toml"
  install -Dm644 "$srcroot/icc/SHP1517-d65.icc" "$share/icc/SHP1517-d65.icc"
  install -Dm644 "$srcroot/hypr/monitors.xps17.lua.example" "$share/hypr/monitors.xps17.lua.example"
  install -Dm755 "$srcroot/install.sh" "$share/install.sh"
  install -Dm755 "$srcroot/uninstall.sh" "$share/uninstall.sh"
  install -Dm644 "$srcroot/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

  install -dm755 "$pkgdir/usr/bin"
  cat >"$pkgdir/usr/bin/xps17-9720-tuning-apply" <<'EOF'
#!/usr/bin/env bash
exec /usr/share/xps17-9720-linux-tuning/install.sh "$@"
EOF
  chmod 0755 "$pkgdir/usr/bin/xps17-9720-tuning-apply"
}
