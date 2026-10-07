import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_obd/network/mqtt_client.dart';

void main() {
  group('MqttConfig', () {
    test('default values', () {
      const config = MqttConfig(brokerHost: 'localhost');
      expect(config.brokerHost, 'localhost');
      expect(config.brokerPort, 1883);
      expect(config.keepAlive, 60);
      expect(config.cleanSession, false);
    });

    test('custom values', () {
      const config = MqttConfig(
        brokerHost: 'mqtt.example.com',
        brokerPort: 8883,
        clientId: 'test-client',
        username: 'testuser',
        password: 'testpass',
        keepAlive: 30,
        cleanSession: true,
      );
      expect(config.brokerHost, 'mqtt.example.com');
      expect(config.brokerPort, 8883);
      expect(config.clientId, 'test-client');
      expect(config.username, 'testuser');
      expect(config.password, 'testpass');
      expect(config.keepAlive, 30);
      expect(config.cleanSession, true);
    });

    test('tailscale factory', () {
      const config = MqttConfig.tailscale(
        tailscaleHost: '100.x.y.z',
        port: 1883,
        clientId: 'strait',
      );
      expect(config.brokerHost, '100.x.y.z');
      expect(config.brokerPort, 1883);
      expect(config.clientId, 'strait');
    });

    test('toString', () {
      const config = MqttConfig(brokerHost: 'localhost', brokerPort: 1883);
      expect(config.toString(), contains('localhost'));
      expect(config.toString(), contains('1883'));
    });
  });

  group('MqttConnectionException', () {
    test('message', () {
      const exception = MqttConnectionException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), contains('Test error'));
    });
  });

  group('OceanMqttClient connectivity checks', () {
    test('getTailscaleIp returns null for invalid host', () async {
      final ip = await OceanMqttClient.getTailscaleIp('invalid-host-that-does-not-exist');
      expect(ip, isNull);
    });

    test('checkTailscaleConnectivity returns false for unreachable host', () async {
      final reachable = await OceanMqttClient.checkTailscaleConnectivity(
        '192.0.2.1', // RFC 5737 test address that should be unreachable
        timeout: const Duration(seconds: 1),
      );
      expect(reachable, false);
    });
  });
}
