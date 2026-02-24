import 'package:flutter/material.dart';
import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../common/block_type_ids.dart';

/// 信条编辑页面
///
/// 用于创建和编辑信条类型的Block
class CreedEditPage extends StatefulWidget {
  const CreedEditPage({super.key, required this.block});

  final BlockModel block;

  bool get isEditing => block.maybeString('bid') != null;

  @override
  State<CreedEditPage> createState() => _CreedEditPageState();
}

class _CreedEditPageState extends State<CreedEditPage> with BlockEditMixin {
  late final TextEditingController _contentController;
  late final TextEditingController _introController;
  final FocusNode _contentFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: BlockTypeIds.creed,
      pageTitle: '信条',
      buildFields: _buildFields,
      validateData: _validateData,
      prepareSubmitData: _prepareSubmitData,
      isEditing: widget.isEditing,
      getSubmitErrorMessage: _getSubmitErrorMessage,
    );
    if (widget.isEditing) {
      initBasicBlock(widget.block);
    }
    initControllers();
  }

  void initControllers() {
    _contentController = TextEditingController(
      text: widget.block.maybeString('content') ?? '',
    );
    _introController = TextEditingController(
      text: widget.block.maybeString('intro') ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _introController.dispose();
    _contentFocusNode.dispose();
    _introFocusNode.dispose();
    super.dispose();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      // 页面标题
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D4A22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.format_quote,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            widget.isEditing ? '编辑信条' : '创建信条',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      
      // 信条内容字段
      AppTextField(
        controller: _contentController,
        label: '信条内容 *',
        hintText: '请输入信条内容...',
        focusNode: _contentFocusNode,
        textInputAction: TextInputAction.next,
        minLines: 6,
        maxLines: null,
      ),
      const SizedBox(height: 8),
      const Text(
        '信条的核心内容，将在卡片和详情页中显示',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 24),
      
      // 简介字段
      AppTextField(
        controller: _introController,
        label: '简介',
        hintText: '请输入简介（可选）...',
        focusNode: _introFocusNode,
        textInputAction: TextInputAction.done,
        minLines: 4,
        maxLines: null,
      ),
      const SizedBox(height: 8),
      const Text(
        '对信条的补充说明，仅在详情页中显示',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    ];
  }

  bool _validateData() {
    final content = _contentController.text.trim();
    return content.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final content = _contentController.text.trim();
    final intro = _introController.text.trim();

    final data = <String, dynamic>{
      'content': content,
    };

    if (intro.isNotEmpty) {
      data['intro'] = intro;
    }

    return data;
  }

  String? _getSubmitErrorMessage() {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      return '请输入信条内容';
    }

    return super.getSubmitErrorMessage();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = config.isEditing || hasSelectedNode;
    return buildEditPage(
      context: context,
      fields: config.buildFields(context),
      onBasicPressed: handleOpenBasicEditor,
      onSubmitPressed: () {
        if (!canSubmit || isSubmitting) return;
        handleSubmit();
      },
      isSubmitting: isSubmitting,
      isEditing: config.isEditing,
      isDisabled: !canSubmit && !config.isEditing,
      pageTitle: config.pageTitle,
    );
  }
}