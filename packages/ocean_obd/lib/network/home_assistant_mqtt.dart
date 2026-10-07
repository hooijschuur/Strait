import 'dart:convert';

import 'package:ocean_obd/platform/gps_fix.dart';

import 'mqtt_client.dart';

/// Home Assistant MQTT discovery configuration
class HomeAssistantMqttConfig {
  const HomeAssistantMqttConfig({
    required this.deviceId,
    required this.deviceName,
    this.manufacturer = 'Strait',
    this.model = 'Fisker Ocean',
    this.softwareVersion = '1.0.0',
    this.mqttPrefix = 'homeassistant',
    this.stateTopicPrefix = 'strait',
    this.discoveryPrefix = 'homeassistant',
  });

  final String deviceId;
  final String deviceName;
  final String manufacturer;
  final String model;
  final String softwareVersion;
  final String mqttPrefix;
  final String stateTopicPrefix;
  final String discoveryPrefix;

  /// Unique device identifier for Home Assistant
  String get uniqueId => deviceId;

  /// Base topic for state updates
  String get stateBaseTopic => '$mqttPrefix/$stateTopicPrefix';

  /// Base topic for discovery messages
  String get discoveryBaseTopic => discoveryPrefix;
}

/// Home Assistant entity types
class HaEntityConfig {
  final String platform;
  final String entityId;
  final String name;
  final String? unitOfMeasurement;
  final String? deviceClass;
  final String? stateClass;
  final String? valueTemplate;
  final Map<String, dynamic>? additionalConfig;

  HaEntityConfig({
    required this.platform,
    required this.entityId,
    required this.name,
    this.unitOfMeasurement,
    this.deviceClass,
    this.stateClass,
    this.valueTemplate,
    this.additionalConfig,
  });

  Map<String, dynamic> toJson() {
    final config = <String, dynamic>{
      'platform': platform,
      'name': name,
      'unique_id': entityId,
    };

    if (unitOfMeasurement != null) {
      config['unit_of_measurement'] = unitOfMeasurement;
    }
    if (deviceClass != null) {
      config['device_class'] = deviceClass;
    }
    if (stateClass != null) {
      config['state_class'] = stateClass;
    }
    if (valueTemplate != null) {
      config['value_template'] = valueTemplate;
    }
    if (additionalConfig != null) {
      config.addAll(additionalConfig!);
    }

    return config;
  }
}

/// Manages Home Assistant MQTT discovery and state publishing
class HomeAssistantMqttManager {
  HomeAssistantMqttManager({
    required this.mqttClient,
    required this.haConfig,
    this.onDiscoverySent,
    this.onStatePublished,
    this.onError,
  });

  final OceanMqttClient mqttClient;
  final HomeAssistantMqttConfig haConfig;
  final void Function(String entityId)? onDiscoverySent;
  final void Function(String entityId, String state)? onStatePublished;
  final void Function(dynamic error)? onError;

  final _discoveredEntities = <String, bool>{};

  /// Publish discovery message for a sensor
  Future<void> publishSensorDiscovery({
    required String entityId,
    required String name,
    required String stateTopic,
    String? unitOfMeasurement,
    String? deviceClass,
    String? stateClass,
    String? valueTemplate,
    Map<String, dynamic>? additionalConfig,
  }) async {
    final config = HaEntityConfig(
      platform: 'mqtt',
      entityId: entityId,
      name: name,
      unitOfMeasurement: unitOfMeasurement,
      deviceClass: deviceClass,
      stateClass: stateClass,
      valueTemplate: valueTemplate,
      additionalConfig: additionalConfig,
    );

    final discoveryTopic = '${haConfig.discoveryBaseTopic}/sensor/${haConfig.uniqueId}/$entityId/config';
    final discoveryPayload = jsonEncode(config.toJson());

    try {
      await mqttClient.publish(discoveryTopic, discoveryPayload, retain: true);
      _discoveredEntities[entityId] = true;
      onDiscoverySent?.call(entityId);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  /// Publish discovery messages for all Fisker Ocean signals
  Future<void> publishAllDiscoveries() async {
    // SOC sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_soc',
      name: '${haConfig.deviceName} SOC',
      stateTopic: '${haConfig.stateBaseTopic}/soc',
      unitOfMeasurement: '%',
      deviceClass: 'battery',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.soc }}',
    );

    // Speed sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_speed',
      name: '${haConfig.deviceName} Speed',
      stateTopic: '${haConfig.stateBaseTopic}/speed',
      unitOfMeasurement: 'km/h',
      deviceClass: 'speed',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.speed }}',
    );

    // Power sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_power',
      name: '${haConfig.deviceName} Power',
      stateTopic: '${haConfig.stateBaseTopic}/power',
      unitOfMeasurement: 'kW',
      deviceClass: 'power',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.power }}',
    );

    // Voltage sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_voltage',
      name: '${haConfig.deviceName} Voltage',
      stateTopic: '${haConfig.stateBaseTopic}/voltage',
      unitOfMeasurement: 'V',
      deviceClass: 'voltage',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.voltage }}',
    );

    // Current sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_current',
      name: '${haConfig.deviceName} Current',
      stateTopic: '${haConfig.stateBaseTopic}/current',
      unitOfMeasurement: 'A',
      deviceClass: 'current',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.current }}',
    );

    // Odometer sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_odometer',
      name: '${haConfig.deviceName} Odometer',
      stateTopic: '${haConfig.stateBaseTopic}/odometer',
      unitOfMeasurement: 'km',
      deviceClass: 'distance',
      stateClass: 'total_increasing',
      valueTemplate: '{{ value_json.odometer }}',
    );

    // Battery temperature sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_battery_temp',
      name: '${haConfig.deviceName} Battery Temp',
      stateTopic: '${haConfig.stateBaseTopic}/battery_temp',
      unitOfMeasurement: '°C',
      deviceClass: 'temperature',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.batt_temp }}',
    );

    // GPS Latitude sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_gps_lat',
      name: '${haConfig.deviceName} GPS Latitude',
      stateTopic: '${haConfig.stateBaseTopic}/gps',
      deviceClass: 'latitude',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.lat }}',
    );

    // GPS Longitude sensor
    await publishSensorDiscovery(
      entityId: '${haConfig.uniqueId}_gps_lon',
      name: '${haConfig.deviceName} GPS Longitude',
      stateTopic: '${haConfig.stateBaseTopic}/gps',
      deviceClass: 'longitude',
      stateClass: 'measurement',
      valueTemplate: '{{ value_json.lon }}',
    );

    // Charging status binary sensor
    await _publishBinarySensorDiscovery(
      entityId: '${haConfig.uniqueId}_charging',
      name: '${haConfig.deviceName} Charging',
      stateTopic: '${haConfig.stateBaseTopic}/status',
      deviceClass: 'plug',
      valueTemplate: '{{ value_json.is_charging }}',
    );

    // Parked status binary sensor
    await _publishBinarySensorDiscovery(
      entityId: '${haConfig.uniqueId}_parked',
      name: '${haConfig.deviceName} Parked',
      stateTopic: '${haConfig.stateBaseTopic}/status',
      deviceClass: 'occupancy',
      valueTemplate: '{{ value_json.is_parked }}',
    );

    // DC Fast Charging status binary sensor
    await _publishBinarySensorDiscovery(
      entityId: '${haConfig.uniqueId}_dcfc',
      name: '${haConfig.deviceName} DC Fast Charging',
      stateTopic: '${haConfig.stateBaseTopic}/status',
      deviceClass: 'plug',
      valueTemplate: '{{ value_json.is_dcfc }}',
    );
  }

  /// Publish discovery for binary sensor
  Future<void> _publishBinarySensorDiscovery({
    required String entityId,
    required String name,
    required String stateTopic,
    String? deviceClass,
    String? valueTemplate,
  }) async {
    final config = <String, dynamic>{
      'platform': 'mqtt',
      'name': name,
      'unique_id': entityId,
      'state_topic': stateTopic,
      'payload_on': '1',
      'payload_off': '0',
    };

    if (deviceClass != null) {
      config['device_class'] = deviceClass;
    }
    if (valueTemplate != null) {
      config['value_template'] = valueTemplate;
    }

    final discoveryTopic = '${haConfig.discoveryBaseTopic}/binary_sensor/${haConfig.uniqueId}/$entityId/config';
    final discoveryPayload = jsonEncode(config);

    try {
      await mqttClient.publish(discoveryTopic, discoveryPayload, retain: true);
      _discoveredEntities[entityId] = true;
      onDiscoverySent?.call(entityId);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  /// Publish state for a single sensor
  Future<void> publishSensorState(String entityId, String topic, String state) async {
    try {
      await mqttClient.publish(topic, state, retain: false);
      onStatePublished?.call(entityId, state);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  /// Publish all vehicle states to Home Assistant
  Future<void> publishVehicleState({
    double? soc,
    double? speed,
    double? power,
    double? voltage,
    double? current,
    double? odometer,
    double? battTemp,
    double? lat,
    double? lon,
    bool? isCharging,
    bool? isDcfc,
    bool? isParked,
  }) async {
    final baseTopic = haConfig.stateBaseTopic;

    // Publish individual sensor states
    if (soc != null) {
      await publishSensorState('${haConfig.uniqueId}_soc', '$baseTopic/soc', soc.toStringAsFixed(1));
    }
    if (speed != null) {
      await publishSensorState('${haConfig.uniqueId}_speed', '$baseTopic/speed', speed.toStringAsFixed(1));
    }
    if (power != null) {
      await publishSensorState('${haConfig.uniqueId}_power', '$baseTopic/power', power.toStringAsFixed(2));
    }
    if (voltage != null) {
      await publishSensorState('${haConfig.uniqueId}_voltage', '$baseTopic/voltage', voltage.toStringAsFixed(1));
    }
    if (current != null) {
      await publishSensorState('${haConfig.uniqueId}_current', '$baseTopic/current', current.toStringAsFixed(1));
    }
    if (odometer != null) {
      await publishSensorState('${haConfig.uniqueId}_odometer', '$baseTopic/odometer', odometer.toStringAsFixed(1));
    }
    if (battTemp != null) {
      await publishSensorState('${haConfig.uniqueId}_battery_temp', '$baseTopic/battery_temp', battTemp.toStringAsFixed(1));
    }

    // Publish GPS as a single JSON payload
    if (lat != null || lon != null) {
      final gpsPayload = jsonEncode({
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      });
      await publishSensorState('${haConfig.uniqueId}_gps', '$baseTopic/gps', gpsPayload);
    }

    // Publish status as a single JSON payload
    final statusPayload = jsonEncode({
      if (isCharging != null) 'is_charging': isCharging ? 1 : 0,
      if (isDcfc != null) 'is_dcfc': isDcfc ? 1 : 0,
      if (isParked != null) 'is_parked': isParked ? 1 : 0,
    });
    await publishSensorState('${haConfig.uniqueId}_status', '$baseTopic/status', statusPayload);
  }

  /// Publish vehicle state from a TelemetryPoint-like structure
  Future<void> publishFromTelemetryPoint(Map<String, dynamic> point) async {
    await publishVehicleState(
      soc: point['soc'] as double?,
      speed: point['speed'] as double?,
      power: point['power'] as double?,
      voltage: point['voltage'] as double?,
      current: point['current'] as double?,
      odometer: point['odometer'] as double?,
      battTemp: point['batt_temp'] as double?,
      lat: point['lat'] as double?,
      lon: point['lon'] as double?,
      isCharging: point['is_charging'] == 1,
      isDcfc: point['is_dcfc'] == 1,
      isParked: point['is_parked'] == 1,
    );
  }

  /// Clear all discovery messages for this device
  Future<void> clearDiscoveries() async {
    for (final entityId in _discoveredEntities.keys) {
      final discoveryTopic = '${haConfig.discoveryBaseTopic}/sensor/${haConfig.uniqueId}/$entityId/config';
      try {
        await mqttClient.publish(discoveryTopic, '', retain: true);
      } catch (e) {
        onError?.call(e);
      }
    }
    _discoveredEntities.clear();
  }

  /// Get birth message for Home Assistant (LWT)
  Map<String, dynamic> getBirthMessage() {
    return {
      'device_id': haConfig.uniqueId,
      'device_name': haConfig.deviceName,
      'manufacturer': haConfig.manufacturer,
      'model': haConfig.model,
      'software_version': haConfig.softwareVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
