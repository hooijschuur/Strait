import 'package:flutter_test/flutter_test.dart';
import 'package:strait/mqtt/mqtt_controller.dart';
import 'package:strait/mqtt/mqtt_uploader.dart';
import 'package:strait/abrp/telemetry.dart';
import 'package:strait/abrp/vehicle_state.dart';
import 'package:ocean_obd/app/app_settings.dart';
import 'package:ocean_obd/network/home_assistant_mqtt.dart';
import 'package:ocean_obd/network/mqtt_client.dart';
import 'package:ocean_obd/signals/signal_table.dart';
import 'package:ocean_obd/ui/connect_controller.dart';
import 'package:ocean_obd/util/json_store.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  group('MqttUploader', () {
    late MockMqttClient mockMqttClient;
    late MockHomeAssistantMqttManager mockHaManager;
    late VehicleState vehicleState;

    setUp(() {
      mockMqttClient = MockMqttClient();
      mockHaManager = MockHomeAssistantMqttManager();
      vehicleState = VehicleState();
    });

    test('constructor with default values', () {
      final uploader = MqttUploader(
        mqttClient: mockMqttClient,
        haManager: mockHaManager,
        snapshot: vehicleState.snapshot,
      );
      expect(uploader.drivingInterval, const Duration(seconds: 5));
      expect(uploader.idleInterval, const Duration(seconds: 30));
      expect(uploader.bufferLimit, 720);
    });

    test('interval calculation when parked', () {
      final uploader = MqttUploader(
        mqttClient: mockMqttClient,
        haManager: mockHaManager,
        snapshot: () => TelemetryPoint(
          utc: 1790000000,
          isParked: true,
        ),
      );
      expect(uploader.interval, const Duration(seconds: 30));
    });

    test('interval calculation when charging', () {
      final uploader = MqttUploader(
        mqttClient: mockMqttClient,
        haManager: mockHaManager,
        snapshot: () => TelemetryPoint(
          utc: 1790000000,
          isCharging: true,
        ),
      );
      expect(uploader.interval, const Duration(seconds: 30));
    });

    test('interval calculation when driving', () {
      final uploader = MqttUploader(
        mqttClient: mockMqttClient,
        haManager: mockHaManager,
        snapshot: () => TelemetryPoint(
          utc: 1790000000,
          speed: 50.0,
        ),
      );
      expect(uploader.interval, const Duration(seconds: 5));
    });
  });

  group('MqttController', () {
    late MockConnectController mockConnectController;
    late MockSignalTable mockSignalTable;
    late AppSettings appSettings;
    late VehicleState vehicleState;

    setUp(() async {
      mockConnectController = MockConnectController();
      mockSignalTable = MockSignalTable();
      
      final docsDir = await getTemporaryDirectory();
      final store = JsonFileStore(File('${docsDir.path}/test_settings.json'));
      appSettings = AppSettings(store);
      await appSettings.load();
      
      vehicleState = VehicleState();
    });

    test('initial state', () {
      final controller = MqttController(
        connect: mockConnectController,
        table: mockSignalTable,
        settings: appSettings,
        vehicle: vehicleState,
      );
      expect(controller.isConnected, false);
      expect(controller.isLinking, false);
      expect(controller.error, isNull);
    });

    test('start fails when MQTT not enabled', () async {
      appSettings.mqttEnabled = false;
      
      final controller = MqttController(
        connect: mockConnectController,
        table: mockSignalTable,
        settings: appSettings,
        vehicle: vehicleState,
      );
      
      await controller.start();
      expect(controller.error, contains('not enabled'));
    });

    test('start fails when broker host not configured', () async {
      appSettings.mqttEnabled = true;
      appSettings.mqttBrokerHost = '';
      
      final controller = MqttController(
        connect: mockConnectController,
        table: mockSignalTable,
        settings: appSettings,
        vehicle: vehicleState,
      );
      
      await controller.start();
      expect(controller.error, contains('not configured'));
    });
  });

  group('TelemetryPoint to Home Assistant', () {
    test('telemetry point conversion for Home Assistant', () {
      final point = TelemetryPoint(
        utc: 1790000000,
        soc: 75.5,
        speed: 50.0,
        power: 15.25,
        voltage: 400.5,
        current: 38.1,
        odometer: 12345.6,
        battTemp: 22.5,
        lat: 52.123456,
        lon: 4.654321,
        isCharging: true,
        isDcfc: false,
        isParked: false,
      );

      final json = point.toJson();
      expect(json['soc'], 75.5);
      expect(json['speed'], 50.0);
      expect(json['power'], 15.25);
      expect(json['voltage'], 400.5);
      expect(json['current'], 38.1);
      expect(json['odometer'], 12345.6);
      expect(json['batt_temp'], 22.5);
      expect(json['lat'], 52.123456);
      expect(json['lon'], 4.654321);
      expect(json['is_charging'], 1);
      expect(json['is_dcfc'], 0);
      expect(json['is_parked'], 0);
    });
  });
}

// Mock classes for testing
class MockMqttClient extends OceanMqttClient {
  MockMqttClient() : super(
    config: MqttConfig(brokerHost: 'test', brokerPort: 1883),
  );

  @override
  bool isConnected = true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> publish(String topic, String message, {int qos = 0, bool retain = false}) async {}
}

class MockHomeAssistantMqttManager extends HomeAssistantMqttManager {
  MockHomeAssistantMqttManager() : super(
    mqttClient: MockMqttClient(),
    haConfig: HomeAssistantMqttConfig(
      deviceId: 'test',
      deviceName: 'Test',
    ),
  );

  @override
  Future<void> publishFromTelemetryPoint(Map<String, dynamic> point) async {}

  @override
  Future<void> publishAllDiscoveries() async {}
}

class MockConnectController extends ConnectController {
  MockConnectController() : super(SignalTable.parse('{"os_version": "test", "modules": {}, "signals": []}'));
}

class MockSignalTable extends SignalTable {
  MockSignalTable() : super(
    osVersion: 'test',
    modules: {},
    signals: [],
  );
}
