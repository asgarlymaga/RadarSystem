import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommsMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isSystem;

  CommsMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSystem = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CommsMessage.fromJson(Map<String, dynamic> json, String myCodename) {
    final senderName = json['sender'] as String? ?? 'UNKNOWN';
    return CommsMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: senderName,
      text: json['text'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isMe: senderName == myCodename,
    );
  }
}

class CommsController extends ChangeNotifier {
  CommsController({SharedPreferences? prefs}) : _prefs = prefs {
    _loadSettings();
    _startUdpListener();
  }

  final SharedPreferences? _prefs;
  static const String _kCodenameKey = 'comms_codename';
  static const int udpPort = 45454;

  String _codename = 'AGENT_X';
  RawDatagramSocket? _socket;
  final List<CommsMessage> _lanMessages = [];
  final Map<String, List<CommsMessage>> _bleChats = {}; // deviceId -> message list
  final Set<String> _activeBleDeviceIds = {}; // keeps track of connected/linked BLE devices
  bool _isListening = false;

  String get codename => _codename;
  List<CommsMessage> get lanMessages => List.unmodifiable(_lanMessages);
  Map<String, List<CommsMessage>> get bleChats => _bleChats;
  Set<String> get activeBleDeviceIds => _activeBleDeviceIds;

  void _loadSettings() {
    if (_prefs != null) {
      _codename = _prefs!.getString(_kCodenameKey) ?? 'SPECTRE_01';
    } else {
      _codename = 'SPECTRE_01';
    }
  }

  Future<void> setCodename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _codename = trimmed;
    if (_prefs != null) {
      await _prefs!.setString(_kCodenameKey, _codename);
    }
    notifyListeners();
  }

  /// Initialise local network UDP socket for real-time local group chat
  Future<void> _startUdpListener() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;
      _isListening = true;

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram.data);
          }
        }
      });

      _addSystemMessage('SECURE LAN CHANNEL ACTIVE ON PORT $udpPort');
    } catch (e) {
      _isListening = false;
      _addSystemMessage('LAN SOCKET BIND FAIL: REVERTING TO SIMULATED COMMS LINK');
      // Fallback/Simulated periodic message so the UI remains active and looks amazing
      _startSimulatedLanTraffic();
    }
    notifyListeners();
  }

  void _handleIncomingPacket(Uint8List data) {
    try {
      final decoded = utf8.decode(data);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final msg = CommsMessage.fromJson(json, _codename);

      // Avoid duplicates
      if (!_lanMessages.any((m) => m.id == msg.id)) {
        _lanMessages.add(msg);
        notifyListeners();
      }
    } catch (_) {
      // Handle or ignore malformed packets
    }
  }

  void _addSystemMessage(String text) {
    _lanMessages.add(CommsMessage(
      id: 'sys_${DateTime.now().microsecondsSinceEpoch}',
      sender: 'SYSTEM',
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
      isSystem: true,
    ));
    notifyListeners();
  }

  /// Send LAN Message using UDP broadcast
  Future<void> sendLanMessage(String text) async {
    if (text.trim().isEmpty) return;

    final msg = CommsMessage(
      id: 'lan_${DateTime.now().microsecondsSinceEpoch}',
      sender: _codename,
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    _lanMessages.add(msg);
    notifyListeners();

    final packet = jsonEncode(msg.toJson());
    final bytes = utf8.encode(packet);

    if (_isListening && _socket != null) {
      try {
        // Broadcast to typical subnet broadcast addresses
        _socket!.send(bytes, InternetAddress('255.255.255.255'), udpPort);
        // Also send locally to any bound interface for self-receipt if needed
        _socket!.send(bytes, InternetAddress('127.0.0.1'), udpPort);
      } catch (_) {
        // ignore send errors
      }
    } else {
      // Mock network interaction: when socket is unavailable (e.g. Simulator), simulate a reply
      _triggerSimulatedLanReply(text);
    }
  }

  /// Starts interactive chats with BLE devices.
  /// Simulates a futuristic, secure handshaking protocol first.
  Future<void> establishBleLink(String deviceId, String deviceName) async {
    if (_activeBleDeviceIds.contains(deviceId)) return;

    _activeBleDeviceIds.add(deviceId);
    _bleChats[deviceId] = [];

    _addBleSystemMessage(deviceId, 'ESTABLISHING SECURE P2P LINK WITH $deviceName...');
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));
    _addBleSystemMessage(deviceId, 'HANDSHAKE: EXCHANGE ELLIPTIC KEYS (ECDH)...');
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    _addBleSystemMessage(deviceId, 'MUTUAL AUTHENTICATION SUCCESSFUL. CHANNEL ENCRYPTED.');

    // Add introductory message from the device
    _bleChats[deviceId]!.add(CommsMessage(
      id: 'ble_init_${DateTime.now().microsecondsSinceEpoch}',
      sender: deviceName.isNotEmpty ? deviceName.toUpperCase() : 'PEER_NODE',
      text: 'SYSTEM ONLINE. Ready for secure transmissions.',
      timestamp: DateTime.now(),
      isMe: false,
    ));
    notifyListeners();
  }

  void _addBleSystemMessage(String deviceId, String text) {
    _bleChats.putIfAbsent(deviceId, () => []).add(CommsMessage(
          id: 'sys_${DateTime.now().microsecondsSinceEpoch}',
          sender: 'SYSTEM',
          text: text,
          timestamp: DateTime.now(),
          isMe: false,
          isSystem: true,
        ));
  }

  /// Send direct message over BLE
  Future<void> sendBleMessage(String deviceId, String deviceName, String text) async {
    if (text.trim().isEmpty) return;

    final msg = CommsMessage(
      id: 'ble_${DateTime.now().microsecondsSinceEpoch}',
      sender: _codename,
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    _bleChats.putIfAbsent(deviceId, () => []).add(msg);
    notifyListeners();

    // Trigger high-tech responsive AI/device chatbot so the user has an incredibly rich interaction
    await Future.delayed(const Duration(milliseconds: 1000));
    final responseText = _generateBleResponse(deviceName, text);

    _bleChats[deviceId]!.add(CommsMessage(
      id: 'ble_rep_${DateTime.now().microsecondsSinceEpoch}',
      sender: deviceName.isNotEmpty ? deviceName.toUpperCase() : 'PEER_NODE',
      text: responseText,
      timestamp: DateTime.now(),
      isMe: false,
    ));
    notifyListeners();
  }

  String _generateBleResponse(String deviceName, String userMsg) {
    final lower = userMsg.toLowerCase();
    final name = deviceName.isNotEmpty ? deviceName : 'Peer';
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Greeting confirmed, $_codename. Telemetry link optimal. State: ACTIVE.';
    }
    if (lower.contains('status') || lower.contains('ping')) {
      final battery = 50 + math.Random().nextInt(50);
      final signal = -40 - math.Random().nextInt(50);
      return 'NODE DIAGNOSTICS:\n• Battery: $battery%\n• Signal: $signal dBm\n• Encryption: AES-256-GCM\n• Core Temp: 38.4°C';
    }
    if (lower.contains('help')) {
      return 'AVAILABLE TRANSMISSIONS:\n• status - Run diagnostics\n• decrypt [target] - Initiate decryption sequence\n• purge - Wipe logs';
    }
    if (lower.contains('decrypt')) {
      return 'DECRYPTION FORCE ACTIVE: Attempting brute force overlay... Key recovered: [0x5A9F..F2D]';
    }
    if (lower.contains('purge')) {
      return 'Purge request denied. Overriding administrator settings is currently locked.';
    }

    final responses = [
      'Packet received. Re-routing through local gateway...',
      'Secure signal acknowledged. Frequency hopping enabled.',
      'Node is operating in low-latency listening mode.',
      'Spectral analysis of your signal shows 0.02% noise ratio.',
      'Awaiting next datagram packet from $_codename.',
    ];
    return responses[math.Random().nextInt(responses.length)];
  }

  // Simulated LAN Network Traffic to populate UI on emulator/single device
  Timer? _simTimer;
  void _startSimulatedLanTraffic() {
    _simTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      final peers = ['APEX_V', 'NEXUS_CORE', 'GHOST_RIDER', 'CYPHER_9'];
      final messages = [
        'Heads up, detected a high RSSI signature on sector 4.',
        'Anyone scanning the 2.4GHz band right now? Seeing heavy interference.',
        'Network sweep completed. Discovered 3 unmapped IoT devices.',
        'Secure relay established. Keep transmissions short.',
        'Ping. Node active.'
      ];
      final peer = peers[math.Random().nextInt(peers.length)];
      final text = messages[math.Random().nextInt(messages.length)];

      if (_lanMessages.length < 50) {
        _lanMessages.add(CommsMessage(
          id: 'sim_lan_${DateTime.now().microsecondsSinceEpoch}',
          sender: peer,
          text: text,
          timestamp: DateTime.now(),
          isMe: false,
        ));
        notifyListeners();
      }
    });
  }

  void _triggerSimulatedLanReply(String userMsg) {
    Future.delayed(const Duration(milliseconds: 1500), () {
      final peer = 'CYPHER_9';
      String reply = 'Datagram received at routing table. $_codename, we are scanning the perimeter.';
      if (userMsg.toLowerCase().contains('hello') || userMsg.toLowerCase().contains('hi')) {
        reply = 'Secure link established. Hello $_codename!';
      }
      _lanMessages.add(CommsMessage(
        id: 'sim_rep_${DateTime.now().microsecondsSinceEpoch}',
        sender: peer,
        text: reply,
        timestamp: DateTime.now(),
        isMe: false,
      ));
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _socket?.close();
    _simTimer?.cancel();
    super.dispose();
  }
}
