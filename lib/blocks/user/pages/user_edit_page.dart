import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../components/layout/recent_blocks_sheet.dart';
import '../../../core/models/block_model.dart';


/// 用户块（User）的编辑与创建页面。
///
/// 负责维护用户的基本身份信息，包括存活状态、类型、简介、
/// 描述数据、姓名、起源时间、联系方式以及头像等字段。
class UserEditPage extends StatefulWidget {
  const UserEditPage({super.key, this.block});

  final BlockModel? block;

  bool get isEditing => block != null;

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> with BlockEditMixin {
  static const Map<String, String> _typeLabels = {
    'humanity': '人类',
    'animal': '动物',
    'ai': '人工智能',
    'company': '公司',
    'organize': '组织',
  };

  static const Map<String, String> _genderLabels = {
    'male': '男性',
    'female': '女性',
    'other': '其他',
    'unknown': '未知',
  };

  late final TextEditingController _nameController;
  late final TextEditingController _introController;
  late final TextEditingController _introDataController;
  late final TextEditingController _originController;
  late final TextEditingController _avatarController;
  late final TextEditingController _contactDataController;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();
  final FocusNode _introDataFocusNode = FocusNode();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _avatarFocusNode = FocusNode();
  final FocusNode _contactDataFocusNode = FocusNode();

  bool _survive = true;
  String _selectedType = 'humanity';
  String _selectedGender = 'unknown';

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: '71b6eb41f026842b3df6b126dfe11c29',
      pageTitle: '用户',
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
      _nameController = TextEditingController(text: block.maybeString('name') ?? '');
      _introController = TextEditingController(text: block.maybeString('intro') ?? '');
      _introDataController = TextEditingController(text: block.maybeString('intro_data') ?? '');
      _originController = TextEditingController(text: _normalizeOriginValue(block.maybeString('origin')));
      _avatarController = TextEditingController(text: block.maybeString('avatar_bid') ?? '');
      _contactDataController = TextEditingController(text: block.maybeString('contact_data') ?? '');

      _survive = block.maybeBool('survive') ?? true;
      final modelType = block.maybeString('type');
      if (modelType != null && _typeLabels.containsKey(modelType)) {
        _selectedType = modelType;
      }
      final gender = block.maybeString('gender');
      if (gender != null && _genderLabels.containsKey(gender)) {
        _selectedGender = gender;
      }
    } else {
      _nameController = TextEditingController();
      _introController = TextEditingController();
      _introDataController = TextEditingController();
      _originController = TextEditingController();
      _avatarController = TextEditingController();
      _contactDataController = TextEditingController();

      _survive = true;
      _selectedType = 'humanity';
      _selectedGender = 'unknown';
    }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    _nameController.dispose();
    _introController.dispose();
    _introDataController.dispose();
    _originController.dispose();
    _avatarController.dispose();
    _contactDataController.dispose();

    _nameFocusNode.dispose();
    _introFocusNode.dispose();
    _introDataFocusNode.dispose();
    _originFocusNode.dispose();
    _avatarFocusNode.dispose();
    _contactDataFocusNode.dispose();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      AppTextField(
        label: '姓名',
        controller: _nameController,
        hintText: '输入用户名称，例如：张三',
        focusNode: _nameFocusNode,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 22),
      _buildStatusAndTypeSection(),
      const SizedBox(height: 22),
      AppTextField(
        label: '起源 / 出生日期',
        controller: _originController,
        hintText: '例如：2022-04-11T09:30:10+08:00',
        focusNode: _originFocusNode,
        keyboardType: TextInputType.datetime,
        suffix: IconButton(
          icon: const Icon(
            Icons.calendar_today_outlined,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: _handlePickOrigin,
        ),
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '介绍',
        controller: _introController,
        hintText: '输入用户的简介说明',
        focusNode: _introFocusNode,
        minLines: 4,
        maxLines: 8,
        textInputAction: TextInputAction.newline,
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '描述性信息数据',
        controller: _introDataController,
        hintText: '以结构化方式补充描述，例如多段 YAML',
        focusNode: _introDataFocusNode,
        minLines: 4,
        maxLines: 12,
        textInputAction: TextInputAction.newline,
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '头像 Block BID',
        controller: _avatarController,
        hintText: '输入或从最近创建的 Block 中选择',
        focusNode: _avatarFocusNode,
        textInputAction: TextInputAction.done,
        suffix: IconButton(
          icon: const Icon(
            Icons.history_toggle_off_outlined,
            color: Colors.white70,
            size: 18,
          ),
          tooltip: '选择最近创建的 Block',
          onPressed: _handleSelectAvatarFromRecent,
        ),
      ),
      const SizedBox(height: 22),
      AppTextField(
        label: '联系方式',
        controller: _contactDataController,
        hintText: '以纯文本记录联系方式，例如电话、邮箱、社交账号等信息',
        focusNode: _contactDataFocusNode,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        minLines: 4,
        maxLines: 10,
      ),
      const SizedBox(height: 28),
    ];
  }

  Widget _buildStatusAndTypeSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '存活状态',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _survive,
                onChanged: (value) => setState(() => _survive = value),
                activeColor: Colors.white,
                activeTrackColor: Colors.white38,
                inactiveThumbColor: Colors.white30,
                inactiveTrackColor: Colors.white10,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '类型',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedType = value);
            },
            items: _typeLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      '${entry.value} (${entry.key})',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF232327),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: const Color(0xFF232327),
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 18),
          const Text(
            '性别',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _genderLabels.entries.map((entry) {
              final isActive = _selectedGender == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _selectedGender = entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.12)
                        : const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive
                          ? Colors.white70
                          : Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                    boxShadow: isActive
                        ? const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _validateData() {
    final name = _nameController.text.trim();
    return name.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final name = _nameController.text.trim();
    final intro = _introController.text.trim();
    final introData = _introDataController.text.trim();
    final originText = _originController.text.trim();
    final avatar = _avatarController.text.trim();
    final contactData = _contactDataController.text.trim();

    final origin = _normalizeOriginValue(originText);

    final data = <String, dynamic>{
      'survive': _survive,
      'type': _selectedType,
      'gender': _selectedGender,
      'intro': intro,
      'intro_data': introData,
      'name': name,
      'origin': origin,
    };

    data.remove('avatar_bid');
    data.remove('contact');
    data.remove('contact_data');

    if (contactData.isNotEmpty) {
      data['contact_data'] = contactData;
    }

    if (avatar.isNotEmpty) {
      data['avatar_bid'] = avatar;
    }

    return data;
  }

  String _normalizeOriginValue(String? origin) {
    if (origin == null) return '';
    final trimmed = origin.trim();
    if (trimmed.isEmpty) return '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return _formatDateOnly(parsed);
    }
    if (trimmed.length >= 10) {
      return trimmed.substring(0, 10);
    }
    return trimmed;
  }

  String _formatDateOnly(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _handlePickOrigin() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final currentText = _originController.text.trim();
    final initialDateTime = DateTime.tryParse(currentText) ?? now;

    final date = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: initialDateTime,
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
    setState(() {
      _originController.text = _formatDateOnly(date);
    });
  }

  Future<void> _handleSelectAvatarFromRecent() async {
    FocusScope.of(context).unfocus();
    final result = await RecentBlocksSheet.show(context);
    if (!mounted || result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _avatarController.text = trimmed;
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
