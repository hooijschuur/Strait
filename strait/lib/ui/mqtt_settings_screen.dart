import 'package:flutter/material.dart';

import 'package:ocean_obd/network/mqtt_client.dart';
import 'link_controller.dart';

/// Settings screen for MQTT and Home Assistant configuration
class MqttSettingsScreen extends StatefulWidget {
  const MqttSettingsScreen({super.key, required this.controller});

  final LinkController controller;

  @override
  State<MqttSettingsScreen> createState() => _MqttSettingsScreenState();
}

class _MqttSettingsScreenState extends State<MqttSettingsScreen> {
  final _brokerHostController = TextEditingController();
  final _brokerPortController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();

  bool _enabled = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _enabled = settings.mqttEnabled;
    _brokerHostController.text = settings.mqttBrokerHost;
    _brokerPortController.text = settings.mqttBrokerPort.toString();
    _clientIdController.text = settings.mqttClientId;
    _usernameController.text = settings.mqttUsername;
    _passwordController.text = settings.mqttPassword;
    _deviceIdController.text = settings.homeAssistantDeviceId;
    _deviceNameController.text = settings.homeAssistantDeviceName;
  }

  @override
  void dispose() {
    _brokerHostController.dispose();
    _brokerPortController.dispose();
    _clientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = widget.controller.settings;
    
    try {
      await settings.updateMqttSettings(
        enabled: _enabled,
        brokerHost: _brokerHostController.text,
        brokerPort: int.tryParse(_brokerPortController.text) ?? 1883,
        clientId: _clientIdController.text.isEmpty ? 'strait' : _clientIdController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        deviceId: _deviceIdController.text.isEmpty ? 'fisker_ocean' : _deviceIdController.text,
        deviceName: _deviceNameController.text.isEmpty ? 'Fisker Ocean' : _deviceNameController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MQTT settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (_brokerHostController.text.isEmpty) {
      setState(() => _testResult = 'Please enter a broker host');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = 'Testing...';
    });

    try {
      final reachable = await OceanMqttClient.checkTailscaleConnectivity(
        _brokerHostController.text,
        timeout: const Duration(seconds: 5),
      );
      
      setState(() {
        _testing = false;
        _testResult = reachable ? 'Connection successful' : 'Connection failed';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = 'Test failed: $e';
      });
    }
  }

  Future<void> _clearSettings() async {
    final settings = widget.controller.settings;
    
    try {
      await settings.clearMqttSettings();
      if (mounted) {
        setState(() {
          _enabled = false;
          _brokerHostController.clear();
          _brokerPortController.text = '1883';
          _clientIdController.text = 'strait';
          _usernameController.clear();
          _passwordController.clear();
          _deviceIdController.text = 'fisker_ocean';
          _deviceNameController.text = 'Fisker Ocean';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MQTT settings cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home Assistant MQTT Integration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure MQTT broker connection to send vehicle data to Home Assistant via Tailscale.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tailscale creates a secure peer-to-peer network, so you can connect to your Home Assistant MQTT broker from anywhere.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: const Text('Enable MQTT Integration'),
            subtitle: const Text('Enable sending data to Home Assistant via MQTT'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('MQTT Broker', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          TextField(
            controller: _brokerHostController,
            decoration: const InputDecoration(
              labelText: 'Broker Host',
              hintText: 'e.g., tailscale-ip or hostname',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _brokerPortController,
            decoration: const InputDecoration(
              labelText: 'Broker Port',
              hintText: 'e.g., 1883',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientIdController,
            decoration: const InputDecoration(
              labelText: 'Client ID (optional)',
              hintText: 'e.g., strait',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            obscureText: true,
          ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Home Assistant Device', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          TextField(
            controller: _deviceIdController,
            decoration: const InputDecoration(
              labelText: 'Device ID',
              hintText: 'e.g., fisker_ocean',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'e.g., Fisker Ocean',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          
          const SizedBox(height: 16),
          
          // Test connection button
          if (_brokerHostController.text.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Verify that your device can connect to the MQTT broker via Tailscale.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _testing ? null : _testConnection,
                      child: Text(_testing ? 'Testing...' : 'Test Connection'),
                    ),
                    if (_testResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testResult!.contains('successful') 
                                ? Colors.green 
                                : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Save and clear buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: _clearSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Clear Settings'),
              ),
              FilledButton(
                onPressed: _save,
                child: const Text('Save Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
