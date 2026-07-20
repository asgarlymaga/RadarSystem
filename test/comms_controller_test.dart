import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tech_radar/features/comms/comms_controller.dart';

void main() {
  group('CommsController Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Loads default codename and updates it successfully', () async {
      final controller = CommsController(prefs: prefs);
      expect(controller.codename, 'SPECTRE_01');

      await controller.setCodename('NEO_MATRIX');
      expect(controller.codename, 'NEO_MATRIX');
      expect(prefs.getString('comms_codename'), 'NEO_MATRIX');
    });

    test('Sending LAN message adds to message list and parses correct fields', () async {
      final controller = CommsController(prefs: prefs);

      // Give the async _startUdpListener a moment to run and add the system message
      await Future.delayed(Duration.zero);
      expect(controller.lanMessages.length, 1); // 1 system startup message

      await controller.sendLanMessage('Awaiting connection...');

      // Should have 2 messages now: 1 system, 1 user sent
      expect(controller.lanMessages.length, 2);
      final userMsg = controller.lanMessages.last;
      expect(userMsg.text, 'Awaiting connection...');
      expect(userMsg.sender, 'SPECTRE_01');
      expect(userMsg.isMe, true);
      expect(userMsg.isSystem, false);
    });

    test('Establishing BLE Link correctly registers active device and initiates handshake', () async {
      final controller = CommsController(prefs: prefs);
      const devId = 'AA:BB:CC:DD:EE:FF';
      const devName = 'HEADPHONES_9000';

      expect(controller.activeBleDeviceIds.contains(devId), false);

      await controller.establishBleLink(devId, devName);

      expect(controller.activeBleDeviceIds.contains(devId), true);

      // Should have established direct link successfully
      final chatList = controller.bleChats[devId];
      expect(chatList, isNotNull);
      // Wait or verify system messages and startup peer response
      expect(chatList!.isNotEmpty, true);
    });

    test('Sending a BLE message appends user message and simulates chatbot reply', () async {
      final controller = CommsController(prefs: prefs);
      const devId = 'AA:BB:CC:DD:EE:FF';
      const devName = 'BEACON_NODE';

      await controller.establishBleLink(devId, devName);
      final initialCount = controller.bleChats[devId]!.length;

      // Don't await sendBleMessage directly if we want to check intermediate state,
      // or we can just await it since it waits for the reply too!
      final future = controller.sendBleMessage(devId, devName, 'status');

      // Check immediately after calling (microtask yield)
      await Future.delayed(Duration.zero);
      expect(controller.bleChats[devId]!.length, initialCount + 1);
      expect(controller.bleChats[devId]!.last.text, 'status');
      expect(controller.bleChats[devId]!.last.isMe, true);

      // Now await the full completion of the sendBleMessage method (including reply delay)
      await future;

      expect(controller.bleChats[devId]!.length, initialCount + 2);
      final reply = controller.bleChats[devId]!.last;
      expect(reply.isMe, false);
      expect(reply.sender, 'BEACON_NODE');
      expect(reply.text.contains('NODE DIAGNOSTICS'), true);
    });
  });
}
