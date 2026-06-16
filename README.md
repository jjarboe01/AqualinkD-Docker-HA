# AqualinkD — Home Assistant Add-on

A Home Assistant local add-on that runs [sfeakes' AqualinkD](https://github.com/sfeakes/AqualinkD) in Docker, connecting to a Jandy AquaLink RS-485 pool controller via an EW-11 WiFi RS485 adapter.

All configuration is managed through the HA add-on UI — no manual file editing required.

---

## Requirements

- Home Assistant OS or Supervised
- [Hi-Flying EW-11](http://www.hi-flying.com/ew11) (or compatible) WiFi RS485 adapter, configured in TCP server mode
- MQTT broker (e.g., the Mosquitto add-on in HA)
- Jandy AquaLink RS-485 panel (RS-4, RS-6, RS-8, RS-16, etc.)

---

## Installation

### 1. Copy the add-on files to Home Assistant

Copy the entire `aqualinkd/` folder into the `/addons/` directory on your Home Assistant host. The path should be:

```
/addons/aqualinkd/
├── Dockerfile
├── config.yaml
├── docker-compose.yml
└── config/
    ├── aqualinkd.conf
    ├── aqualinkd-ts.sh
    ├── aqexec-pre-impl.sh
    └── aqualinkd-docker.cmd
```

The easiest way to get files onto HA is via the **SSH & Web Terminal** add-on or **Samba** share (`\\<ha-ip>\addons`).

### 2. Install the add-on

In Home Assistant:

1. Go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮ menu** (top right) → **Check for updates** (or reload the page)
3. Scroll to the bottom — you should see **AqualinkD** under "Local add-ons"
4. Click it → **Install**

> **Note:** If the add-on doesn't appear, SSH into HA and run:
> ```bash
> curl -X POST http://supervisor/store/reload -H "Authorization: Bearer $SUPERVISOR_TOKEN"
> ha supervisor reload
> ```

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
2. Reads `/data/options.json` (HA's add-on config store) and applies all settings to `aqualinkd.conf` via `sed`
3. Starts a `socat` reconnect loop bridging the EW-11 TCP connection to a virtual serial port (`/aquadconf/tty.Pool`)
4. Launches `aqualinkd-docker` with timestamps prepended to all log output

If the EW-11 connection drops, `socat` automatically retries every 5 seconds without requiring a container restart.

---

## Upgrading

After pulling new files:

```bash
# SSH into HA, then:
ha addons rebuild local_aqualinkd

# If ports aren't binding (first time or after port changes):
ha addons uninstall local_aqualinkd
curl -X POST http://supervisor/store/reload -H "Authorization: Bearer $SUPERVISOR_TOKEN"
ha addons install local_aqualinkd
ha addons start local_aqualinkd
```

---

## Known Limitations

- The **Logs tab** in the AqualinkD web UI will show `Error: Failed to open journal` — this is expected. AqualinkD's web UI uses `libsystemd` journal which doesn't exist in Docker on HA OS. The daemon itself works fine; logs are written to `/var/log/aqualinkd.log` inside the container and are visible via **Settings → Add-ons → AqualinkD → Log**.
- HA sidebar panel requires a browser-accessible URL. The panel iframe points to `http://<ha-ip>:7243`.

---

## Credits

- [sfeakes/AqualinkD](https://github.com/sfeakes/AqualinkD) — the underlying daemon
- EW-11 RS485-over-WiFi adapter by Hi-Flying
