# Logitech-Z407-Linux-Connection

Keeps Logi Z407 Bluetooth speakers connected on Linux and set as the default audio output.

## Problem

On Linux the Z407 speakers do not reliably reconnect on its own. After boot, a speaker power-cycle, or a `bluetoothd` restart (e.g. a bluez package upgrade drops every connection and does not restore them), the speakers stay disconnected, or connect without becoming the default sink.

## What this does

`z407-connect`:

1. Connects to the speakers with `bluetoothctl`.
2. Waits for WirePlumber to expose the `bluez_output.<MAC>` PipeWire node, retrying up to 12 times, 5s apart.
3. Sets that node as the default output with `wpctl set-default`.
4. Watches D-Bus (`gdbus monitor`) and repeats steps 1-3 whenever `org.bluez` reappears.

## Run

Requires `bluez` (`bluetoothctl`), PipeWire with WirePlumber (`pw-cli`, `wpctl`), and `gdbus` (GLib).

The speakers must already be paired. Find their address with `bluetoothctl devices`.

Manually:

```sh
Z407_MAC=AA:BB:CC:DD:EE:FF ./z407-connect
```

As a user systemd service:

```sh
install -Dm755 z407-connect ~/.local/bin/z407-connect
install -Dm644 z407-connect.service ~/.config/systemd/user/z407-connect.service

# set Z407_MAC in the unit to your speakers' address
systemctl --user daemon-reload
systemctl --user enable --now z407-connect.service
```

The unit starts after WirePlumber and restarts the script 10 s after it exits.
