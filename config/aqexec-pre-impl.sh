#!/bin/bash
# Read HA add-on options and apply to aqualinkd config before daemon starts

OPTIONS=/data/options.json
CONF=/aquadconf/aqualinkd.conf

echo "Applying HA options from ${OPTIONS}..."

# Helper: convert JSON boolean to yes/no
yn() { [ "$(jq -r "$1" $OPTIONS)" = "true" ] && echo "yes" || echo "no"; }
# Helper: get string value
str() { jq -r "$1" $OPTIONS; }
# Helper: get int value
num() { jq -r "$1" $OPTIONS; }

EW11_IP=$(str ".ew11_host")
EW11_PORT=$(num ".ew11_port")
TTY_LINK=/aquadconf/tty.Pool

# --- MQTT ---
sed -i "s|^mqtt_address = .*|mqtt_address = $(str .mqtt_host):$(num .mqtt_port)|" $CONF
sed -i "s|^mqtt_user =.*|mqtt_user = $(str .mqtt_user)|" $CONF
sed -i "s|^mqtt_passwd =.*|mqtt_passwd = $(str .mqtt_password)|" $CONF
sed -i "s|^mqtt_aq_topic =.*|mqtt_aq_topic = $(str .mqtt_topic)|" $CONF
sed -i "s|^mqtt_timed_update =.*|mqtt_timed_update = $(yn .mqtt_timed_update)|" $CONF

# --- Panel ---
sed -i "s|^panel_type =.*|panel_type = $(str .panel_type)|" $CONF
sed -i "s|^device_id=.*|device_id=$(str .device_id)|" $CONF
sed -i "s|^rssa_device_id=.*|rssa_device_id=$(str .rssa_device_id)|" $CONF
sed -i "s|^extended_device_id=.*|extended_device_id=$(str .extended_device_id)|" $CONF
sed -i "s|^extended_device_id_programming =.*|extended_device_id_programming = $(yn .extended_device_id_programming)|" $CONF

# --- Logging ---
sed -i "s|^log_level=.*|log_level=$(str .log_level)|" $CONF
sed -i "s|^display_warnings_in_web=.*|display_warnings_in_web=$(yn .display_warnings_in_web)|" $CONF

# --- RS485 device reading (delete + append since these may be commented out) ---
for key in read_RS485_swg read_RS485_ePump read_RS485_vsfPump read_RS485_JXi read_RS485_LX read_RS485_Chem; do
  sed -i "/^#\?${key}/d" $CONF
done
echo "read_RS485_swg = $(yn .read_rs485_swg)"         >> $CONF
echo "read_RS485_ePump = $(yn .read_rs485_epump)"     >> $CONF
echo "read_RS485_vsfPump = $(yn .read_rs485_vsfpump)" >> $CONF
echo "read_RS485_JXi = $(yn .read_rs485_jxi)"         >> $CONF
echo "read_RS485_LX = $(yn .read_rs485_lx)"           >> $CONF
echo "read_RS485_Chem = $(yn .read_rs485_chem)"       >> $CONF

# --- Temperature / Time ---
sed -i "s|^convert_mqtt_temp_to_c =.*|convert_mqtt_temp_to_c = $(yn .convert_mqtt_temp_to_c)|" $CONF
sed -i "s|^keep_paneltime_synced =.*|keep_paneltime_synced = $(yn .keep_paneltime_synced)|" $CONF

# --- Pool/Spa reporting ---
sed -i "s|^report_zero_spa_temp =.*|report_zero_spa_temp = $(yn .report_zero_spa_temp)|" $CONF
sed -i "s|^report_zero_pool_temp =.*|report_zero_pool_temp = $(yn .report_zero_pool_temp)|" $CONF
sed -i "s|^override_freeze_protect =.*|override_freeze_protect = $(yn .override_freeze_protect)|" $CONF

# --- Force settings ---
sed -i "s|^force_SWG =.*|force_SWG = $(yn .force_swg)|" $CONF
sed -i "s|^force_PS_setpoints =.*|force_PS_setpoints = $(yn .force_ps_setpoints)|" $CONF
sed -i "s|^force_Frzprotect_setpoints =.*|force_Frzprotect_setpoints = $(yn .force_frzprotect_setpoints)|" $CONF
sed -i "s|^force_chem_feeder =.*|force_chem_feeder = $(yn .force_chem_feeder)|" $CONF

# --- SWG / Light / Misc ---
sed -i "s|^swg_zero_ignore_count =.*|swg_zero_ignore_count = $(num .swg_zero_ignore_count)|" $CONF
sed -i "s|^light_programming_mode=.*|light_programming_mode=$(num .light_programming_mode)|" $CONF
sed -i "s|^light_programming_initial_on=.*|light_programming_initial_on=$(num .light_programming_initial_on)|" $CONF
sed -i "s|^light_programming_initial_off=.*|light_programming_initial_off=$(num .light_programming_initial_off)|" $CONF
sed -i "s|^rs485_frame_delay =.*|rs485_frame_delay = $(num .rs485_frame_delay)|" $CONF
sed -i "s|^ftdi_low_latency =.*|ftdi_low_latency = $(yn .ftdi_low_latency)|" $CONF
sed -i "s|^enable_scheduler =.*|enable_scheduler = $(yn .enable_scheduler)|" $CONF

# --- Buttons (strip all existing, regenerate from options) ---
sed -i '/^#\?button_[0-9]/d' $CONF
echo "" >> $CONF
echo "# Button configuration (managed via HA add-on options)" >> $CONF
jq -r '
  .buttons | to_entries[] |
  (.key + 1) as $num |
  ($num | tostring | if length < 2 then "0" + . else . end) as $n |
  "button_\($n)_label=\(.value.label)",
  (if .value.pump_id != null then "button_\($n)_pumpID=\(.value.pump_id)" else empty end),
  (if .value.pump_index != null then "button_\($n)_pumpIndex=\(.value.pump_index)" else empty end),
  (if .value.light_mode != null then "button_\($n)_lightMode=\(.value.light_mode)" else empty end),
  ""
' $OPTIONS >> $CONF

echo "Config applied: EW11=${EW11_IP}:${EW11_PORT} panel=$(str .panel_type) log=$(str .log_level)"

# --- Reconnect loop for EW-11 TCP ---
echo "Starting SOCAT reconnect loop ${EW11_IP}:${EW11_PORT} -> ${TTY_LINK}"
(
  while true; do
    socat pty,link=${TTY_LINK},raw,ignoreeof TCP:${EW11_IP}:${EW11_PORT},ignoreeof,connect-timeout=10
    echo "SOCAT: lost connection, retrying in 5s..."
    rm -f ${TTY_LINK}
    sleep 5
  done
) &

echo "Sleeping for SOCAT start..."
sleep 3
