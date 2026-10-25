# Logitech-Z407-Linux-Connection

Keeps Logi Z407 Bluetooth speakers connected on Linux and set as the default audio output.

## Problem

On Linux the Z407 speakers do not reliably reconnect on their own. After boot, a speaker power cycle, or a `bluetoothd` restart (e.g., a bluez package upgrade drops every connection and does not restore them), the speakers stay disconnected or connect without becoming the default sink.

## What this does

`z407-connect`:

1. Connects to the speakers with `bluetoothctl`.
2. Waits for WirePlumber to expose the `bluez_output.<MAC>` PipeWire node, retrying up to 12 times, 5s apart.
3. Sets that node as the default output with `wpctl set-default`.
4. Watches D-Bus (`gdbus monitor`) and repeats steps 1-3 whenever `org.bluez` reappears.

## Run

Pair the speakers once (`bluetoothctl`: `scan on`, `pair`, `trust`), then:

```sh
./install.sh [AA:BB:CC:DD:EE:FF]
```

This installs missing dependencies (`apt`, `dnf`, or `pacman`; needs `sudo`), enables `bluetooth.service`, installs the script and a user systemd unit, and starts it. The address defaults to the one paired device named "Z407". It is stored in `~/.config/z407-connect/env`. Re-running is safe.

From then on the unit starts at every login, after WirePlumber, and restarts the script 10s after it exits.

Dependencies: [BlueZ](https://github.com/bluez/bluez) (`bluetoothctl`), [PipeWire](https://pipewire.org/) (`pw-cli`) with [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/) (`wpctl`), and [GLib](https://docs.gtk.org/gio/) (`gdbus`).

To run without the service: `Z407_MAC=AA:BB:CC:DD:EE:FF ./z407-connect`.
