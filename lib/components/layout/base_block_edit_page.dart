import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../state/connection_provider.dart';
import '../../state/block_provider.dart';
import 'block_basic_editor_page.dart';

/// 编辑页面配置类
class EditPageConfig {
  final String modelId;
  final String pageTitle;
  final List<Widget> Function(BuildContext context) buildFields;
  final bool Function() validateData;
  final Map<String, dynamic> Function() prepareSubmitData;
  final bool isEditing;
  final String? Function()? getSubmitErrorMessage;
  final void Function(BlockModel resultBlock)? onSubmitSuccess;

  const EditPageConfig({
    required this.modelId,
    required this.pageTitle,
    required this.buildFields,
    required this.validateData,
    required this.prepareSubmitData,
    required this.isEditing,
    this.getSubmitErrorMessage,
    this.onSubmitSuccess,
  });
}

/// 块编辑页面的mixin
mixin BlockEditMixin<T extends StatefulWidget> on State<T> {
  late final EditPageConfig config;
  bool _isSubmitting = false;
  BlockModel? _basicBlock;

  /// 是否正在提交
  bool get isSubmitting => _isSubmitting;

  /// 是否正在编辑
  bool get isEditing => config.isEditing;

  /// 获取是否选择了节点
  bool get hasSelectedNode {
    final nodeBid = _basicBlock?.maybeString('node_bid');
    return nodeBid != null && nodeBid.length >= 10;
  }

  /// 构建基础块数据
  BlockModel get effectiveBasicBlock {
    _basicBlock ??= _createInitialBlock();
    return _basicBlock!;
  }

  BlockModel _createInitialBlock() {
    final data = <String, dynamic>{
      'bid': '',
      'tag': <String>[],
      'link': <String>[],
      'permission_level': 0,
      'model': config.modelId,
    };
    return BlockModel(data: data);
  }

  /// 初始化基础块数据 (用于initState)
  void initBasicBlock(BlockModel block) {
    _basicBlock = BlockModel(data: Map<String, dynamic>.from(block.data));
  }

  /// 更新基础块数据
  void updateBasicBlock(BlockModel block) {
    setState(() => _basicBlock = BlockModel(data: Map<String, dynamic>.from(block.data)));
  }

  /// 处理提交
  Future<void> handleSubmit() async {
    FocusScope.of(context).unfocus();

    final errorMessage = config.getSubmitErrorMessage?.call() ??
        (getSubmitErrorMessage() ?? defaultGetSubmitErrorMessage());
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    if (!config.validateData()) {
      return;
    }

    final base = Map<String, dynamic>.from(effectiveBasicBlock.data);
    final rawNodeBid = base['node_bid']?.toString().trim() ?? '';
    final String? nodeBid = rawNodeBid.isNotEmpty ? rawNodeBid : null;

    final bid = (base['bid']?.toString().trim().isNotEmpty ?? false)
        ? base['bid'].toString()
        : BlockBasicEditorPage.generateBidSafe(context, nodeBid: nodeBid);

    final submitData = config.prepareSubmitData();
    base.addAll(submitData);
    base.removeWhere((key, value) => value == null);
    base['bid'] = bid;
    base['model'] = config.modelId;

    // 标准化tag和link
    base['tag'] = base['tag'] is List
        ? List<String>.from((base['tag'] as List).whereType<String>())
        : <String>[];
    base['link'] = base['link'] is List
        ? List<String>.from((base['link'] as List).whereType<String>())
        : <String>[];
    base['permission_level'] = base['permission_level'] is int 
        ? base['permission_level'] 
        : (int.tryParse(base['permission_level']?.toString() ?? '0') ?? 0);

    // 移除不需要保存的节点相关字段
    base.remove('node_name');
    base.remove('node_bid');
    base.remove('node_connection');
    base.remove('node_connection_address');

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      await api.saveBlock(data: base, receiverBid: nodeBid);

      if (!mounted) return;

      final resultBlock = BlockModel(data: base);
      setState(() {
        _isSubmitting = false;
        _basicBlock = resultBlock;
      });

      (config.onSubmitSuccess ?? onSubmitSuccess).call(resultBlock);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$error')),
      );
    }
  }

  /// 处理打开基础编辑器
  Future<void> handleOpenBasicEditor() async {
    final result = await BlockBasicEditorPage.show(
      context,
      initialData: effectiveBasicBlock,
      allowNodeSelection: !isEditing,
    );
    if (result == null || !mounted) return;
    updateBasicBlock(result);
  }

  /// 构建浮动按钮
  Widget buildFloatingButtons() {
    final canSubmit = isEditing || hasSelectedNode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppFloatingActionButton(
          label: '基本',
          icon: Icons.settings_outlined,
          onTap: handleOpenBasicEditor,
        ),
        const SizedBox(height: 12),
        AppFloatingActionButton(
          label: isEditing ? '保存' : '创建',
          icon: isEditing ? Icons.save_outlined : Icons.check,
          onTap: (!canSubmit || _isSubmitting) ? null : handleSubmit,
          isLoading: _isSubmitting,
          isDisabled: !canSubmit && !isEditing,
        ),
      ],
    );
  }

  /// 默认的提交错误信息获取
  String? defaultGetSubmitErrorMessage() {
    if (!isEditing && !hasSelectedNode) {
      return '请先在基础设置中选择节点';
    }
    return null;
  }

  /// 默认的提交成功处理
  void onSubmitSuccess(BlockModel resultBlock) {
    // Update BlockProvider to notify all listening pages
    try {
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(resultBlock);
      debugPrint('BlockEditMixin: Updated BlockProvider after save with BID: ${resultBlock.bid}');
    } catch (e) {
      debugPrint('BlockEditMixin: Error updating BlockProvider: $e');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEditing ? '${config.pageTitle}已更新' : '${config.pageTitle}创建成功')),
    );

    if (isEditing) {
      Navigator.of(context).pop(resultBlock);
    } else {
      AppRouter.openBlockDetailPage(context, resultBlock, replace: true);
    }
  }

  /// 获取提交错误信息（可重写）
  String? getSubmitErrorMessage() => null;
}

/// 统一的文本输入组件
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.focusNode,
    this.textInputAction,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int minLines;
  final int? maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            color: Colors.white,
            fontSize: (maxLines ?? 1) > 1 ? 14 : 15,
            height: (maxLines ?? 1) > 1 ? 1.6 : 1.0,
            fontWeight: (maxLines ?? 1) == 1 ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1C1C1F),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: (maxLines ?? 1) > 1 ? 18 : 16,
            ),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.28)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 统一的浮动操作按钮组件
class AppFloatingActionButton extends StatelessWidget {
  const AppFloatingActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null && !isLoading && !isDisabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDisabled
            ? const Color(0xFF374151).withOpacity(0.4)
            : const Color(0xFF4B5563),
        border: Border.all(
          color: isDisabled
              ? const Color(0xFF374151).withOpacity(0.3)
              : const Color(0xFF6B7280).withOpacity(0.5),
          width: 1.0
        ),
        boxShadow: isDisabled ? null : const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                else
                  Icon(icon, size: 16, color: isEnabled ? Colors.white : Colors.white38),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isEnabled ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 构建标准编辑页面布局
Widget buildEditPage({
  required BuildContext context,
  required List<Widget> fields,
  required VoidCallback onBasicPressed,
  required VoidCallback onSubmitPressed,
  required bool isSubmitting,
  required bool isEditing,
  bool isDisabled = false,
  String pageTitle = '块',
}) {
  final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

  return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isKeyboardVisible ? null : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppFloatingActionButton(
            label: '基本',
            icon: Icons.settings_outlined,
            onTap: onBasicPressed,
          ),
          const SizedBox(height: 12),
          AppFloatingActionButton(
            label: isEditing ? '保存' : '创建',
            icon: isEditing ? Icons.save_outlined : Icons.check,
            onTap: onSubmitPressed,
            isLoading: isSubmitting,
            isDisabled: isDisabled,
          ),
        ],
      ),
    ),
  );
}
