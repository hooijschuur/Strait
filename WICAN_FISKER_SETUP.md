# Fisker Ocean WiCAN Pro Setup Guide (wambs fork)

This guide explains how to set up your WiCAN Pro device with the **wambs fork** firmware to monitor your Fisker Ocean and send data to Home Assistant via MQTT.

## Prerequisites

1. **WiCAN Pro device** with wambs fork firmware installed
2. **Fisker Ocean** (tested with Ocean OS 2.2.3)
3. **MQTT broker** (Mosquitto, Home Assistant MQTT add-on, or cloud service)
4. **Home Assistant** installation (optional, for data visualization)
5. **OBD-II adapter connection** to your Fisker Ocean

## Step 1: Install wambs Fork Firmware

1. Download the latest **wambs fork** firmware from: https://github.com/wambs/wican-fw/releases
2. Look for files named like: `wican-fw_obd_pro_v4.47p_beta-09.bin` or newer
3. Update your WiCAN Pro via the web interface:
   - Connect to your WiCAN Pro's WiFi (or local network if in station mode)
   - Open the web interface (typically http://192.168.0.10 or your device's IP)
   - Go to **System > Firmware Update**
   - Upload the wambs fork firmware .bin file
   - Wait for the update to complete and the device to reboot

## Step 2: Configure WiCAN Pro for Fisker Ocean

### Basic Setup

1. **Connect to WiCAN Pro**:
   - Connect your computer/phone to the WiCAN Pro's WiFi network
   - Open the web interface in your browser

2. **Configure WiFi/Network** (if using Station Mode):
   - Go to **System > Network**
   - Set your WiFi SSID and password
   - Save and reboot if needed

3. **Configure MQTT Settings**:
   - Go to **System > MQTT**
   - Enable MQTT
   - Set your MQTT broker IP/hostname
   - Set MQTT port (default: 1883)
   - Set MQTT username and password (if required)
   - Set Client ID (e.g., `wican-fisker-ocean`)
   - Set Base Topic (e.g., `wican/fisker/ocean`)
   - Save settings

### Vehicle Profile Setup

1. **Go to Automate > Vehicle Groups**
2. **Create a new Vehicle Group** for Fisker Ocean:
   - Click "Add New Group"
   - Name: `Fisker Ocean`
   - Enable the group

3. **Import the Fisker Ocean Profile**:
   - You have two options:

   **Option A: Manual Entry (Recommended)**
   
   Create individual PIDs based on the provided profile:
   
   | Parameter | PID | Module | Expression | Unit | Poll Interval |
   |-----------|-----|--------|------------|------|---------------|
   | SOC | `222050` | BMS (7E1) | `[B3:B4]*0.1` | % | 1s |
   | HV Voltage | `222107` | BMS (7E1) | `[B3:B4]*0.1` | V | 1s |
   | HV Current | `222004` | BMS (7E1) | `([B3:B4]*0.1)-2000` | A | 1s |
   | Battery Temp | `222089` | BMS (7E1) | `[B3:B4]*0.01` | °C | 30s |
   | Speed | `22EFF7` | VCU (7C2) | `[B3:B4]*0.1` | km/h | 1s |
   | Odometer | `223409` | BCM (7C1) | `[B3:B6]*0.01` | km | 60s |
   | 12V Voltage | `22EFF9` | VCU (7C2) | `[B3:B4]*0.001` | V | 30s |
   | Cell Voltage Min | `222136` | BMS (7E1) | `[B3:B4]*0.001` | V | 10s |
   | Cell Voltage Max | `222137` | BMS (7E1) | `[B3:B4]*0.001` | V | 10s |
   | Cell Voltage Avg | `222138` | BMS (7E1) | `[B3:B4]*0.001` | V | 10s |
   | Tire Pressures | `223427` | BCM (7C1) | `B3*1.379`, `B4*1.379`, etc. | kPa | 60s |

   For each PID:
   - Click "Add New PID"
   - Enter the PID code (e.g., `222050`)
   - Set the **PID Init** commands for the module:
     - BMS (7E1): `ATSH7E1;ATFCSH7E1;ATCRA7E9;`
     - VCU (7C2): `ATSH7C2;ATFCSH7C2;ATCRA7CA;`
     - BCM (7C1): `ATSH7C1;ATFCSH7C1;ATCRA7C9;`
   - Add parameters with the expressions above
   - Set MQTT Topic to: `wican/fisker/ocean/[parameter_name]`
   - Set poll interval
   - Save

   **Option B: Import JSON Profile**
   
   If the wambs fork supports profile import:
   1. Download the `fisker-ocean-wican-profile.json` file
   2. Go to **Automate > Vehicle Profiles**
   3. Upload the JSON file
   4. Select the profile and apply it to your vehicle group

4. **Set Global ELM327 Initialization**:
   - Go to **System > ELM327 Settings**
   - Set initialization string: `ATSP6;ATST96;ATFCSD300000;ATFCSM1;`
   - Save

5. **Configure Module Addressing**:
   - The profile uses these module addresses:
     - **BMS**: Request 7E1, Response 7E9
     - **VCU**: Request 7C2, Response 7CA
     - **BCM**: Request 7C1, Response 7C9

## Step 3: Configure MQTT Topics

Ensure your MQTT topics match the Home Assistant configuration:

### Recommended Topic Structure:
```
wican/fisker/ocean/soc              - State of Charge (%)
wican/fisker/ocean/hv_v             - HV Pack Voltage (V)
wican/fisker/ocean/hv_a             - HV Pack Current (A)
wican/fisker/ocean/batt_temp        - Battery Temperature (°C)
wican/fisker/ocean/speed            - Vehicle Speed (km/h)
wican/fisker/ocean/odometer         - Odometer (km)
wican/fisker/ocean/aux_voltage      - 12V Auxiliary Voltage (V)
wican/fisker/ocean/cell_v_min       - Minimum Cell Voltage (V)
wican/fisker/ocean/cell_v_max       - Maximum Cell Voltage (V)
wican/fisker/ocean/cell_v_avg       - Average Cell Voltage (V)
wican/fisker/ocean/soc_min          - Minimum Cell SOC (%)
wican/fisker/ocean/soc_max          - Maximum Cell SOC (%)
wican/fisker/ocean/soc_avg          - Average Cell SOC (%)
wican/fisker/ocean/tyre_p_fl        - Front Left Tire Pressure (kPa)
wican/fisker/ocean/tyre_p_fr        - Front Right Tire Pressure (kPa)
wican/fisker/ocean/tyre_p_rl        - Rear Left Tire Pressure (kPa)
wican/fisker/ocean/tyre_p_rr        - Rear Right Tire Pressure (kPa)
wican/fisker/ocean/drive_current    - Drive Current without auxiliaries (A)
wican/fisker/ocean/hv_v_smooth      - Smooth HV Voltage (V)
wican/fisker/ocean/bms_state        - BMS State
wican/fisker/ocean/availability     - Device availability (online/offline)
```

## Step 4: Home Assistant Configuration

1. **Copy the MQTT configuration** from `fisker-ocean-homeassistant-mqtt.yaml`
2. **Add it to your Home Assistant**:
   - Option A: Add directly to your `configuration.yaml`
   - Option B: Create a new file `fisker_ocean.yaml` in your config directory and include it:
     ```yaml
     # In configuration.yaml
     homeassistant:
       packages: !include_dir_named packages
     ```
     Then save the MQTT config in `packages/fisker_ocean.yaml`

3. **Restart Home Assistant**

4. **Verify sensors appear** in Developer Tools > States

## Step 5: Dashboard Setup (Optional)

Create a dashboard with these suggested cards:

### Battery Overview Card
```yaml
type: vertical-stack
cards:
  - type: gauge
    entity: sensor.fisker_ocean_soc
    name: Battery SOC
    min: 0
    max: 100
    severity:
      green: 50
      yellow: 30
      red: 15

  - type: entities
    entities:
      - entity: sensor.fisker_ocean_hv_voltage
        name: Pack Voltage
      - entity: sensor.fisker_ocean_hv_current
        name: Pack Current
      - entity: sensor.fisker_ocean_hv_power
        name: Pack Power
      - entity: sensor.fisker_ocean_battery_temperature
        name: Battery Temp

  - type: entities
    entities:
      - entity: sensor.fisker_ocean_energy_remaining
        name: Energy Remaining
      - entity: sensor.fisker_ocean_estimated_range
        name: Estimated Range
```

### Tire Pressure Card
```yaml
type: vertical-stack
cards:
  - type: picture-glance
    image: /local/images/tire-icon.png
    entities:
      - entity: sensor.fisker_ocean_tire_pressure_fl
        name: Front Left
      - entity: sensor.fisker_ocean_tire_pressure_fr
        name: Front Right
      - entity: sensor.fisker_ocean_tire_pressure_rl
        name: Rear Left
      - entity: sensor.fisker_ocean_tire_pressure_rr
        name: Rear Right
```

### Charging Status Card
```yaml
type: conditional
conditions:
  - entity: binary_sensor.fisker_ocean_is_charging
    state: "on"
card:
  type: vertical-stack
  cards:
    - type: markdown
      content: "**Charging in Progress**"
    - type: entities
      entities:
        - entity: sensor.fisker_ocean_soc
        - entity: sensor.fisker_ocean_hv_current
        - entity: sensor.fisker_ocean_hv_power
        - entity: binary_sensor.fisker_ocean_is_dc_fast_charging
```

## Troubleshooting

### WiCAN Pro Not Connecting to MQTT
1. Verify MQTT broker is running
2. Check credentials in WiCAN Pro MQTT settings
3. Test MQTT connection with a client like MQTT Explorer
4. Check WiCAN Pro logs via web interface

### No Data from Fisker Ocean
1. Verify WiCAN Pro is properly connected to OBD-II port
2. Check that the car is in "Ready" mode (not off)
3. Verify the ELM327 initialization commands are correct
4. Test with a single PID first (e.g., SOC on BMS)
5. Check the CAN bus speed (should be 500 kbps for Fisker Ocean)

### Incorrect Values
1. Verify the PID expressions match the actual data format
2. Check byte order (big-endian vs little-endian)
3. Verify scaling factors
4. Compare with known values from the car's dashboard

### Common Issues
- **TPMS not waking up**: Tire pressure sensors may take 20+ minutes of driving to wake up
- **BMS not responding**: Try different initialization sequences
- **Connection drops**: Ensure stable power to WiCAN Pro (use a quality OBD-II power adapter)

## Data Verification

Compare WiCAN Pro readings with your Fisker Ocean dashboard:

| Parameter | WiCAN Sensor | Dashboard Value | Expected Match |
|-----------|--------------|-----------------|----------------|
| SOC | `sensor.fisker_ocean_soc` | Dashboard SOC | ±1-2% |
| Speed | `sensor.fisker_ocean_speed` | Speedometer | ±3% (known offset) |
| Odometer | `sensor.fisker_ocean_odometer` | Odometer | ±3% (known offset) |
| HV Voltage | `sensor.fisker_ocean_hv_voltage` | N/A | 390-415V |
| HV Current | `sensor.fisker_ocean_hv_current` | N/A | Varies with load |

## Advanced Configuration

### Custom Polling Rates
Adjust polling rates based on your needs:
- **Driving**: 1 second for SOC, voltage, current, speed
- **Parked**: 30-60 seconds for most parameters
- **Sleep**: Reduce to minimum to preserve battery

### Multiple Module Polling
For better performance, consider grouping PIDs by module:
- **Group 1 (BMS)**: SOC, voltage, current, temperature
- **Group 2 (VCU)**: Speed, 12V voltage
- **Group 3 (BCM)**: Odometer, tire pressures

### Power Saving
Configure WiCAN Pro to sleep when the car is off:
1. Go to **System > Power Saving**
2. Enable "Sleep When Car Off"
3. Set voltage threshold: 13.0V
4. Set wake interval: 300 seconds (5 minutes)

## References

- **Strait Project**: https://github.com/hooijschuur/Strait - The original Fisker Ocean OBD-II research
- **wambs wican-fw**: https://github.com/wambs/wican-fw - The forked firmware with group-based PIDs
- **WiCAN Pro Documentation**: https://wambs.github.io/wican-fw/
- **Fisker Ocean DID Catalog**: See `docs/fisker-ocean/did-catalog.md` in the Strait repository

## Contributing

If you find additional PIDs or improve the profile:
1. Test thoroughly
2. Document your findings
3. Submit a pull request to update this profile
4. Include evidence (screenshots, logs, comparisons with dashboard)

## License

This configuration is provided as-is for personal use. Use at your own risk.

## Changelog

- **v1.0**: Initial profile based on Strait project research (Ocean OS 2.2.3)
- Added support for main battery parameters (SOC, voltage, current)
- Added support for vehicle speed and odometer
- Added support for tire pressures (when TPMS is active)
- Added Home Assistant MQTT configuration
- Added calculated sensors (power, energy remaining, range)
