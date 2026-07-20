import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'comms_controller.dart';

/// Dark cybernetic Sci-Fi Chat/Comms hub UI screen (LAN Group and BLE P2P Direct Chat).
class CommsHubScreen extends StatefulWidget {
  final String? initialBleDeviceId;
  final String? initialBleDeviceName;

  const CommsHubScreen({
    super.key,
    this.initialBleDeviceId,
    this.initialBleDeviceName,
  });

  @override
  State<CommsHubScreen> createState() => _CommsHubScreenState();
}

class _CommsHubScreenState extends State<CommsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _codenameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedBleDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codenameController.text = context.read<CommsController>().codename;

    // If navigated from the BLE detail/scan sheets, automatically establish link and select device
    if (widget.initialBleDeviceId != null) {
      final bleId = widget.initialBleDeviceId!;
      final bleName = widget.initialBleDeviceName ?? 'BLE_NODE';
      _selectedBleDeviceId = bleId;
      _tabController.index = 1; // switch to BLE Chat tab

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CommsController>().establishBleLink(bleId, bleName);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgController.dispose();
    _codenameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final commsCtrl = context.watch<CommsController>();
    final isLanTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SECURE COMMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge, color: AppColors.bleGreen),
            tooltip: 'Configure Codename',
            onPressed: () => _showCodenameDialog(context, commsCtrl),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.bleGreen,
          labelColor: AppColors.bleGreen,
          unselectedLabelColor: AppColors.textMuted,
          onTap: (index) {
            setState(() {});
          },
          tabs: const [
            Tab(
              icon: Icon(Icons.language),
              text: 'LAN CHANNEL',
            ),
            Tab(
              icon: Icon(Icons.bluetooth_connected),
              text: 'BLE SECURE LINK',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sub-status indicator
            _buildStatusHeader(commsCtrl),
            const Divider(height: 1, color: AppColors.surfaceHigh),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // handle manually
                children: [
                  _buildLanTab(commsCtrl),
                  _buildBleTab(commsCtrl),
                ],
              ),
            ),

            // Message Composer Footer
            const Divider(height: 1, color: AppColors.surfaceHigh),
            _buildMessageComposer(commsCtrl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(CommsController commsCtrl) {
    final statusColor = _tabController.index == 0 ? AppColors.wifiBlue : AppColors.bleGreen;
    final statusText = _tabController.index == 0
        ? 'LAN GROUP CHAT  •  PORT ${CommsController.udpPort}'
        : 'P2P DECRYPTED CHANNELS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          Text(
            'CODENAME: ${commsCtrl.codename}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLanTab(CommsController commsCtrl) {
    _scrollToBottom();
    final messages = commsCtrl.lanMessages;

    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'NO ACTIVE TRANSMISSIONS ON SUB-NET.\nSEND A DATAGRAM TO INITIALIZE.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildBleTab(CommsController commsCtrl) {
    final activeIds = commsCtrl.activeBleDeviceIds;

    if (activeIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_searching, size: 48, color: AppColors.bleGreen),
              SizedBox(height: 16),
              Text(
                'NO ESTABLISHED BLE SECURE LINKS',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.bleGreen, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              SizedBox(height: 8),
              Text(
                'Select a discovered device from the wireless radar or scan details, then initialize a "Secure Chat Link" to begin direct messaging.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // If active chats exist but none is currently selected, pick the first one
    if (_selectedBleDeviceId == null || !activeIds.contains(_selectedBleDeviceId)) {
      _selectedBleDeviceId = activeIds.first;
    }

    final currentChatId = _selectedBleDeviceId!;
    final messages = commsCtrl.bleChats[currentChatId] ?? [];
    _scrollToBottom();

    return Row(
      children: [
        // Sidebar lists active devices
        Container(
          width: 80,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.surfaceHigh, width: 1)),
            color: AppColors.surface,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: activeIds.map((id) {
              final isSelected = id == _selectedBleDeviceId;
              final color = isSelected ? AppColors.bleGreen : AppColors.textMuted;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedBleDeviceId = id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceHigh : Colors.transparent,
                    border: isSelected
                        ? const Border(left: BorderSide(color: AppColors.bleGreen, width: 3))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.radar, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        id.length > 5 ? id.substring(id.length - 5) : id,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Expanded Chat pane
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surfaceHigh.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: AppColors.bleGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SECURE P2P LINK: $currentChatId',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, letterSpacing: 1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(CommsMessage msg) {
    if (msg.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
        ),
        child: Text(
          '[SYSTEM] ${msg.text}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      );
    }

    final isMe = msg.isMe;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe
        ? AppColors.bleGreen.withValues(alpha: 0.15)
        : AppColors.surfaceHigh;
    final borderColor = isMe ? AppColors.bleGreen : AppColors.textMuted;
    final senderColor = isMe ? AppColors.bleGreen : AppColors.wifiBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.sender,
                style: TextStyle(
                  color: senderColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(12),
              ),
              border: Border.all(color: borderColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer(CommsController commsCtrl) {
    final activeIds = commsCtrl.activeBleDeviceIds;
    final isBleTab = _tabController.index == 1;
    final disableComposer = isBleTab && activeIds.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              enabled: !disableComposer,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: disableComposer ? 'No active secure channel' : 'Enter transmission...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.surfaceHigh.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.bleGreen),
                ),
              ),
              onSubmitted: (_) => _sendMessage(commsCtrl),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.bleGreen),
            onPressed: disableComposer ? null : () => _sendMessage(commsCtrl),
          ),
        ],
      ),
    );
  }

  void _sendMessage(CommsController commsCtrl) {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    if (_tabController.index == 0) {
      // LAN
      commsCtrl.sendLanMessage(text);
    } else {
      // BLE
      if (_selectedBleDeviceId != null) {
        commsCtrl.sendBleMessage(_selectedBleDeviceId!, _selectedBleDeviceId!, text);
      }
    }

    _msgController.clear();
    _scrollToBottom();
  }

  void _showCodenameDialog(BuildContext context, CommsController commsCtrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text(
          'SET CODENAME',
          style: TextStyle(color: AppColors.bleGreen, letterSpacing: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your codename identifies your node on the network. Use a secure pseudonym.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codenameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'CODENAME',
                labelStyle: TextStyle(color: AppColors.bleGreen),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textMuted),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.bleGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.bleGreen),
            child: const Text('UPDATE', style: TextStyle(color: AppColors.background)),
            onPressed: () {
              commsCtrl.setCodename(_codenameController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
