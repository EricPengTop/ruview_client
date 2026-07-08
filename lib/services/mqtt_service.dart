import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;
  final String host;
  final int port;
  final void Function(String topic, Map<String, dynamic> payload) onMessage;

  MqttService({
    required this.host,
    required this.port,
    required this.onMessage,
  });

  Future<void> connect() async {
    _client = MqttServerClient(host, 'ruview_client_${DateTime.now().millisecondsSinceEpoch}');
    _client!.port = port;
    _client!.keepAlivePeriod = 30;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier('ruview_client')
        .startClean();
    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect();
    } catch (e) {
      _client = null;
      rethrow;
    }

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final topic = msg.topic;
        String payloadStr;
        if (msg.payload is MqttPublishMessage) {
          payloadStr = MqttPublishPayload.bytesToStringAsString(
              (msg.payload as MqttPublishMessage).payload.message);
        } else {
          continue;
        }

        try {
          final json = jsonDecode(payloadStr) as Map<String, dynamic>;
          onMessage(topic, json);
        } catch (_) {}
      }
    });
  }

  void subscribe(String topic) {
    _client?.subscribe(topic, MqttQos.atMostOnce);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
