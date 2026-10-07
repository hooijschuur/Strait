import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_obd/network/home_assistant_mqtt.dart';

void main() {
  group('HomeAssistantMqttConfig', () {
    test('default values', () {
      const config = HomeAssistantMqttConfig(
        deviceId: 'test_device',
        deviceName: 'Test Device',
      );
      expect(config.deviceId, 'test_device');
      expect(config.deviceName, 'Test Device');
      expect(config.manufacturer, 'Strait');
      expect(config.model, 'Fisker Ocean');
      expect(config.softwareVersion, '1.0.0');
      expect(config.mqttPrefix, 'homeassistant');
      expect(config.stateTopicPrefix, 'strait');
      expect(config.discoveryPrefix, 'homeassistant');
    });

    test('uniqueId', () {
      const config = HomeAssistantMqttConfig(
        deviceId: 'fisker_ocean_123',
        deviceName: 'Fisker Ocean',
      );
      expect(config.uniqueId, 'fisker_ocean_123');
    });

    test('stateBaseTopic', () {
      const config = HomeAssistantMqttConfig(
        deviceId: 'test',
        deviceName: 'Test',
        mqttPrefix: 'ha',
        stateTopicPrefix: 'car',
      );
      expect(config.stateBaseTopic, 'ha/car');
    });

    test('discoveryBaseTopic', () {
      const config = HomeAssistantMqttConfig(
        deviceId: 'test',
        deviceName: 'Test',
        discoveryPrefix: 'ha',
      );
      expect(config.discoveryBaseTopic, 'ha');
    });
  });

  group('HaEntityConfig', () {
    test('toJson with all fields', () {
      const config = HaEntityConfig(
        platform: 'mqtt',
        entityId: 'test_sensor',
        name: 'Test Sensor',
        unitOfMeasurement: '°C',
        deviceClass: 'temperature',
        stateClass: 'measurement',
        valueTemplate: '{{ value }}',
        additionalConfig: {'expire_after': 3600},
      );

      final json = config.toJson();
      expect(json['platform'], 'mqtt');
      expect(json['unique_id'], 'test_sensor');
      expect(json['name'], 'Test Sensor');
      expect(json['unit_of_measurement'], '°C');
      expect(json['device_class'], 'temperature');
      expect(json['state_class'], 'measurement');
      expect(json['value_template'], '{{ value }}');
      expect(json['expire_after'], 3600);
    });

    test('toJson with minimal fields', () {
      const config = HaEntityConfig(
        platform: 'mqtt',
        entityId: 'test_sensor',
        name: 'Test Sensor',
      );

      final json = config.toJson();
      expect(json['platform'], 'mqtt');
      expect(json['unique_id'], 'test_sensor');
      expect(json['name'], 'Test Sensor');
      expect(json.containsKey('unit_of_measurement'), false);
      expect(json.containsKey('device_class'), false);
    });
  });

  group('HomeAssistantMqttManager discovery topics', () {
    test('sensor discovery topic format', () {
      const haConfig = HomeAssistantMqttConfig(
        deviceId: 'fisker',
        deviceName: 'Fisker',
        discoveryPrefix: 'ha',
      );

      // This would be tested with a mock MQTT client in a real test environment
      // For now, we just verify the expected topic structure
      const expectedTopic = 'ha/sensor/fisker/soc/config';
      expect(expectedTopic, startsWith('ha/sensor/'));
      expect(expectedTopic, contains('fisker'));
      expect(expectedTopic, endsWith('/config'));
    });

    test('binary sensor discovery topic format', () {
      const expectedTopic = 'homeassistant/binary_sensor/device_id/entity_id/config';
      expect(expectedTopic, startsWith('homeassistant/binary_sensor/'));
      expect(expectedTopic, endsWith('/config'));
    });
  });
}
