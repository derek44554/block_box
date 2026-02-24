import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../blocks/service/utils/service_decryptor.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';

class RawDataPage extends StatefulWidget {
  const RawDataPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<RawDataPage> createState() => _RawDataPageState();
}

class _RawDataPageState extends State<RawDataPage> {
  Map<String, dynamic>? _decryptedData;
  bool _isDecrypting = false;
  bool _isEncrypted = false;

  @override
  void initState() {
    super.initState();
    _checkAndDecrypt();
  }

  Future<void> _checkAndDecrypt() async {
    _isEncrypted = ServiceDecryptor.isEncrypted(widget.block);
    if (!_isEncrypted) return;

    setState(() => _isDecrypting = true);

    final result = await ServiceDecryptor.tryDecrypt(widget.block);

    if (mounted) {
      setState(() {
        _decryptedData = result?.data;
        _isDecrypting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedBid = formatBid(widget.block.maybeString('bid') ?? '');
    final rawJsonCompact = jsonEncode(widget.block.data);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(widget.block.data);

    debugPrint('[RawDataPage] block data: $rawJsonCompact');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '原始数据',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            if (formattedBid.isNotEmpty)
              Text(
                formattedBid,
                style: const TextStyle(fontSize: 12, color: Colors.white54, letterSpacing: 0.6),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: '复制原始数据',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawJsonCompact));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('原始数据已复制'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isEncrypted && _decryptedData != null
            ? _buildEncryptedDataScrollView(prettyJson)
            : _buildSingleDataScrollView(prettyJson),
      ),
    );
  }

  Widget _buildSingleDataScrollView(String jsonData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: _buildDataCard(
        title: '原始数据',
        icon: Icons.dataset_outlined,
        jsonData: jsonData,
        isDecrypted: false,
      ),
    );
  }

  Widget _buildEncryptedDataScrollView(String encryptedJson) {
    final decryptedJson = const JsonEncoder.withIndent('  ').convert(_decryptedData!);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        children: [
          _buildDataCard(
            title: '原始数据（加密）',
            icon: Icons.lock_outline,
            jsonData: encryptedJson,
            isDecrypted: false,
          ),
          const SizedBox(height: 20),
          _buildDataCard(
            title: '解密后数据',
            icon: Icons.lock_open_outlined,
            jsonData: decryptedJson,
            isDecrypted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required String jsonData,
    required bool isDecrypted,
  }) {
    final accentColor = isDecrypted ? Colors.greenAccent : Colors.white70;
    final borderColor = isDecrypted 
        ? Colors.greenAccent.withValues(alpha: 0.3) 
        : Colors.white.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDecrypted 
                  ? Colors.greenAccent.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF1A1A1A), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 12),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                if (_isDecrypting && isDecrypted) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.content_copy, size: 16, color: accentColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '复制此数据',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${title}已复制'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: SelectableText(
              jsonData,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                height: 1.55,
                color: Color(0xFFE6E6E6),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
