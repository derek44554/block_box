import 'package:flutter/material.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';

/// 集合块编辑页面，可用于创建或修改集合。
class SetEditPage extends StatefulWidget {
  const SetEditPage({super.key, this.block});

  final BlockModel? block;

  bool get isEditing => block != null;

  @override
  State<SetEditPage> createState() => _SetEditPageState();
}

class _SetEditPageState extends State<SetEditPage> with BlockEditMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _introController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: '1635e536a5a331a283f9da56b7b51774',
      pageTitle: '集合',
      buildFields: _buildFields,
      validateData: _validateData,
      prepareSubmitData: _prepareSubmitData,
      isEditing: widget.isEditing,
    );
    if (widget.block != null) {
      initBasicBlock(widget.block!);
    }
    initControllers();
  }

  void initControllers() {
    final block = widget.block;
    if (block != null) {
      _titleController = TextEditingController(text: block.maybeString('name') ?? '');
      _introController = TextEditingController(text: block.maybeString('intro') ?? '');
    } else {
      _titleController = TextEditingController();
      _introController = TextEditingController();
    }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    _titleController.dispose();
    _introController.dispose();
    _titleFocusNode.dispose();
    _introFocusNode.dispose();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      AppTextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        label: '标题',
        hintText: '输入集合标题',
      ),
      const SizedBox(height: 18),
      AppTextField(
        controller: _introController,
        focusNode: _introFocusNode,
        label: '简介',
        hintText: '描述集合的用途或内容...',
        minLines: 4,
        maxLines: 8,
      ),
      const SizedBox(height: 40),
    ];
  }

  bool _validateData() {
    final title = _titleController.text.trim();
    return title.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final title = _titleController.text.trim();
    final intro = _introController.text.trim();

    return {
      'name': title,
      'intro': intro,
    };
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
