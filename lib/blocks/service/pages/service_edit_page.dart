import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:block_app/core/network/crypto/crypto_util.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../features/settings/services/api_keys_manager.dart';
import '../utils/service_decryptor.dart';


/// 服务块（Service）的编辑与创建页面。
///
/// 负责提供用户界面，用于输入或修改服务的核心信息，包括：
/// - 标题 (title)
/// - 官网/网址 (website)
/// - 简介 (intro)
/// - 动态的账户信息列表 (account)，包含多组键值对。
class ServiceEditPage extends StatefulWidget {
  const ServiceEditPage({super.key, this.block});

  final BlockModel? block;
  bool get isEditing => block != null;

  @override
  State<ServiceEditPage> createState() => _ServiceEditPageState();
}

class AccountField {
  AccountField({required this.key, required this.value});
  String key;
  String value;
}

class _ServiceEditPageState extends State<ServiceEditPage> with BlockEditMixin {
  static const String _serviceModelId = '81b0bc8db4f678300d199f5b34729282';

  late final TextEditingController _titleController;
  late final TextEditingController _websiteController;
  late final TextEditingController _introController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _websiteFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();

  late List<AccountField> _accountFields;

  // 加密相关
  bool _enableEncryption = false;
  String? _selectedKeyBid;
  final TextEditingController _publicController = TextEditingController();
  List<Map<String, dynamic>> _availableKeys = [];

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: _serviceModelId,
      pageTitle: '服务',
      buildFields: _buildFields,
      validateData: _validateData,
      prepareSubmitData: _prepareSubmitData,
      isEditing: widget.isEditing,
    );
    
    if (widget.block != null) {
      initBasicBlock(widget.block!);
    }
    
    initControllers();
    _loadAvailableKeys();
  }

  void initControllers() {
    final block = widget.block;
    
    // Default initialization
    _titleController = TextEditingController();
    _websiteController = TextEditingController();
    _introController = TextEditingController();
    _accountFields = <AccountField>[];

    if (block != null) {
      if (ServiceDecryptor.isEncrypted(block)) {
         _enableEncryption = true;
         _publicController.text = block.maybeString('public') ?? '';
         _decryptAndPopulate(block);
      } else {
         _titleController.text = block.maybeString('name') ?? '';
         _websiteController.text = block.maybeString('website') ?? '';
         _introController.text = block.maybeString('intro') ?? '';
         _accountFields = _parseAccountFields(block);
      }
    }
  }

  Future<void> _decryptAndPopulate(BlockModel block) async {
      // Ensure keys are loaded first to avoid Dropdown crash
      if (_availableKeys.isEmpty) {
         final keys = await ApiKeysManager.getApiKeys();
         if (mounted) {
           setState(() => _availableKeys = keys);
         }
      }

      final result = await ServiceDecryptor.tryDecrypt(block);
      if (!mounted) return;
      
      if (result != null) {
        setState(() {
          _selectedKeyBid = result.keyBid;
          _titleController.text = result.data['name'] as String? ?? '';
          _websiteController.text = result.data['website'] as String? ?? '';
          _introController.text = result.data['intro'] as String? ?? '';
          
          final accountList = result.data['account'];
          if (accountList is List) {
            _accountFields = accountList
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    final key = (item['k'] ?? '').toString();
                    final value = (item['v'] ?? '').toString();
                    return AccountField(key: key, value: value);
                  }
                  return null;
                })
                .whereType<AccountField>()
                .toList();
          }
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法解密此服务，请检查密钥')),
        );
      }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    _titleController.dispose();
    _websiteController.dispose();
    _introController.dispose();
    _publicController.dispose();
    _titleFocusNode.dispose();
    _websiteFocusNode.dispose();
    _introFocusNode.dispose();
  }

  Future<void> _loadAvailableKeys() async {
    final keys = await ApiKeysManager.getApiKeys();
    if (mounted) {
      setState(() {
        _availableKeys = keys;
      });
    }
  }

  List<AccountField> _parseAccountFields(BlockModel? block) {
    if (block == null) return <AccountField>[];
    final accountList = block.list<dynamic>('account');
    return accountList
        .map((item) {
          if (item is Map<String, dynamic>) {
            final key = (item['k'] ?? '').toString();
            final value = (item['v'] ?? '').toString();
            return AccountField(key: key, value: value);
          }
          return null;
        })
        .whereType<AccountField>()
        .toList();
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      // 加密开关
      _buildEncryptionToggle(),
      const SizedBox(height: 22),
      
      // 如果开启加密，显示公开信息输入框
      if (_enableEncryption) ...[
        AppTextField(
          controller: _publicController,
          label: '公开信息',
          hintText: '输入对此加密服务的公开描述',
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 22),
        _buildKeySelector(),
        const SizedBox(height: 22),
      ],
      
      AppTextField(
        controller: _titleController,
        label: '标题',
        hintText: '输入服务名称',
        focusNode: _titleFocusNode,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 22),
      AppTextField(
        controller: _websiteController,
        label: '官网',
        hintText: '输入网址',
        focusNode: _websiteFocusNode,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 22),
      AppTextField(
        controller: _introController,
        label: '简介',
        hintText: '简单描述这个服务',
        minLines: 3,
        maxLines: 5,
        focusNode: _introFocusNode,
        textInputAction: TextInputAction.newline,
      ),
      const SizedBox(height: 28),
      _buildAccountSection(),
      const SizedBox(height: 120), // 底部间距，避免被悬浮按钮遮挡
    ];
  }

  bool _validateData() {
    final title = _titleController.text.trim();
    if (_enableEncryption && _selectedKeyBid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开启加密后必须选择一个密钥')),
      );
      return false;
    }
    return title.isNotEmpty;
  }

  Map<String, dynamic> _prepareSubmitData() {
    if (_enableEncryption) {
      return _prepareEncryptedData();
    } else {
      return _prepareNormalData();
    }
  }

  Map<String, dynamic> _prepareNormalData() {
    final title = _titleController.text.trim();
    final website = _websiteController.text.trim();
    final intro = _introController.text.trim();

    return {
      'name': title,
      'website': website,
      'intro': intro,
      'account': _buildAccountPayload(),
      'crypto': null,
      'public': null,
    };
  }

  Map<String, dynamic> _prepareEncryptedData() {
    try {
      // 1. 准备需要加密的数据
      final dataToEncrypt = {
        'name': _titleController.text.trim(),
        'website': _websiteController.text.trim(),
        'intro': _introController.text.trim(),
        'account': _buildAccountPayload(),
      };

      // 2. 生成随机密钥 (32 bytes = 256 bits)
      final dataKey = CryptoUtil.generateRandomKey(32);

      // 3. 加密数据
      final jsonData = json.encode(dataToEncrypt);
      final encryptedText = CryptoUtil.encryptAesGcm(
        Uint8List.fromList(utf8.encode(jsonData)),
        dataKey,
      );

      // 4. 使用选中的公钥加密数据密钥
      final selectedKey = _availableKeys.firstWhere(
        (k) => k['bid'] == _selectedKeyBid,
      );
      final publicKeyHex = selectedKey['key'] as String;
      final publicKeyBytes = CryptoUtil.hexToBytes(publicKeyHex);

      // 使用公钥加密数据密钥
      final encryptedDataKey = CryptoUtil.encryptAesGcm(dataKey, publicKeyBytes);

      // 5. 构建加密结构
      final public = _publicController.text.trim();
      return {
        'public': public,
        'crypto': {
          'algo': 'PPE-001',
          'keys': [
            {
              'bid': _selectedKeyBid,
              'key': encryptedDataKey,
            }
          ],
          'text': encryptedText,
        },
        'name': null,
        'website': null,
        'intro': null,
        'account': null,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加密失败: $e')),
      );
      rethrow;
    }
  }

  List<Map<String, String>> _buildAccountPayload() {
    final entries = <Map<String, String>>[];
    for (final field in _accountFields) {
      final key = field.key.trim();
      final value = field.value.trim();
      if (key.isEmpty && value.isEmpty) {
        continue;
      }
      entries.add({'k': key, 'v': value});
    }
    return entries;
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '账户信息',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
              onPressed: () => _handleAddAccountTap(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_accountFields.isEmpty)
          const Center(
            child: Text('暂无账户信息，点击右上角添加', style: TextStyle(color: Colors.white38)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _accountFields.length,
            itemBuilder: (context, index) {
              return _buildAccountFieldItem(index);
            },
          ),
      ],
    );
  }

  Future<void> _handleAddAccountTap() async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    final result = await showDialog<AccountField>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '添加账户信息',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: keyController,
                label: '字段名',
                hintText: '例如：账号',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                controller: valueController,
                label: '值',
                hintText: '请输入对应内容',
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white60),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final key = keyController.text.trim();
                final value = valueController.text.trim();
                if (key.isEmpty && value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请至少填写一个字段或对应的值')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(AccountField(key: key, value: value));
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _accountFields.add(result);
    });
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool autofocus = false,
  }) {
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
          autofocus: autofocus,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF232327),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountFieldItem(int index) {
    final field = _accountFields[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: _buildAccountTextField(
              initialValue: field.key,
              hint: '字段名',
              onChanged: (val) => field.key = val,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _buildAccountTextField(
              initialValue: field.value,
              hint: '值',
              onChanged: (val) => field.value = val,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                _accountFields.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTextField({
    required String initialValue,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF1C1C1F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildEncryptionToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: _enableEncryption ? Colors.greenAccent : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开启加密',
                  style: TextStyle(
                    color: _enableEncryption ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '加密后 website、title、intro、account 将被保护',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableEncryption,
            onChanged: (value) {
              setState(() {
                _enableEncryption = value;
                if (!value) {
                  _selectedKeyBid = null;
                }
              });
            },
            activeColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildKeySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择加密密钥',
          style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          child: _availableKeys.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '暂无可用密钥，请先在密钥管理中添加',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedKeyBid,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Text(
                        '请选择一个密钥',
                        style: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2C2C2F),
                    menuMaxHeight: 300,
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_drop_down, color: Colors.white54),
                    ),
                    items: _availableKeys.map((key) {
                      final bid = key['bid'] as String;
                      final name = key['name'] as String? ?? 'Unnamed Key';
                      return DropdownMenuItem<String>(
                        value: bid,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedKeyBid = value;
                      });
                    },
                  ),
                ),
        ),
      ],
    );
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
