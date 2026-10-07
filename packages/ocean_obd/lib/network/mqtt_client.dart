import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// MQTT connection configuration for Home Assistant via Tailscale.
enum MqttConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class MqttConfig {
  const MqttConfig({
    required this.brokerHost,
    this.brokerPort = 1883,
    this.clientId,
    this.username,
    this.password,
    this.keepAlive = 60,
    this.cleanSession = false,
    this.timeout = const Duration(seconds: 30),
  });

  final String brokerHost;
  final int brokerPort;
  final String? clientId;
  final String? username;
  final String? password;
  final int keepAlive;
  final bool cleanSession;
  final Duration timeout;

  String get brokerUrl => brokerHost;
  int get port => brokerPort;

  /// For Tailscale, use the Tailscale IP or hostname
  factory MqttConfig.tailscale({
    required String tailscaleHost,
    int port = 1883,
    String? clientId,
  }) {
    return MqttConfig(
      brokerHost: tailscaleHost,
      brokerPort: port,
      clientId: clientId,
    );
  }

  @override
  String toString() => 'MqttConfig(host: $brokerHost, port: $brokerPort, clientId: $clientId)';
}

class MqttConnectionException implements Exception {
  MqttConnectionException(this.message);
  final String message;
  @override
  String toString() => 'MqttConnectionException: $message';
}

/// Wrapper for MQTT client operations with Tailscale support.
/// This class handles connection, disconnection, and message publishing
/// for Home Assistant MQTT integration.
class OceanMqttClient {
  OceanMqttClient({
    required this.config,
    this.onStateChanged,
    this.onMessagePublished,
    this.onError,
  }) : _client = MqttServerClient(config.brokerHost, config.clientId ?? '');

  final MqttConfig config;
  final void Function(MqttConnectionState)? onStateChanged;
  final void Function(String topic)? onMessagePublished;
  final void Function(dynamic error)? onError;

  final MqttServerClient _client;

  MqttConnectionState _state = MqttConnectionState.disconnected;
  MqttConnectionState get state => _state;

  bool get isConnected => _state == MqttConnectionState.connected;

  /// Connect to the MQTT broker
  Future<void> connect() async {
    if (_state == MqttConnectionState.connected) {
      return;
    }

    _setState(MqttConnectionState.connecting);

    try {
      _client.port = config.brokerPort;
      _client.keepAlivePeriod = config.keepAlive;
      _client.cleanSession = config.cleanSession;
      _client.timeout = config.timeout;

      if (config.username != null) {
        _client.logging(on: false);
        _client.onDisconnected = _onDisconnected;
        _client.onConnected = _onConnected;
        _client.onSubscribed = _onSubscribed;

        final connMess = MqttConnectMessage()
            .withClientIdentifier(config.clientId ?? '')
            .keepAliveFor(config.keepAlive)
            .withWillTopic('willtopic')
            .withWillMessage('Will message')
            .startClean();

        if (config.username != null) {
          connMess.authenticateAs(config.username!, config.password ?? '');
        }

        await _client.connect(config.username, config.password);
        _setState(MqttConnectionState.connected);
      } else {
        // No authentication
        await _client.connect();
        _setState(MqttConnectionState.connected);
      }
    } catch (e) {
      _setState(MqttConnectionState.error);
      onError?.call(e);
      throw MqttConnectionException('Failed to connect to MQTT broker: $e');
    }
  }

  /// Disconnect from the MQTT broker
  Future<void> disconnect() async {
    if (_state != MqttConnectionState.connected) {
      return;
    }

    try {
      _client.disconnect();
      _setState(MqttConnectionState.disconnected);
    } catch (e) {
      _setState(MqttConnectionState.error);
      onError?.call(e);
      throw MqttConnectionException('Failed to disconnect: $e');
    }
  }

  /// Publish a message to a topic
  Future<void> publish(String topic, String message, {int qos = 0, bool retain = false}) async {
    if (_state != MqttConnectionState.connected) {
      throw MqttConnectionException('Cannot publish: not connected to MQTT broker');
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client.publishMessage(topic, qos, builder.payload!, retain: retain);
      onMessagePublished?.call(topic);
    } catch (e) {
      onError?.call(e);
      throw MqttConnectionException('Failed to publish message to $topic: $e');
    }
  }

  /// Publish a message with QoS 1 for better reliability
  Future<void> publishReliable(String topic, String message, {bool retain = false}) async {
    await publish(topic, message, qos: 1, retain: retain);
  }

  /// Subscribe to a topic
  Future<void> subscribe(String topic, {int qos = 0}) async {
    if (_state != MqttConnectionState.connected) {
      throw MqttConnectionException('Cannot subscribe: not connected to MQTT broker');
    }

    try {
      _client.subscribe(topic, qos);
    } catch (e) {
      onError?.call(e);
      throw MqttConnectionException('Failed to subscribe to $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribe(String topic) async {
    if (_state != MqttConnectionState.connected) {
      return;
    }

    try {
      _client.unsubscribe(topic);
    } catch (e) {
      onError?.call(e);
    }
  }

  /// Check if the device can reach the MQTT broker via Tailscale
  /// This is a simple connectivity check using ping
  static Future<bool> checkTailscaleConnectivity(String host, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      // Try to resolve the hostname first
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        return false;
      }

      // Try to establish a socket connection
      final socket = await Socket.connect(host, 1883, timeout: timeout);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the Tailscale IP address for a given hostname
  /// This returns the first IP address resolved for the hostname
  static Future<String?> getTailscaleIp(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        return null;
      }
      // Return the first IP address
      return addresses.first.address;
    } catch (e) {
      return null;
    }
  }

  void _setState(MqttConnectionState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  void _onConnected() {
    _setState(MqttConnectionState.connected);
  }

  void _onDisconnected() {
    _setState(MqttConnectionState.disconnected);
  }

  void _onSubscribed(String topic) {
    // Could notify about successful subscription
  }

  /// Dispose the client
  void dispose() {
    _client.disconnect();
  }
}
