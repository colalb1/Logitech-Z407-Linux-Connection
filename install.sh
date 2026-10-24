#!/usr/bin/env bash
# Installs missing dependencies, then installs z407-connect as a user systemd
# service that starts at login. Safe to re-run.
#
# Usage: ./install.sh [AA:BB:CC:DD:EE:FF]
# Without an address, the single paired device named "Z407" is used.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly REPO_DIR
readonly BIN_DIR=$HOME/.local/bin
readonly UNIT_DIR=$HOME/.config/systemd/user
readonly CONFIG_DIR=$HOME/.config/z407-connect
readonly REQUIRED_COMMANDS=(bluetoothctl pw-cli wpctl gdbus)

# shellcheck disable=SC2034  # read through a nameref in missing_packages
declare -A APT_PACKAGES=([bluetoothctl]=bluez [pw-cli]=pipewire-bin [wpctl]=wireplumber [gdbus]=libglib2.0-bin)
# shellcheck disable=SC2034
declare -A DNF_PACKAGES=([bluetoothctl]=bluez [pw-cli]=pipewire-utils [wpctl]=wireplumber [gdbus]=glib2)
# shellcheck disable=SC2034
declare -A PACMAN_PACKAGES=([bluetoothctl]=bluez-utils [pw-cli]=pipewire [wpctl]=wireplumber [gdbus]=glib2)

die() {
  echo "error: $*" >&2
  exit 1
}

# $1 is the name of the command->package map for the detected package manager.
missing_packages() {
  local -n packages=$1
  local cmd

  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    command -v "$cmd" >/dev/null || echo "${packages[$cmd]}"
  done
}

install_dependencies() {
  local -a packages=()

  if command -v apt-get >/dev/null; then
    mapfile -t packages < <(missing_packages APT_PACKAGES)

    # Provides the bluez_output.* PipeWire nodes the script waits for.
    dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1 || packages+=(libspa-0.2-bluetooth)

    ((${#packages[@]} == 0)) || sudo apt-get install -y "${packages[@]}"
  elif command -v dnf >/dev/null; then
    mapfile -t packages < <(missing_packages DNF_PACKAGES)
    ((${#packages[@]} == 0)) || sudo dnf install -y "${packages[@]}"
  elif command -v pacman >/dev/null; then
    mapfile -t packages < <(missing_packages PACMAN_PACKAGES)
    ((${#packages[@]} == 0)) || sudo pacman -S --needed --noconfirm "${packages[@]}"
  else
    local cmd

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
      command -v "$cmd" >/dev/null || die "missing '$cmd' and no supported package manager (apt, dnf, pacman) found"
    done
  fi
}

ensure_bluetooth_service() {
  if ! systemctl is-enabled --quiet bluetooth.service || ! systemctl is-active --quiet bluetooth.service; then
    sudo systemctl enable --now bluetooth.service
  fi
}

detect_mac() {
  local -a matches

  mapfile -t matches < <(bluetoothctl devices Paired | awk '/Z407/ { print $2 }')

  ((${#matches[@]} == 1)) || die "could not pick the speakers automatically; pair them first, then pass the address from 'bluetoothctl devices Paired'"

  echo "${matches[0]}"
}

main() {
  local mac=${1:-}

  install_dependencies
  ensure_bluetooth_service

  [[ -n $mac ]] || mac=$(detect_mac)

  [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die "'$mac' is not a Bluetooth address"

  bluetoothctl info "$mac" | grep -q 'Paired: yes' || die "$mac is not paired; put the speakers in pairing mode and pair them once with bluetoothctl"

  install -Dm755 "$REPO_DIR/z407-connect" "$BIN_DIR/z407-connect"
  install -Dm644 "$REPO_DIR/z407-connect.service" "$UNIT_DIR/z407-connect.service"

  mkdir -p "$CONFIG_DIR"
  echo "Z407_MAC=$mac" >"$CONFIG_DIR/env"

  systemctl --user daemon-reload
  systemctl --user enable z407-connect.service
  systemctl --user restart z407-connect.service

  echo "Installed. The speakers will connect at every login."
}

main "$@"
