import 'dart:async';
import 'dart:collection';

import 'package:ocean_obd/network/home_assistant_mqtt.dart';
import 'package:ocean_obd/network/mqtt_client.dart';

import '../abrp/telemetry.dart';

/// Sends telemetry to Home Assistant via MQTT on a schedule.
/// This works alongside the ABRP uploader to send data to Home Assistant
/// through a Tailscale-connected MQTT broker.
class MqttUploader {
  MqttUploader({
    required this.mqttClient,
    required this.haManager,
    required this.snapshot,
    DateTime Function()? clock,
    this.drivingInterval = const Duration(seconds: 5),
    this.idleInterval = const Duration(seconds: 30),
    this.bufferLimit = 720,
  }) : _clock = clock ?? DateTime.now;

  final OceanMqttClient mqttClient;
  final HomeAssistantMqttManager haManager;
  final TelemetryPoint? Function() snapshot;
  final DateTime Function() _clock;
  final Duration drivingInterval;
  final Duration idleInterval;
  final int bufferLimit;

  final buffer = Queue<TelemetryPoint>();
  int sent = 0;
  int dropped = 0;
  DateTime? lastSuccessAt;
  String status = 'Not started';

  /// Called after every tick.
  void Function()? onUpdate;

  bool _stopping = false;
  Completer<void>? _wake;
  bool _discoverySent = false;

  Duration get interval {
    final p = snapshot();
    final idle = p != null && (p.isParked == true || p.isCharging == true);
    return idle ? idleInterval : drivingInterval;
  }

  Future<void> run() async {
    _stopping = false;
    
    // Ensure MQTT is connected
    if (!mqttClient.isConnected) {
      try {
        await mqttClient.connect();
        status = 'Connecting to MQTT...';
        onUpdate?.call();
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        status = 'MQTT connection failed: $e';
        onUpdate?.call();
        return;
      }
    }
    
    // Send discovery messages if not already sent
    if (!_discoverySent && mqttClient.isConnected) {
      try {
        await haManager.publishAllDiscoveries();
        _discoverySent = true;
        status = 'Discovery sent, uploading data';
      } catch (e) {
        status = 'Failed to send discovery: $e';
      }
      onUpdate?.call();
    }
    
    while (!_stopping) {
      await tick();
      await _sleep(interval);
    }
    status = 'Stopped';
    onUpdate?.call();
  }

  void stop() {
    _stopping = true;
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  /// One upload cycle: flush the buffer if there is one, then send the
  /// current point.
  Future<void> tick() async {
    final point = snapshot();
    if (point == null) {
      status = 'Waiting for car data';
      onUpdate?.call();
      return;
    }

    if (buffer.isNotEmpty) {
      final flushed = await _flush();
      if (!flushed) {
        _keep(point);
        onUpdate?.call();
        return;
      }
    }

    try {
      await _publishPoint(point);
      lastSuccessAt = _clock();
      sent++;
      status = 'Sending to Home Assistant';
    } catch (e) {
      _keep(point);
      status = 'MQTT error: $e';
    }
    onUpdate?.call();
  }

  /// Sends buffered points.
  Future<bool> _flush() async {
    while (buffer.isNotEmpty) {
      final point = buffer.removeFirst();
      try {
        await _publishPoint(point);
        sent++;
        lastSuccessAt = _clock();
      } catch (e) {
        dropped++;
        return false;
      }
    }
    return true;
  }

  Future<void> _publishPoint(TelemetryPoint point) async {
    if (!mqttClient.isConnected) {
      throw Exception('MQTT client not connected');
    }

    // Convert telemetry point to a map for Home Assistant
    final pointMap = point.toJson();
    
    // Add timestamp to the payload
    pointMap['timestamp'] = DateTime.fromMillisecondsSinceEpoch(point.utc * 1000).toIso8601String();
    
    // Publish to Home Assistant
    await haManager.publishFromTelemetryPoint(pointMap);
  }

  void _keep(TelemetryPoint p) {
    buffer.addLast(p);
    while (buffer.length > bufferLimit) {
      buffer.removeFirst();
      dropped++;
    }
  }

  Future<void> _sleep(Duration d) async {
    if (_stopping) return;
    final wake = _wake = Completer<void>();
    await Future.any([wake.future, Future<void>.delayed(d)]);
  }

  /// Reconnect to MQTT broker
  Future<bool> reconnect() async {
    try {
      if (mqttClient.isConnected) {
        await mqttClient.disconnect();
      }
      await mqttClient.connect();
      _discoverySent = false; // Reset discovery flag to resend on reconnect
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if MQTT is connected
  bool get isConnected => mqttClient.isConnected;

  /// Get MQTT connection state
  MqttConnectionState get connectionState => mqttClient.state;
}
