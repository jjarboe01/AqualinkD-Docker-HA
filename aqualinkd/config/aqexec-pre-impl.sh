#!/bin/bash
# Read HA add-on options and regenerate the aqualinkd config before the daemon starts.
#
# The config is rebuilt from an immutable template on every boot and written
# atomically, so runs are deterministic and never accumulate drift from
# repeated in-place edits.
set -euo pipefail

OPTIONS=/data/options.json
CONF=/aquadconf/aqualinkd.conf
TEMPLATE=/etc/aqualinkd.conf.template
TTY_LINK=/aquadconf/tty.Pool

# --- Validate inputs (fail fast; never boot on a broken/partial config) ---
if [ ! -f "$OPTIONS" ]; then
  echo "ERROR: HA options file $OPTIONS not found; aborting." >&2
  exit 1
fi
if ! jq -e . "$OPTIONS" >/dev/null 2>&1; then
  echo "ERROR: $OPTIONS is not valid JSON; aborting." >&2
  exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: config template $TEMPLATE not found; aborting." >&2
  exit 1
fi

# All scalar options must be present (config.yaml ships defaults for every one,
# so a null here means the options store is broken — refuse rather than write
# the literal string "null" into the config).
REQUIRED_KEYS="
  .ew11_host .ew11_port
  .mqtt_host .mqtt_port .mqtt_user .mqtt_password .mqtt_topic .mqtt_timed_update
  .panel_type .device_id .rssa_device_id .extended_device_id .extended_device_id_programming
  .log_level .display_warnings_in_web
  .read_rs485_swg .read_rs485_epump .read_rs485_vsfpump .read_rs485_jxi .read_rs485_lx .read_rs485_chem
  .convert_mqtt_temp_to_c .keep_paneltime_synced
  .report_zero_spa_temp .report_zero_pool_temp .override_freeze_protect
  .force_swg .force_ps_setpoints .force_frzprotect_setpoints .force_chem_feeder
  .swg_zero_ignore_count .light_programming_mode .light_programming_initial_on .light_programming_initial_off
  .rs485_frame_delay .ftdi_low_latency .enable_scheduler
"
missing=0
for k in $REQUIRED_KEYS; do
  if [ "$(jq -r "$k" "$OPTIONS")" = "null" ]; then
    echo "ERROR: required option '$k' is missing in $OPTIONS" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || { echo "ERROR: aborting due to missing options." >&2; exit 1; }

echo "Applying HA options from ${OPTIONS}..."

# Helpers (validation above guarantees non-null values)
yn()  { [ "$(jq -r "$1" "$OPTIONS")" = "true" ] && echo "yes" || echo "no"; }
str() { jq -r "$1" "$OPTIONS"; }
num() { jq -r "$1" "$OPTIONS"; }

EW11_IP=$(str .ew11_host)
EW11_PORT=$(num .ew11_port)

# --- Build the new config in a temp file, then move it into place atomically ---
TMPCONF="$(mktemp "${CONF}.XXXXXX")"
cleanup() { rm -f "$TMPCONF"; }
trap cleanup EXIT

cp "$TEMPLATE" "$TMPCONF"

# --- MQTT ---
sed -i "s|^mqtt_address = .*|mqtt_address = $(str .mqtt_host):$(num .mqtt_port)|" "$TMPCONF"
sed -i "s|^mqtt_user =.*|mqtt_user = $(str .mqtt_user)|" "$TMPCONF"
sed -i "s|^mqtt_passwd =.*|mqtt_passwd = $(str .mqtt_password)|" "$TMPCONF"
sed -i "s|^mqtt_aq_topic =.*|mqtt_aq_topic = $(str .mqtt_topic)|" "$TMPCONF"
sed -i "s|^mqtt_timed_update =.*|mqtt_timed_update = $(yn .mqtt_timed_update)|" "$TMPCONF"

# --- Panel ---
sed -i "s|^panel_type =.*|panel_type = $(str .panel_type)|" "$TMPCONF"
sed -i "s|^device_id=.*|device_id=$(str .device_id)|" "$TMPCONF"
sed -i "s|^rssa_device_id=.*|rssa_device_id=$(str .rssa_device_id)|" "$TMPCONF"
sed -i "s|^extended_device_id=.*|extended_device_id=$(str .extended_device_id)|" "$TMPCONF"
sed -i "s|^extended_device_id_programming =.*|extended_device_id_programming = $(yn .extended_device_id_programming)|" "$TMPCONF"

# --- Logging ---
sed -i "s|^log_level=.*|log_level=$(str .log_level)|" "$TMPCONF"
sed -i "s|^display_warnings_in_web=.*|display_warnings_in_web=$(yn .display_warnings_in_web)|" "$TMPCONF"

# --- RS485 device reading (delete + append since these may be commented out) ---
for key in read_RS485_swg read_RS485_ePump read_RS485_vsfPump read_RS485_JXi read_RS485_LX read_RS485_Chem; do
  sed -i "/^#\?${key}/d" "$TMPCONF"
done
{
  echo "read_RS485_swg = $(yn .read_rs485_swg)"
  echo "read_RS485_ePump = $(yn .read_rs485_epump)"
  echo "read_RS485_vsfPump = $(yn .read_rs485_vsfpump)"
  echo "read_RS485_JXi = $(yn .read_rs485_jxi)"
  echo "read_RS485_LX = $(yn .read_rs485_lx)"
  echo "read_RS485_Chem = $(yn .read_rs485_chem)"
} >> "$TMPCONF"

# --- Temperature / Time ---
sed -i "s|^convert_mqtt_temp_to_c =.*|convert_mqtt_temp_to_c = $(yn .convert_mqtt_temp_to_c)|" "$TMPCONF"
sed -i "s|^keep_paneltime_synced =.*|keep_paneltime_synced = $(yn .keep_paneltime_synced)|" "$TMPCONF"

# --- Pool/Spa reporting ---
sed -i "s|^report_zero_spa_temp =.*|report_zero_spa_temp = $(yn .report_zero_spa_temp)|" "$TMPCONF"
sed -i "s|^report_zero_pool_temp =.*|report_zero_pool_temp = $(yn .report_zero_pool_temp)|" "$TMPCONF"
sed -i "s|^override_freeze_protect =.*|override_freeze_protect = $(yn .override_freeze_protect)|" "$TMPCONF"

# --- Force settings ---
sed -i "s|^force_SWG =.*|force_SWG = $(yn .force_swg)|" "$TMPCONF"
sed -i "s|^force_PS_setpoints =.*|force_PS_setpoints = $(yn .force_ps_setpoints)|" "$TMPCONF"
sed -i "s|^force_Frzprotect_setpoints =.*|force_Frzprotect_setpoints = $(yn .force_frzprotect_setpoints)|" "$TMPCONF"
sed -i "s|^force_chem_feeder =.*|force_chem_feeder = $(yn .force_chem_feeder)|" "$TMPCONF"

# --- SWG / Light / Misc ---
sed -i "s|^swg_zero_ignore_count =.*|swg_zero_ignore_count = $(num .swg_zero_ignore_count)|" "$TMPCONF"
sed -i "s|^light_programming_mode=.*|light_programming_mode=$(num .light_programming_mode)|" "$TMPCONF"
sed -i "s|^light_programming_initial_on=.*|light_programming_initial_on=$(num .light_programming_initial_on)|" "$TMPCONF"
sed -i "s|^light_programming_initial_off=.*|light_programming_initial_off=$(num .light_programming_initial_off)|" "$TMPCONF"
sed -i "s|^rs485_frame_delay =.*|rs485_frame_delay = $(num .rs485_frame_delay)|" "$TMPCONF"
sed -i "s|^ftdi_low_latency =.*|ftdi_low_latency = $(yn .ftdi_low_latency)|" "$TMPCONF"
sed -i "s|^enable_scheduler =.*|enable_scheduler = $(yn .enable_scheduler)|" "$TMPCONF"

# --- Buttons (strip all existing, regenerate from options) ---
sed -i '/^#\?button_[0-9]/d' "$TMPCONF"
{
  echo ""
  echo "# Button configuration (managed via HA add-on options)"
  jq -r '
    (.buttons // []) | to_entries[] |
    (.key + 1) as $num |
    ($num | tostring | if length < 2 then "0" + . else . end) as $n |
    "button_\($n)_label=\(.value.label)",
    (if .value.pump_id != null then "button_\($n)_pumpID=\(.value.pump_id)" else empty end),
    (if .value.pump_index != null then "button_\($n)_pumpIndex=\(.value.pump_index)" else empty end),
    (if .value.light_mode != null then "button_\($n)_lightMode=\(.value.light_mode)" else empty end),
    ""
  ' "$OPTIONS"
} >> "$TMPCONF"

# --- Sanity-check the generated config before swapping it in ---
if [ ! -s "$TMPCONF" ] \
   || ! grep -q '^mqtt_address = ' "$TMPCONF" \
   || ! grep -q '^serial_port=' "$TMPCONF" \
   || grep -q '= null$' "$TMPCONF"; then
  echo "ERROR: generated config failed validation; keeping previous config." >&2
  exit 1
fi

# Atomic replace (temp file is on the same filesystem as the target).
mv -f "$TMPCONF" "$CONF"
chmod 644 "$CONF"
trap - EXIT

echo "Config applied: EW11=${EW11_IP}:${EW11_PORT} panel=$(str .panel_type) log=$(str .log_level)"

# --- Reconnect loop for EW-11 TCP ---
# -T 60: if no bytes flow for 60s (half-open EW-11 session), socat exits and we
#        reconnect, instead of AqualinkD reading silence forever.
# Stale PTY symlink is cleared at the top of every iteration so a crashed socat
# never leaves a dead /aquadconf/tty.Pool behind.
echo "Starting SOCAT reconnect loop ${EW11_IP}:${EW11_PORT} -> ${TTY_LINK}"
(
  while true; do
    rm -f "${TTY_LINK}"
    socat -T 60 pty,link=${TTY_LINK},raw,ignoreeof TCP:${EW11_IP}:${EW11_PORT},ignoreeof,connect-timeout=10 \
      || echo "SOCAT: connection ended (rc=$?)"
    echo "SOCAT: lost connection to ${EW11_IP}:${EW11_PORT}, retrying in 5s..."
    sleep 5
  done
) &

# Wait (briefly) for the serial link to appear so aqualinkd doesn't open a
# missing device on first start.
echo "Waiting for serial link ${TTY_LINK}..."
for _ in $(seq 1 10); do
  [ -e "${TTY_LINK}" ] && break
  sleep 1
done
