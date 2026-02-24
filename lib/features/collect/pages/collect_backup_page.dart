import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/dialogs/app_dialog.dart';
import '../providers/collect_provider.dart';
import '../services/collect_backup_service.dart';
import '../../aggregation/providers/aggregation_provider.dart';

/// 应用数据备份页面
/// 
/// 提供收藏和聚集数据的统一导出和导入功能
class CollectBackupPage extends StatefulWidget {
  const CollectBackupPage({super.key});

  @override
  State<CollectBackupPage> createState() => _CollectBackupPageState();
}

class _CollectBackupPageState extends State<CollectBackupPage> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final collectProvider = context.watch<CollectProvider>();
    final aggregationProvider = context.watch<AggregationProvider>();
    final hasCollectData = collectProvider.entries.isNotEmpty || collectProvider.tags.isNotEmpty;
    final hasAggregationData = aggregationProvider.items.isNotEmpty;
    final hasData = hasCollectData || hasAggregationData;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '数据备份',
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
            // 数据概览
            _buildDataOverview(collectProvider, aggregationProvider),
            const SizedBox(height: 32),

            // 导出功能
            _buildSectionHeader('导出数据'),
            const SizedBox(height: 12),
            _buildExportSection(hasData),
            const SizedBox(height: 32),

            // 导入功能
            _buildSectionHeader('导入数据'),
            const SizedBox(height: 12),
            _buildImportSection(),
            const SizedBox(height: 32),

            // 使用说明
            _buildSectionHeader('使用说明'),
            const SizedBox(height: 12),
            _buildUsageInstructions(),
          ],
        ),
      ),
    );
  }

  /// 构建数据概览
  Widget _buildDataOverview(CollectProvider collectProvider, AggregationProvider aggregationProvider) {
    final tagCount = collectProvider.tags.length;
    final entryCount = collectProvider.entries.length;
    final itemCount = collectProvider.entries.fold<int>(0, (sum, entry) => sum + entry.items.length);
    final aggregationItemCount = aggregationProvider.items.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前数据概览',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // 收藏数据
          const Text(
            '收藏',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDataStat('标签', tagCount, Icons.label_outline),
              ),
              Expanded(
                child: _buildDataStat('分组', entryCount, Icons.folder_outlined),
              ),
              Expanded(
                child: _buildDataStat('条目', itemCount, Icons.bookmark_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 聚集数据
          const Text(
            '聚集',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDataStat('聚集项', aggregationItemCount, Icons.view_module_outlined),
              ),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建数据统计项
  Widget _buildDataStat(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 构建导出功能区域
  Widget _buildExportSection(bool hasData) {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.file_download_outlined,
          title: '导出到文件',
          subtitle: hasData ? '将应用数据保存为文件' : '暂无数据可导出',
          enabled: hasData && !_isExporting,
          loading: _isExporting,
          onTap: hasData ? _handleExportToFile : null,
        ),
      ],
    );
  }

  /// 构建导入功能区域
  Widget _buildImportSection() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.file_upload_outlined,
          title: '从文件导入',
          subtitle: '选择备份文件恢复应用数据',
          enabled: !_isImporting,
          loading: _isImporting,
          onTap: _handleImportFromFile,
        ),
      ],
    );
  }

  /// 构建操作卡片
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(enabled ? 0.04 : 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(enabled ? 0.08 : 0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(enabled ? 0.06 : 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loading
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
                    : Icon(
                        icon,
                        color: enabled ? Colors.white70 : Colors.white30,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white54,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(enabled ? 0.4 : 0.2),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled && !loading)
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

  /// 构建使用说明
  Widget _buildUsageInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能说明',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('导出功能可以选择保存路径，将应用数据保存为 JSON 文件'),
          _buildInstructionItem('导入时会自动合并数据，不会覆盖现有内容'),
          _buildInstructionItem('备份文件包含收藏和聚集的所有数据'),
          _buildInstructionItem('备份文件可以在不同设备间传输，方便数据迁移'),
          _buildInstructionItem('建议定期备份重要数据'),
        ],
      ),
    );
  }

  /// 构建说明项
  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分组标题
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

  /// 处理导出到文件
  Future<void> _handleExportToFile() async {
    setState(() => _isExporting = true);

    try {
      final collectProvider = context.read<CollectProvider>();
      final aggregationProvider = context.read<AggregationProvider>();
      final result = await CollectBackupService.exportAllDataWithDialog(
        collectProvider,
        aggregationProvider,
      );

      if (!mounted) return;

      if (result.cancelled) {
        // 用户取消，不显示任何提示
        return;
      }

      if (result.success && result.filePath != null) {
        _showSuccessDialog(
          title: '导出成功',
          message: '应用数据已保存到：\n\n${result.filePath!.split('/').last}',
        );
      } else {
        _showErrorDialog(result.error ?? '导出失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// 处理从文件导入
  Future<void> _handleImportFromFile() async {
    setState(() => _isImporting = true);

    try {
      final collectProvider = context.read<CollectProvider>();
      final aggregationProvider = context.read<AggregationProvider>();
      final result = await CollectBackupService.importAllData(
        collectProvider,
        aggregationProvider,
      );

      if (!mounted) return;

      if (result.cancelled) {
        // 用户取消，不显示任何提示
        return;
      }

      if (result.success) {
        if (result.hasImportedData) {
          final messages = <String>[];
          if (result.importedTags > 0) messages.add('• ${result.importedTags} 个标签');
          if (result.importedEntries > 0) messages.add('• ${result.importedEntries} 个分组');
          if (result.importedItems > 0) messages.add('• ${result.importedItems} 个条目');
          if (result.importedAggregationItems > 0) messages.add('• ${result.importedAggregationItems} 个聚集项');
          
          _showSuccessDialog(
            title: '导入成功',
            message: '已成功导入：\n${messages.join('\n')}',
          );
        } else {
          _showInfoDialog('导入完成，但没有新数据需要添加');
        }
      } else {
        _showErrorDialog(result.error ?? '导入失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// 显示成功对话框
  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示信息对话框
  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: '提示',
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: '错误',
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}