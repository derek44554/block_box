import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaml/yaml.dart';

import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../../core/routing/app_router.dart';
import '../../../state/block_provider.dart';
import '../../../state/connection_provider.dart';

/// Block 导入页面
///
/// 支持一次选择多个 YAML Block 文件，预检查格式和服务器已有状态后再写入。
class BlockImportPage extends StatefulWidget {
  const BlockImportPage({super.key});

  @override
  State<BlockImportPage> createState() => _BlockImportPageState();
}

class _BlockImportPageState extends State<BlockImportPage> {
  final List<_ImportBlockItem> _items = [];
  bool _isPicking = false;
  bool _isImporting = false;

  int get _existingCount =>
      _items.where((item) => item.status == _ImportBlockStatus.existing).length;

  int get _invalidCount =>
      _items.where((item) => item.status == _ImportBlockStatus.invalid).length;

  int get _normalCount =>
      _items.where((item) => item.status != _ImportBlockStatus.invalid).length;

  int get _importableCount => _existingCount + _normalCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Block 导入',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildPickCard(),
            const SizedBox(height: 18),
            _buildImportSummary(),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildImportButton(),
              const SizedBox(height: 22),
              _buildSectionHeader('本次选中的 Block'),
              const SizedBox(height: 10),
              for (final item in _items) ...[
                _buildBlockItem(item),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isPicking || _isImporting ? null : _handlePickBlocks,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isPicking
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.upload_file_outlined,
                        color: Colors.white70,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPicking ? '正在读取...' : '选择 Block 文件',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可一次选择多个 .yml 或 .yaml 文件',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStat('已选择', _items.length, Colors.white70),
          ),
          Expanded(
            child: _buildSummaryStat('已存在', _existingCount, Colors.amber),
          ),
          Expanded(
            child: _buildSummaryStat('格式错误', _invalidCount, Colors.redAccent),
          ),
          Expanded(
            child: _buildSummaryStat('正常', _normalCount, Colors.greenAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    final enabled = _importableCount > 0 && !_isImporting && !_isPicking;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: enabled ? _handleImportBlocks : null,
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black54,
                ),
              )
            : const Icon(Icons.cloud_upload_outlined, size: 20),
        label: Text(_isImporting ? '导入中...' : '导入可用 Block'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withOpacity(0.12),
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildBlockItem(_ImportBlockItem item) {
    final statusColor = _statusColor(item.status);
    final title = item.block?.maybeString('name') ?? item.bid ?? item.fileName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_statusIcon(item.status), color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.bid ?? item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusChip(item),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSmallButton(
                label: '删除',
                icon: Icons.delete_outline,
                onPressed: () => _removeItem(item),
              ),
              if (item.block != null)
                _buildSmallButton(
                  label: '查看详情',
                  icon: Icons.visibility_outlined,
                  onPressed: () => _openBlockDetail(item.block!),
                ),
              if (item.existingBlock != null)
                _buildSmallButton(
                  label: '查看原 Block',
                  icon: Icons.manage_search_outlined,
                  onPressed: () => _openBlockDetail(item.existingBlock!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(_ImportBlockItem item) {
    final color = _statusColor(item.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        _statusLabel(item.status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isPicking || _isImporting ? null : onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withOpacity(0.14)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Future<void> _handlePickBlocks() async {
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择 Block 文件',
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['yml', 'yaml'],
      );

      if (result == null) {
        return;
      }

      final nextItems = <_ImportBlockItem>[];
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.isEmpty) {
          nextItems.add(
            _ImportBlockItem.invalid(
              fileName: file.name,
              errorMessage: '无法读取文件路径',
            ),
          );
          continue;
        }
        nextItems.add(await _readBlockFile(path, file.name));
      }

      await _checkExistingBlocks(nextItems);

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(nextItems);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<_ImportBlockItem> _readBlockFile(String path, String fileName) async {
    try {
      final content = await File(path).readAsString();
      final parsed = loadYaml(content);
      final normalized = _normalizeYaml(parsed);
      if (normalized is! Map<String, dynamic>) {
        return _ImportBlockItem.invalid(
          fileName: fileName,
          errorMessage: '文件内容不是 Block 对象',
        );
      }

      final bid = normalized['bid'];
      if (bid is! String || bid.trim().isEmpty) {
        return _ImportBlockItem.invalid(
          fileName: fileName,
          errorMessage: '缺少有效的 bid 字段',
        );
      }

      final block = BlockModel(data: normalized);
      return _ImportBlockItem.valid(fileName: fileName, block: block);
    } catch (error) {
      return _ImportBlockItem.invalid(
        fileName: fileName,
        errorMessage: '解析失败：$error',
      );
    }
  }

  Future<void> _checkExistingBlocks(List<_ImportBlockItem> items) async {
    final provider = context.read<ConnectionProvider>();
    final api = BlockApi(connectionProvider: provider);

    for (final item in items) {
      final bid = item.bid;
      if (bid == null || item.status == _ImportBlockStatus.invalid) {
        continue;
      }

      try {
        final response = await api.getBlock(bid: bid);
        final data = response['data'];
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          item
            ..status = _ImportBlockStatus.existing
            ..existingBlock = BlockModel(data: data);
        }
      } catch (_) {
        item.status = _ImportBlockStatus.normal;
      }
    }
  }

  Future<void> _handleImportBlocks() async {
    final importableItems = _items
        .where((item) => item.status != _ImportBlockStatus.invalid)
        .where((item) => item.block != null)
        .toList();

    if (importableItems.isEmpty) {
      return;
    }

    setState(() => _isImporting = true);

    var successCount = 0;
    try {
      final connectionProvider = context.read<ConnectionProvider>();
      final blockProvider = context.read<BlockProvider>();
      final api = BlockApi(connectionProvider: connectionProvider);

      for (final item in importableItems) {
        final block = item.block!;
        await api.saveBlock(data: block.data);
        blockProvider.updateBlock(block);
        successCount += 1;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 $successCount 个 Block')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：已导入 $successCount 个，错误：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _removeItem(_ImportBlockItem item) {
    setState(() => _items.remove(item));
  }

  Future<void> _openBlockDetail(BlockModel block) async {
    await AppRouter.openBlockDetailPage(context, block);
  }

  dynamic _normalizeYaml(dynamic value) {
    if (value is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (entry) =>
              MapEntry(entry.key.toString(), _normalizeYaml(entry.value)),
        ),
      );
    }
    if (value is YamlList) {
      return value.map(_normalizeYaml).toList();
    }
    return value;
  }

  Color _statusColor(_ImportBlockStatus status) {
    switch (status) {
      case _ImportBlockStatus.invalid:
        return Colors.redAccent;
      case _ImportBlockStatus.existing:
        return Colors.amber;
      case _ImportBlockStatus.normal:
        return Colors.greenAccent;
    }
  }

  IconData _statusIcon(_ImportBlockStatus status) {
    switch (status) {
      case _ImportBlockStatus.invalid:
        return Icons.error_outline;
      case _ImportBlockStatus.existing:
        return Icons.warning_amber_outlined;
      case _ImportBlockStatus.normal:
        return Icons.check_circle_outline;
    }
  }

  String _statusLabel(_ImportBlockStatus status) {
    switch (status) {
      case _ImportBlockStatus.invalid:
        return '错误';
      case _ImportBlockStatus.existing:
        return '已存在';
      case _ImportBlockStatus.normal:
        return '正常';
    }
  }
}

enum _ImportBlockStatus { invalid, existing, normal }

class _ImportBlockItem {
  _ImportBlockItem({
    required this.fileName,
    required this.status,
    this.block,
    this.existingBlock,
    this.errorMessage,
  });

  factory _ImportBlockItem.valid({
    required String fileName,
    required BlockModel block,
  }) {
    return _ImportBlockItem(
      fileName: fileName,
      status: _ImportBlockStatus.normal,
      block: block,
    );
  }

  factory _ImportBlockItem.invalid({
    required String fileName,
    required String errorMessage,
  }) {
    return _ImportBlockItem(
      fileName: fileName,
      status: _ImportBlockStatus.invalid,
      errorMessage: errorMessage,
    );
  }

  final String fileName;
  _ImportBlockStatus status;
  BlockModel? block;
  BlockModel? existingBlock;
  String? errorMessage;

  String? get bid => block?.maybeString('bid');
}
