# AqualinkD Add-on Repository

A [Home Assistant](https://www.home-assistant.io/) add-on repository that packages
[sfeakes' AqualinkD](https://github.com/sfeakes/AqualinkD) — a daemon for Jandy AquaLink
RS-485 pool/spa controllers — connected over an EW-11 WiFi RS485 adapter.

## Add this repository

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮ menu** (top right) → **Repositories**.
3. Add this URL:
   ```
   https://github.com/jjarboe01/AqualinkD-Docker-HA
   ```
4. Reload the store — the add-on below will appear under **AqualinkD Add-on Repository**.

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fjjarboe01%2FAqualinkD-Docker-HA)

## Add-ons in this repository

| Add-on | Description |
|---|---|
| **[AqualinkD](aqualinkd/)** | Runs AqualinkD in Docker, bridging a Jandy AquaLink RS-485 panel to MQTT / a web UI via an EW-11 adapter. All configuration is managed through the add-on options UI. |

See the add-on's [documentation](aqualinkd/DOCS.md) for requirements, configuration, and how it works.

## Requirements

- Home Assistant OS or Supervised (the Supervisor builds the add-on locally from its Dockerfile)
- A [Hi-Flying EW-11](http://www.hi-flying.com/ew11) (or compatible) WiFi RS485 adapter in TCP server mode — **run EW-11 firmware v1.50.0 or newer for best results**; older firmware exhibits WiFi latency/jitter that causes RS485 read errors (bad checksums / dropped packets)
- An MQTT broker (e.g. the Mosquitto add-on)
- A Jandy AquaLink RS-485 panel

## Credits

- [aqualinkd/AqualinkD](https://github.com/aqualinkd/AqualinkD) — the underlying daemon
- EW-11 RS485-over-WiFi adapter by Hi-Flying
