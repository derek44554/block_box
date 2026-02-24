import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../components/layout/recent_blocks_sheet.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/time_formatter.dart';


class RecordEditPage extends StatefulWidget {
  const RecordEditPage({super.key, this.block});

  final BlockModel? block;

  bool get isEditing => block != null;

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> with BlockEditMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _introController;
  late final TextEditingController _coverController;
  late final TextEditingController _addressController;
  late final TextEditingController _timeController;

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _introFocus = FocusNode();
  final FocusNode _coverFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _timeFocus = FocusNode();

  bool _preciseDate = false;
  bool _preciseTime = false;
  bool _timeRange = false;

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: 'a3dbfde11fdb0e35485c57d2fa03f0f4',
      pageTitle: '档案',
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
      _coverController = TextEditingController(text: _extractCoverBid(block) ?? '');
      _addressController = TextEditingController(text: block.maybeString('address') ?? '');
      _timeController = TextEditingController(text: block.maybeString('add_time') ?? '');
      _preciseDate = block.maybeBool('precise_date') ?? false;
      _preciseTime = block.maybeBool('precise_time') ?? false;
      _timeRange = block.maybeBool('time_range') ?? false;
    } else {
      _titleController = TextEditingController();
      _introController = TextEditingController();
      _coverController = TextEditingController();
      _addressController = TextEditingController();
      _timeController = TextEditingController();
      _preciseDate = false;
      _preciseTime = false;
      _timeRange = false;
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
    _coverController.dispose();
    _addressController.dispose();
    _timeController.dispose();
    _titleFocus.dispose();
    _introFocus.dispose();
    _coverFocus.dispose();
    _addressFocus.dispose();
    _timeFocus.dispose();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      _buildHeader(),
      const SizedBox(height: 28),
      AppTextField(
        label: '标题',
        controller: _titleController,
        hintText: '输入档案标题',
        focusNode: _titleFocus,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 22),
      _buildCoverField(),
      const SizedBox(height: 22),
      AppTextField(
        label: '简介',
        controller: _introController,
        hintText: '描述档案内容、背景或说明',
        focusNode: _introFocus,
        minLines: 4,
        maxLines: 10,
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '地点（可选）',
        controller: _addressController,
        hintText: '例如：上海市 静安区',
        focusNode: _addressFocus,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '时间（ISO8601）',
        controller: _timeController,
        hintText: '例如：2024-05-10T14:20:00+08:00',
        focusNode: _timeFocus,
        textInputAction: TextInputAction.done,
        suffix: IconButton(
          onPressed: _handlePickDateTime,
          icon: const Icon(
            Icons.schedule_outlined,
            color: Colors.white60,
            size: 18,
          ),
        ),
      ),
      const SizedBox(height: 22),
      _buildPrecisionSelectors(),
    ];
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 0.8,
            ),
          ),
          child: Text(
            widget.isEditing ? '编辑档案' : '新建档案',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverField() {
    return AppTextField(
      label: '封面图片 BID',
      controller: _coverController,
      hintText: '输入图片 Block 的 BID，或从最近使用中选择',
      focusNode: _coverFocus,
      textInputAction: TextInputAction.next,
      suffix: IconButton(
        onPressed: _handleSelectCoverFromRecent,
        icon: const Icon(
          Icons.collections_outlined,
          color: Colors.white60,
          size: 18,
        ),
        tooltip: '从最近创建的 Block 选择',
      ),
    );
  }

  Widget _buildPrecisionSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '时间精度选项',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPrecisionChip(
              label: '精准日期',
              value: _preciseDate,
              onChanged: (value) => setState(() => _preciseDate = value),
            ),
            _buildPrecisionChip(
              label: '精准时间',
              value: _preciseTime,
              onChanged: (value) => setState(() => _preciseTime = value),
            ),
            _buildPrecisionChip(
              label: '范围时间',
              value: _timeRange,
              onChanged: (value) => setState(() => _timeRange = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrecisionChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? Colors.white.withOpacity(0.12)
              : const Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? Colors.white70 : Colors.white.withOpacity(0.1),
            width: 0.9,
          ),
          boxShadow: value
              ? const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: value ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white70,
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateData() {
    final title = _titleController.text.trim();
    return title.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final title = _titleController.text.trim();
    final intro = _introController.text.trim();
    final cover = _coverController.text.trim();
    final address = _addressController.text.trim();
    final time = _timeController.text.trim();

    final data = <String, dynamic>{
      'name': title,
      'intro': intro,
      'address': address,
      'precise_date': _preciseDate,
      'precise_time': _preciseTime,
      'time_range': _timeRange,
    };

    if (time.isEmpty) {
      data.remove('add_time');
    } else {
      data['add_time'] = time;
    }

    if (cover.isNotEmpty) {
      data['cover_bid'] = cover;
    }

    return data;
  }

  Future<void> _handlePickDateTime() async {
    FocusScope.of(context).unfocus();

    final initial =
        DateTime.tryParse(_timeController.text.trim()) ?? DateTime.now();

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

  Future<void> _handleSelectCoverFromRecent() async {
    FocusScope.of(context).unfocus();
    final result = await RecentBlocksSheet.show(context);
    if (!mounted || result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _coverController.text = trimmed;
    });
  }

  String? _extractCoverBid(BlockModel block) {
    return block.maybeString('cover_bid') ?? block.maybeString('coverBid');
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
