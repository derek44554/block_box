import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/time_formatter.dart';

/// 文档编辑/创建页面。
class DocumentEditPage extends StatefulWidget {
  const DocumentEditPage({super.key, this.block});

  final BlockModel? block;

  bool get isEditing => block != null;

  @override
  State<DocumentEditPage> createState() => _DocumentEditPageState();
}

class _DocumentEditPageState extends State<DocumentEditPage> with BlockEditMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _timeController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();
  bool _enableTime = false;

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: '93b133932057a254cc15d0f09c91ca98',
      pageTitle: '文档',
      buildFields: _buildFields,
      validateData: _validateData,
      prepareSubmitData: _prepareSubmitData,
      isEditing: widget.isEditing,
      getSubmitErrorMessage: _getSubmitErrorMessage,
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
      _contentController = TextEditingController(text: block.maybeString('content') ?? '');
      final addTime = block.maybeString('add_time');
      _timeController = TextEditingController(text: addTime ?? '');
      _enableTime = addTime != null && addTime.isNotEmpty;
    } else {
      _titleController = TextEditingController();
      _contentController = TextEditingController();
      _timeController = TextEditingController();
      _enableTime = false;
    }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    _titleController.dispose();
    _contentController.dispose();
    _timeController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _timeFocusNode.dispose();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      AppTextField(
        controller: _titleController,
        label: '标题',
        hintText: '输入文档标题',
        focusNode: _titleFocusNode,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 22),
      AppTextField(
        controller: _contentController,
        label: '正文',
        hintText: '输入文档内容...',
        focusNode: _contentFocusNode,
        minLines: 8,
        maxLines: null,
      ),
      const SizedBox(height: 22),
      _buildTimeToggle(),
      if (_enableTime) ...[
        const SizedBox(height: 16),
        _buildTimeField(),
      ],
    ];
  }

  bool _validateData() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    return title.isNotEmpty || content.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final time = _timeController.text.trim();

    final data = <String, dynamic>{
      'name': title,
      'content': content,
    };

    if (_enableTime && time.isNotEmpty) {
      data['add_time'] = time;
    }

    return data;
  }

  String? _getSubmitErrorMessage() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      return '标题和内容不能同时为空';
    }

    return super.getSubmitErrorMessage();
  }

  Widget _buildTimeToggle() {
    return Row(
      children: [
        Switch(
          value: _enableTime,
          onChanged: (value) {
            setState(() {
              _enableTime = value;
              if (value && _timeController.text.isEmpty) {
                _timeController.text = nowIso8601WithOffset();
              }
            });
          },
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withOpacity(0.3),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '保存时间',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return AppTextField(
      controller: _timeController,
      label: '时间',
      hintText: '例如：2024-03-14T15:59:48+08:00',
      focusNode: _timeFocusNode,
      textInputAction: TextInputAction.done,
      suffix: IconButton(
        onPressed: _handlePickDateTime,
        icon: const Icon(
          Icons.schedule_outlined,
          color: Colors.white60,
          size: 18,
        ),
      ),
    );
  }

  Future<void> _handlePickDateTime() async {
    FocusScope.of(context).unfocus();

    final initial = DateTime.tryParse(_timeController.text.trim()) ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('zh', 'CN'),
          delegates: GlobalMaterialLocalizations.delegates,
          child: Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Colors.white),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (time == null || !mounted) return;

    final composed = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _timeController.text = iso8601WithOffset(composed);
    });
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
