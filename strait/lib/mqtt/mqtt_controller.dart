import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ocean_obd/app/app_settings.dart';
import 'package:ocean_obd/network/home_assistant_mqtt.dart';
import 'package:ocean_obd/network/mqtt_client.dart';
import 'package:ocean_obd/signals/signal_table.dart';
import 'package:ocean_obd/ui/connect_controller.dart';

import '../abrp/vehicle_state.dart';
import 'mqtt_uploader.dart';

/// Manages MQTT connection and Home Assistant integration for Strait.
/// This controller handles the MQTT client lifecycle and coordinates
/// between the vehicle state and Home Assistant MQTT publishing.
class MqttController extends ChangeNotifier {
  MqttController({
    required this.connect,
    required this.table,
    required this.settings,
    required this.vehicle,
  });

  final ConnectController connect;
  final SignalTable table;
  final AppSettings settings;
  final VehicleState vehicle;

  OceanMqttClient? _mqttClient;
  HomeAssistantMqttManager? _haManager;
  MqttUploader? _uploader;

  String? error;
  bool _discoverySent = false;
  bool _linking = false;

  bool get isConnected => _mqttClient?.isConnected ?? false;
  bool get isLinking => _linking;
  MqttConnectionState get connectionState => _mqttClient?.state ?? MqttConnectionState.disconnected;
  MqttUploader? get uploader => _uploader;

  /// Start MQTT uploading to Home Assistant
  Future<void> start() async {
    if (_linking) return;
    
    if (!settings.mqttEnabled) {
      error = 'MQTT is not enabled in settings';
      notifyListeners();
      return;
    }
    
    if (settings.mqttBrokerHost.isEmpty) {
      error = 'MQTT broker host is not configured';
      notifyListeners();
      return;
    }

    error = null;
    _linking = true;
    notifyListeners();

    try {
      // Create MQTT configuration
      final config = MqttConfig(
        brokerHost: settings.mqttBrokerHost,
        brokerPort: settings.mqttBrokerPort,
        clientId: settings.mqttClientId.isNotEmpty ? settings.mqttClientId : 'strait_${DateTime.now().millisecondsSinceEpoch}',
        username: settings.mqttUsername.isNotEmpty ? settings.mqttUsername : null,
        password: settings.mqttPassword.isNotEmpty ? settings.mqttPassword : null,
      );

      // Create MQTT client
      final mqttClient = _mqttClient = OceanMqttClient(
        config: config,
        onStateChanged: (state) {
          notifyListeners();
        },
        onError: (e) {
          error = 'MQTT error: $e';
          notifyListeners();
        },
      );

      // Create Home Assistant configuration
      final haConfig = HomeAssistantMqttConfig(
        deviceId: settings.homeAssistantDeviceId,
        deviceName: settings.homeAssistantDeviceName,
        manufacturer: 'Strait',
        model: 'Fisker Ocean',
      );

      // Create Home Assistant manager
      final haManager = _haManager = HomeAssistantMqttManager(
        mqttClient: mqttClient,
        haConfig: haConfig,
        onDiscoverySent: (entityId) {
          _discoverySent = true;
          settings.homeAssistantDiscoverySent = true;
        },
        onError: (e) {
          error = 'Home Assistant discovery error: $e';
          notifyListeners();
        },
      );

      // Create uploader
      final uploader = _uploader = MqttUploader(
        mqttClient: mqttClient,
        haManager: haManager,
        snapshot: vehicle.snapshot,
      );
      uploader.onUpdate = () => notifyListeners();

      // Start uploading
      await uploader.run();
      
    } catch (e) {
      error = 'Failed to start MQTT: $e';
      await stop();
    }
    
    notifyListeners();
  }

  /// Stop MQTT uploading
  Future<void> stop() async {
    _linking = false;
    await _uploader?.stop();
    await _mqttClient?.disconnect();
    _uploader = null;
    _mqttClient = null;
    _haManager = null;
    error = null;
    notifyListeners();
  }

  /// Toggle MQTT linking
  Future<void> toggle() async {
    if (_linking) {
      await stop();
    } else {
      await start();
    }
  }

  /// Reconnect to MQTT broker
  Future<void> reconnect() async {
    await stop();
    await start();
  }

  /// Check Tailscale connectivity to the MQTT broker
  Future<bool> checkTailscaleConnectivity() async {
    if (settings.mqttBrokerHost.isEmpty) {
      return false;
    }
    return await OceanMqttClient.checkTailscaleConnectivity(
      settings.mqttBrokerHost,
      timeout: const Duration(seconds: 5),
    );
  }

  /// Get Tailscale IP for the MQTT broker
  Future<String?> getTailscaleIp() async {
    if (settings.mqttBrokerHost.isEmpty) {
      return null;
    }
    return await OceanMqttClient.getTailscaleIp(settings.mqttBrokerHost);
  }

  /// Send test message to verify MQTT connection
  Future<bool> sendTestMessage() async {
    if (_mqttClient == null || !_mqttClient!.isConnected) {
      return false;
    }
    
    try {
      final testTopic = 'strait/test';
      final testMessage = jsonEncode({
        'message': 'Test from Strait',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _mqttClient!.publish(testTopic, testMessage);
      return true;
    } catch (e) {
      error = 'Test message failed: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _uploader?.stop();
    _mqttClient?.dispose();
    super.dispose();
  }
}
