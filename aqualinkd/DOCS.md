# AqualinkD — Home Assistant Add-on

A Home Assistant add-on that runs [sfeakes' AqualinkD](https://github.com/sfeakes/AqualinkD) in Docker, connecting to a Jandy AquaLink RS-485 pool controller via an EW-11 WiFi RS485 adapter.

All configuration is managed through the HA add-on UI — no manual file editing required.

---

## Requirements

- Home Assistant OS or Supervised
- [Hi-Flying EW-11](http://www.hi-flying.com/ew11) (or compatible) WiFi RS485 adapter, configured in TCP server mode. **Run EW-11 firmware v1.50.0 or newer for best results** — older firmware has WiFi latency/jitter that causes RS485 read errors (`bad Jandy checksum` / `BAD PACKET` in the log).
- MQTT broker (e.g., the Mosquitto add-on in HA)
- Jandy AquaLink RS-485 panel (RS-4, RS-6, RS-8, RS-16, etc.)

---

## Installation

### 1. Add this repository to Home Assistant

1. Go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮ menu** (top right) → **Repositories**
3. Paste the repository URL and click **Add**:
   ```
   https://github.com/jjarboe01/AqualinkD-Docker-HA
   ```
4. Close the dialog.

### 2. Install the add-on

1. Still in the **Add-on Store**, reload the page (or **⋮ → Check for updates**)
2. Find **AqualinkD** under the **AqualinkD Add-on Repository** section
3. Click it → **Install**

The add-on is built locally from the Dockerfile on first install, so the initial install takes a few minutes.

### 3. Configure the add-on

Go to the add-on's **Configuration** tab and fill in your values:

#### EW-11 Adapter
| Setting | Description |
|---|---|
| `ew11_host` | IP address of your EW-11 adapter |
| `ew11_port` | TCP port on the EW-11 (default: `8899`) |

#### MQTT
| Setting | Description |
|---|---|
| `mqtt_host` | IP/hostname of your MQTT broker |
| `mqtt_port` | MQTT port (default: `1883`) |
| `mqtt_user` | MQTT username |
| `mqtt_password` | MQTT password |
| `mqtt_topic` | Root MQTT topic (default: `aqualinkd`) |
| `mqtt_timed_update` | Re-publish all state every ~5 min even if unchanged |

#### Panel
| Setting | Description |
|---|---|
| `panel_type` | Your panel type string, e.g. `RS-4 Only`, `RS-8 Combo`, `RS-16 Combo` |
| `device_id` | AqualinkD RS device ID (default: `0x09`) |
| `rssa_device_id` | Serial Interface device ID (default: `0x48`) |
| `extended_device_id` | Extended/VSP device ID (default: `0x30`) |
| `extended_device_id_programming` | Use extended ID for faster programming |

#### RS485 Devices
Enable reading from these devices directly off the bus:

| Setting | Device |
|---|---|
| `read_rs485_swg` | Salt Water Generator |
| `read_rs485_epump` | Jandy ePump / ePump AC |
| `read_rs485_vsfpump` | Pentair VS/VF/VSF pump |
| `read_rs485_jxi` | Jandy JXi heater |
| `read_rs485_lx` | Jandy LX/LT heaters |
| `read_rs485_chem` | Jandy Chemical Feeder |

#### Buttons
Configure your panel buttons as an array. Each button maps to an aux circuit in order (Button 01, 02, etc.). Optional fields per button:

```yaml
buttons:
  - label: "Filter Pump"
    pump_id: "0x78"       # RS485 ID of variable speed pump (Jandy: 0x78-0x7B, Pentair: 0x60-0x6F)
    pump_index: 1         # Pump index set in Aqualink control panel (1-4)
  - label: "Pool Light"
    light_mode: 2         # 0=Aqualink, 1=Jandy, 2=Jandy LED, 3=SAm/SAL, 4=Color Logic, 5=Intellibrite, 6=Dimmer
  - label: "High Speed"
  - label: "NONE"         # Use NONE for unused circuits
```

### 4. Start the add-on

Click **Start**. Enable **Watchdog** so HA restarts the add-on automatically if it crashes.

The AqualinkD web UI is available at `http://<ha-ip>:7243` and will also appear as a sidebar panel in HA (pool icon).

---

## How it works

On each container start, `aqualinkd-ts.sh` runs, which:

1. Copies the pre-exec script from the image layer into `/aquadconf/` (so config changes always take effect on restart)
2. Reads `/data/options.json` (HA's add-on config store), validates it, and **regenerates** `aqualinkd.conf` from an immutable baked-in template. The new file is written to a temp file and moved into place atomically — if options are missing or invalid, the daemon aborts and the previous working config is left untouched.
3. Starts a `socat` reconnect loop bridging the EW-11 TCP connection to a virtual serial port (`/aquadconf/tty.Pool`)
4. Launches `aqualinkd-docker` with timestamps prepended to all log output

Because the config is rebuilt from the template on every start, runs are deterministic and never accumulate drift. **This means manual edits to `config/aqualinkd.conf` are overwritten on each start — all configuration must go through the HA add-on options UI.**

If the EW-11 connection drops, `socat` automatically retries every 5 seconds without requiring a container restart. A 60-second inactivity timeout (`socat -T 60`) also tears down and reconnects a *half-open* EW-11 session (one where the TCP socket stays up but no RS485 bytes flow), which is the common silent-failure mode for these WiFi serial bridges.

### Pinning the AqualinkD version

The image builds a specific AqualinkD release (default `v3.1.0`) for reproducible builds. To change it, build with `--build-arg AQUALINKD_VERSION=vX.Y.Z`, or set it to `latest` to track the newest upstream release.

### Health

The container ships a Docker `HEALTHCHECK` that verifies **both** the web UI responds and the serial bridge (`/aquadconf/tty.Pool`) exists — so "web up but RS485 dead" is reported as unhealthy, not just a dead web server. Note that Home Assistant's own add-on restart is driven by the `watchdog:` URL in `config.yaml`; the Docker healthcheck is visible via `docker ps` / `docker inspect` and in standalone `docker compose` use.

---

## Upgrading

When a new version is published (the `version` in `config.yaml` is bumped), Home Assistant picks it up automatically:

1. Go to **Settings → Add-ons → Add-on Store** and reload (or **⋮ → Check for updates**)
2. Open the **AqualinkD** add-on — if an update is available, an **Update** button appears
3. Click **Update** (the add-on is rebuilt from the new Dockerfile)

To force a rebuild from the current sources at any time, use the add-on's **⋮ → Rebuild** option, or from the HA CLI:

```bash
ha addons rebuild <slug>
```

> The add-on `<slug>` for a custom repository looks like `XXXXXXXX_aqualinkd` (a repository hash prefix). Find it under **Settings → Add-ons → AqualinkD** in the URL, or via `ha addons list`.

---

## Known Limitations

- The **Logs tab** in the AqualinkD web UI will show `Error: Failed to open journal` — this is expected. AqualinkD's web UI uses `libsystemd` journal which doesn't exist in Docker on HA OS. The daemon itself works fine; logs are written to `/var/log/aqualinkd.log` inside the container and are visible via **Settings → Add-ons → AqualinkD → Log**.
- HA sidebar panel requires a browser-accessible URL. The panel iframe points to `http://<ha-ip>:7243`.

---

## Credits

- [aqualinkd/AqualinkD](https://github.com/aqualinkd/AqualinkD) — the underlying daemon
- EW-11 RS485-over-WiFi adapter by Hi-Flying
