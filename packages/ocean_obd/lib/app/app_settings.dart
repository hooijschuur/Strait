import 'package:flutter/foundation.dart';

import '../util/json_store.dart';
import '../util/units.dart';

/// User settings persisted in `settings.json`. Secrets (ABRP token) do not
/// belong here; they go in secure storage in Phase 2.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store);

  final JsonFileStore _store;

  /// Imperial by default (PLAN.md §0).
  UnitSystem units = UnitSystem.imperial;

  /// Car software version written into every session header.
  String carOs = '2.2.3';

  /// MQTT settings for Home Assistant integration via Tailscale
  bool mqttEnabled = false;
  String mqttBrokerHost = '';
  int mqttBrokerPort = 1883;
  String mqttClientId = 'strait';
  String mqttUsername = '';
  String mqttPassword = '';
  String homeAssistantDeviceId = 'fisker_ocean';
  String homeAssistantDeviceName = 'Fisker Ocean';
  bool homeAssistantDiscoverySent = false;

  Future<void> load() async {
    final j = await _store.load();
    if (j == null) return;
    units = UnitSystem.values.asNameMap()[j['units']] ?? units;
    carOs = j['car_os'] as String? ?? carOs;
    
    // Load MQTT settings
    mqttEnabled = j['mqtt_enabled'] as bool? ?? mqttEnabled;
    mqttBrokerHost = j['mqtt_broker_host'] as String? ?? mqttBrokerHost;
    mqttBrokerPort = j['mqtt_broker_port'] as int? ?? mqttBrokerPort;
    mqttClientId = j['mqtt_client_id'] as String? ?? mqttClientId;
    mqttUsername = j['mqtt_username'] as String? ?? mqttUsername;
    mqttPassword = j['mqtt_password'] as String? ?? mqttPassword;
    homeAssistantDeviceId = j['ha_device_id'] as String? ?? homeAssistantDeviceId;
    homeAssistantDeviceName = j['ha_device_name'] as String? ?? homeAssistantDeviceName;
    homeAssistantDiscoverySent = j['ha_discovery_sent'] as bool? ?? homeAssistantDiscoverySent;
    
    notifyListeners();
  }

  Future<void> update({UnitSystem? units, String? carOs}) async {
    if (units != null) this.units = units;
    if (carOs != null && carOs.trim().isNotEmpty) this.carOs = carOs.trim();
    notifyListeners();
    await _store.save({'units': this.units.name, 'car_os': this.carOs});
  }

  /// Update MQTT settings
  Future<void> updateMqttSettings({
    bool? enabled,
    String? brokerHost,
    int? brokerPort,
    String? clientId,
    String? username,
    String? password,
    String? deviceId,
    String? deviceName,
    bool? discoverySent,
  }) async {
    if (enabled != null) mqttEnabled = enabled;
    if (brokerHost != null) mqttBrokerHost = brokerHost.trim();
    if (brokerPort != null) mqttBrokerPort = brokerPort;
    if (clientId != null) mqttClientId = clientId.trim();
    if (username != null) mqttUsername = username.trim();
    if (password != null) mqttPassword = password.trim();
    if (deviceId != null) homeAssistantDeviceId = deviceId.trim();
    if (deviceName != null) homeAssistantDeviceName = deviceName.trim();
    if (discoverySent != null) homeAssistantDiscoverySent = discoverySent;
    
    notifyListeners();
    
    await _store.save({
      'units': this.units.name,
      'car_os': this.carOs,
      'mqtt_enabled': this.mqttEnabled,
      'mqtt_broker_host': this.mqttBrokerHost,
      'mqtt_broker_port': this.mqttBrokerPort,
      'mqtt_client_id': this.mqttClientId,
      'mqtt_username': this.mqttUsername,
      'mqtt_password': this.mqttPassword,
      'ha_device_id': this.homeAssistantDeviceId,
      'ha_device_name': this.homeAssistantDeviceName,
      'ha_discovery_sent': this.homeAssistantDiscoverySent,
    });
  }

  /// Clear MQTT settings
  Future<void> clearMqttSettings() async {
    mqttEnabled = false;
    mqttBrokerHost = '';
    mqttBrokerPort = 1883;
    mqttClientId = 'strait';
    mqttUsername = '';
    mqttPassword = '';
    homeAssistantDeviceId = 'fisker_ocean';
    homeAssistantDeviceName = 'Fisker Ocean';
    homeAssistantDiscoverySent = false;
    
    notifyListeners();
    
    await _store.save({
      'units': this.units.name,
      'car_os': this.carOs,
      'mqtt_enabled': this.mqttEnabled,
      'mqtt_broker_host': this.mqttBrokerHost,
      'mqtt_broker_port': this.mqttBrokerPort,
      'mqtt_client_id': this.mqttClientId,
      'mqtt_username': this.mqttUsername,
      'mqtt_password': this.mqttPassword,
      'ha_device_id': this.homeAssistantDeviceId,
      'ha_device_name': this.homeAssistantDeviceName,
      'ha_discovery_sent': this.homeAssistantDiscoverySent,
    });
  }
}
