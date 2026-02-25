import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/sha3.dart';
import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';
import '../../../core/network/api/block_api.dart';
import '../../file/models/file_card_data.dart';
import '../../../utils/block_image_loader.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/utils/generators/bid_generator.dart';

/// 文章编辑页面
class ArticleEditPage extends StatefulWidget {
  const ArticleEditPage({super.key, this.block, this.traceNodeBid});

  final BlockModel? block;
  final String? traceNodeBid;

  bool get isEditing => block != null;

  @override
  State<ArticleEditPage> createState() => _ArticleEditPageState();
}

class _ArticleEditPageState extends State<ArticleEditPage> with BlockEditMixin {
  static const String _articleModelId = '52da1e115d0a764b43c90f6b43284aa9';

  late final TextEditingController _nameController;
  late final TextEditingController _introController;
  late final TextEditingController _coverController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();
  final FocusNode _coverFocusNode = FocusNode();

  BlockModel? _coverBlock;
  bool _isLoadingCover = false;
  DateTime? _addTime;

  // 文件上传相关
  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  bool _encryptFile = true;
  bool _isSubmitting = false;
  bool _updateContent = false; // 新增：是否更新内容的选项

  bool get _hasSelectedNode {
    final nodeBid = effectiveBasicBlock.maybeString('node_bid');
    return nodeBid != null && nodeBid.length >= 10;
  }

  @override
  void initState() {
    super.initState();

    // 初始化基础配置
    config = EditPageConfig(
      modelId: _articleModelId,
      pageTitle: '文章',
      buildFields: _buildFields,
      validateData: _validateData,
      prepareSubmitData: _prepareSubmitData,
      isEditing: widget.isEditing,
    );

    final block = widget.block;
    if (block != null) {
      initBasicBlock(block);
      _nameController = TextEditingController(
        text: block.maybeString('name') ?? '',
      );
      _introController = TextEditingController(
        text: block.maybeString('intro') ?? '',
      );
      _coverController = TextEditingController(
        text: block.maybeString('cover') ?? '',
      );
      _addTime = block.getDateTime('add_time');
      _loadCoverBlock();
    } else {
      _nameController = TextEditingController();
      _introController = TextEditingController();
      _coverController = TextEditingController();
      _addTime = DateTime.now(); // 创建时设置为当前时间
      
      final data = <String, dynamic>{
        'bid': '',
        'tag': <String>[],
        'link': <String>[],
        'permission_level': 0,
        'model': _articleModelId,
        'name': '',
        'intro': '',
        'cover': '',
        'add_time': _addTime!.toIso8601String(),
      };
      final traceNodeBid = widget.traceNodeBid?.trim();
      if (traceNodeBid != null && traceNodeBid.isNotEmpty) {
        data['node_bid'] = traceNodeBid;
      }
      initBasicBlock(BlockModel(data: data));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _coverController.dispose();
    _nameFocusNode.dispose();
    _introFocusNode.dispose();
    _coverFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCoverBlock() async {
    final coverBid = _coverController.text.trim();
    if (coverBid.isEmpty || !_isBidFormat(coverBid)) {
      setState(() {
        _coverBlock = null;
        _isLoadingCover = false;
      });
      return;
    }

    setState(() => _isLoadingCover = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: coverBid);

      final data = response['data'];
      if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
        final block = BlockModel(data: data);
        if (mounted) {
          setState(() {
            _coverBlock = block;
            _isLoadingCover = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _coverBlock = null;
            _isLoadingCover = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _coverBlock = null;
          _isLoadingCover = false;
        });
      }
    }
  }

  bool _isBidFormat(String text) {
    return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.isEditing || _hasSelectedNode;
    return buildEditPage(
      context: context,
      fields: config.buildFields(context),
      onBasicPressed: handleOpenBasicEditor,
      onSubmitPressed: () {
        if (!canSubmit || _isSubmitting) return;
        _handleCustomSubmit();
      },
      isSubmitting: _isSubmitting,
      isEditing: config.isEditing,
      isDisabled: !canSubmit && !config.isEditing,
      pageTitle: config.pageTitle,
    );
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      if (!widget.isEditing) ...[
        _buildFileSelector(),
        const SizedBox(height: 22),
        _buildEncryptionToggle(),
        const SizedBox(height: 22),
      ],
      if (widget.isEditing) ...[
        _buildUpdateContentToggle(),
        const SizedBox(height: 22),
        if (_updateContent) ...[
          _buildFileSelector(),
          const SizedBox(height: 22),
          _buildEncryptionToggle(),
          const SizedBox(height: 22),
        ],
      ],
      _buildNameField(),
      const SizedBox(height: 22),
      _buildAddTimeField(),
      const SizedBox(height: 22),
      _buildCoverField(),
      const SizedBox(height: 22),
      _buildIntroField(),
    ];
  }

  bool _validateData() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    
    // 创建模式或编辑模式下选择更新内容时需要文件
    if ((!widget.isEditing) || (widget.isEditing && _updateContent)) {
      if (_selectedFile == null) return false;
    }
    
    return true;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final data = {
      'name': _nameController.text.trim(),
      'intro': _introController.text.trim(),
      'cover': _coverController.text.trim(),
    };
    
    // 只有创建时才设置 add_time，编辑时不修改
    if (!widget.isEditing && _addTime != null) {
      data['add_time'] = _addTime!.toIso8601String();
    }
    
    return data;
  }

  Widget _buildNameField() {
    return AppTextField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      label: '文章名称',
      hintText: '输入文章名称',
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildAddTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '创建时间',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Text(
            _addTime != null 
                ? _formatDateTime(_addTime!)
                : '未设置',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Widget _buildCoverField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _coverController,
          focusNode: _coverFocusNode,
          label: '封面图片 BID',
          hintText: '输入封面图片的 BID（32位十六进制字符串）',
          textInputAction: TextInputAction.next,
          onChanged: (value) {
            // 延迟加载，避免频繁请求
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_coverController.text.trim() == value.trim()) {
                _loadCoverBlock();
              }
            });
          },
          suffix: _isLoadingCover
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                )
              : null,
        ),
        if (_coverBlock != null) ...[
          const SizedBox(height: 12),
          _buildCoverPreview(),
        ],
      ],
    );
  }

  Widget _buildCoverPreview() {
    if (_coverBlock == null) return const SizedBox.shrink();

    final fileData = FileCardData.fromBlock(_coverBlock!);
    final fileName = _coverBlock!.maybeString('name') ?? '未知文件';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                color: Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                '封面预览',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isImageFile(fileData.ipfsExt))
            _buildImagePreview(fileData)
          else
            _buildCoverFileInfo(fileName),
        ],
      ),
    );
  }

  Widget _buildImagePreview(FileCardData fileData) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<BlockImageResult>(
          future: _loadImage(fileData),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _buildImagePlaceholder();
            }

            return Image.memory(
              snapshot.data!.bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildCoverFileInfo(String fileName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: Colors.white54,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  '非图片文件',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<BlockImageResult> _loadImage(FileCardData fileData) async {
    try {
      final provider = context.read<ConnectionProvider>();
      final endpoint = provider.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('缺少 IPFS 地址');
      }

      final result = await BlockImageLoader.instance.loadVariant(
        data: fileData,
        endpoint: endpoint,
        variant: ImageVariant.medium,
      );

      return result;
    } catch (e) {
      throw Exception('加载图片失败: $e');
    }
  }

  bool _isImageFile(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(ext);
  }

  Widget _buildFileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '文章文件',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _handleSelectFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF18181A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
            ),
            child: _selectedFile != null ? _buildFileInfo() : _buildFilePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    final displayName = _fileName ?? _selectedFile?.path.split('/').last ?? '未知文件';
    final sizeText = _fileSize != null ? _formatFileSize(_fileSize!) : '';
    
    return Column(
      children: [
        const Icon(
          Icons.description_outlined,
          color: Colors.white70,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (sizeText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            sizeText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePlaceholder() {
    return Column(
      children: [
        Icon(
          Icons.upload_file_outlined,
          color: Colors.white.withValues(alpha: 0.4),
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          '点击选择 .md 文件',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '支持 Markdown 格式文件',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEncryptionToggle() {
    return Row(
      children: [
        Switch(
          value: _encryptFile,
          onChanged: (value) {
            setState(() => _encryptFile = value);
          },
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white54,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '加密上传',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '使用 PPE-001 算法加密文件内容',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _handleSelectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        _showMessage('无法读取选择的文件');
        return;
      }

      final selectedFile = File(file.path!);
      final fileSize = await selectedFile.length();

      setState(() {
        _selectedFile = selectedFile;
        _fileName = file.name;
        _fileSize = fileSize;
      });

      // 如果文件名为空，自动填充
      if (_nameController.text.trim().isEmpty) {
        final nameWithoutExt = file.name.replaceAll('.md', '');
        _nameController.text = nameWithoutExt;
      }
    } catch (e) {
      _showMessage('选择文件失败: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildUpdateContentToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Switch(
            value: _updateContent,
            onChanged: (value) {
              setState(() {
                _updateContent = value;
                if (!value) {
                  // 如果关闭更新内容，清除选择的文件
                  _selectedFile = null;
                  _fileName = null;
                  _fileSize = null;
                }
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '更新文章内容',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '选择新的 .md 文件来替换当前文章内容',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroField() {
    return AppTextField(
      controller: _introController,
      focusNode: _introFocusNode,
      label: '文章介绍',
      hintText: '输入文章的详细介绍...',
      minLines: 4,
      maxLines: 8,
    );
  }

  Future<void> _handleCustomSubmit() async {
    if (widget.isEditing) {
      // 编辑模式
      await _handleEditSubmit();
      return;
    }

    // 创建模式需要上传文件
    if (_selectedFile == null) {
      _showMessage('请先选择 .md 文件');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请输入文章名称');
      return;
    }

    final rawNodeBid = effectiveBasicBlock.maybeString('node_bid') ?? '';
    final String? blockNodeBid = rawNodeBid.isNotEmpty ? rawNodeBid : null;

    if (blockNodeBid == null || blockNodeBid.length < 10) {
      _showMessage('请先在基础设置中选择节点');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final connectionProvider = context.read<ConnectionProvider>();
      final storageConnection = connectionProvider.activeConnection;
      
      if (storageConnection == null) {
        _showMessage('当前没有可用的连接');
        return;
      }

      if (storageConnection.address.isEmpty) {
        _showMessage('IPFS 节点地址无效');
        return;
      }

      // 上传文件到 IPFS
      final ipfsData = await _uploadFile(
        file: _selectedFile!,
        endpoint: storageConnection.address,
        encrypt: _encryptFile,
        uploadPassword: storageConnection.ipfsUploadPassword ?? '',
      );

      // 准备 block 数据
      final blockData = Map<String, dynamic>.from(effectiveBasicBlock.data)
        ..['name'] = name
        ..['intro'] = _introController.text.trim()
        ..['cover'] = _coverController.text.trim()
        ..['ipfs'] = ipfsData
        ..['bid'] = generateBidV2(blockNodeBid)
        ..['node_bid'] = blockNodeBid
        ..['model'] = _articleModelId;

      // 只有创建时才设置 add_time
      if (_addTime != null) {
        blockData['add_time'] = _addTime!.toIso8601String();
      }

      // 保存 block
      final api = BlockApi(connectionProvider: connectionProvider);
      await api.saveBlock(
        data: blockData,
        receiverBid: blockNodeBid,
      );

      if (!mounted) return;

      // Update BlockProvider to notify all listening pages
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(BlockModel(data: Map<String, dynamic>.from(blockData)));

      _showMessage('文章创建成功');
      
      // 导航到详情页面
      final resultBlock = BlockModel(data: blockData);
      Navigator.of(context).pop(resultBlock);
    } catch (error) {
      if (!mounted) return;
      _showMessage('创建失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleEditSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请输入文章名称');
      return;
    }

    // 如果选择更新内容但没有选择文件
    if (_updateContent && _selectedFile == null) {
      _showMessage('请选择要上传的 .md 文件');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final connectionProvider = context.read<ConnectionProvider>();
      final blockData = Map<String, dynamic>.from(effectiveBasicBlock.data);

      // 更新基本信息
      blockData['name'] = name;
      blockData['intro'] = _introController.text.trim();
      blockData['cover'] = _coverController.text.trim();

      // 如果选择更新内容，上传新文件
      if (_updateContent && _selectedFile != null) {
        final storageConnection = connectionProvider.activeConnection;
        
        if (storageConnection == null) {
          _showMessage('当前没有可用的连接');
          return;
        }

        if (storageConnection.address.isEmpty) {
          _showMessage('IPFS 节点地址无效');
          return;
        }

        // 上传新文件到 IPFS
        final newIpfsData = await _uploadFile(
          file: _selectedFile!,
          endpoint: storageConnection.address,
          encrypt: _encryptFile,
          uploadPassword: storageConnection.ipfsUploadPassword ?? '',
        );

        // 处理版本历史
        final currentIpfs = blockData['ipfs'] as Map<String, dynamic>?;
        if (currentIpfs != null) {
          // 将当前 ipfs 数据移动到 ipfs_v 列表
          final ipfsVersions = List<Map<String, dynamic>>.from(
            blockData['ipfs_v'] as List<dynamic>? ?? <Map<String, dynamic>>[],
          );
          
          // 直接添加旧版本数据，不添加时间戳
          ipfsVersions.add(Map<String, dynamic>.from(currentIpfs));
          blockData['ipfs_v'] = ipfsVersions;
        }

        // 更新 ipfs 字段为新数据
        blockData['ipfs'] = newIpfsData;
      }

      // 保存更新的 block
      final api = BlockApi(connectionProvider: connectionProvider);
      await api.saveBlock(data: blockData);

      if (!mounted) return;

      // Update BlockProvider to notify all listening pages
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(BlockModel(data: Map<String, dynamic>.from(blockData)));

      if (_updateContent) {
        _showMessage('文章内容和信息更新成功');
      } else {
        _showMessage('文章信息更新成功');
      }

      // 返回更新后的 block
      final resultBlock = BlockModel(data: blockData);
      Navigator.of(context).pop(resultBlock);
    } catch (error) {
      if (!mounted) return;
      _showMessage('更新失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<Map<String, dynamic>> _uploadFile({
    required File file,
    required String endpoint,
    required bool encrypt,
    required String uploadPassword,
  }) async {
    final manager = _UploadTaskManager(
      sourceFile: file,
      endpoint: endpoint,
      encrypt: encrypt,
      fileExtension: '.md',
      uploadPassword: uploadPassword,
    );

    try {
      return await manager.execute();
    } finally {
      await manager.dispose();
    }
  }

  @override
  String? getSubmitErrorMessage() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return '请输入文章名称';
    }

    // 创建模式或编辑模式下选择更新内容时需要文件
    if ((!widget.isEditing) || (widget.isEditing && _updateContent)) {
      if (_selectedFile == null) {
        return widget.isEditing ? '请选择要上传的 .md 文件' : '请选择 .md 文件';
      }
    }

    final coverBid = _coverController.text.trim();
    if (coverBid.isNotEmpty && !_isBidFormat(coverBid)) {
      return '封面 BID 格式不正确（应为32位十六进制字符串）';
    }

    return null;
  }
}

class _UploadTaskManager {
  _UploadTaskManager({
    required this.sourceFile,
    required this.endpoint,
    required this.encrypt,
    required this.fileExtension,
    required this.uploadPassword,
  });

  final File sourceFile;
  final String endpoint;
  final bool encrypt;
  final String? fileExtension;
  final String uploadPassword;

  final List<String> _generatedTempFiles = [];
  String? _tempDirectoryPath;

  Future<Map<String, dynamic>> execute() async {
    _tempDirectoryPath ??= (await getTemporaryDirectory()).path;

    final payload = _UploadTaskPayload(
      sourcePath: sourceFile.path,
      encrypt: encrypt,
      tempDirPath: _tempDirectoryPath!,
    );

    final result = await Isolate.run(() => _performTask(payload));

    if (result.generatedTempPath != null) {
      _generatedTempFiles.add(result.generatedTempPath!);
    }

    final cid = await _uploadToIpfs(result.uploadPath);
    final ext = _resolveExtension();

    final response = <String, dynamic>{
      'cid': cid,
      'ext': ext,
      'size': result.fileSize,
      'sha3_256': result.sha3Hex,
    };

    if (result.encryptionKeyHex != null) {
      response['encryption'] = {
        'algo': 'PPE-001',
        'key': result.encryptionKeyHex,
      };
    }

    return response;
  }

  Future<void> dispose() async {
    for (final path in _generatedTempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // ignore cleanup errors
      }
    }
    _generatedTempFiles.clear();
  }

  Future<String> _uploadToIpfs(String uploadPath) async {
    final endpointUrl = Uri.parse(endpoint);
    final uploadUrl = endpointUrl.replace(path: '/ipfs/ipfs/upload');

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['password'] = uploadPassword
      ..files.add(await http.MultipartFile.fromPath('file', uploadPath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('上传失败(${response.statusCode})：$body');
    }

    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final cid = decoded['cid'];
      if (cid is String && cid.isNotEmpty) {
        return cid;
      }
      throw Exception('上传响应缺少 cid 字段');
    } catch (error) {
      throw Exception('解析上传响应失败：$error');
    }
  }

  String _resolveExtension() {
    if (fileExtension != null && fileExtension!.isNotEmpty) {
      return fileExtension!.startsWith('.')
          ? fileExtension!
          : '.${fileExtension!}';
    }
    return '.md';
  }

  static Future<_UploadTaskResult> _performTask(
    _UploadTaskPayload payload,
  ) async {
    final sourceFile = File(payload.sourcePath);
    final bytes = await sourceFile.readAsBytes();

    if (!payload.encrypt) {
      return _UploadTaskResult(
        uploadPath: payload.sourcePath,
        fileSize: bytes.length,
        sha3Hex: _sha3Hex(bytes),
      );
    }

    final key = _randomBytes(32);
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKeyFromBytes(key);
    final nonce = algorithm.newNonce();

    final secretBox = await algorithm.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);

    final tempPath = '${payload.tempDirPath}/enc_${DateTime.now().microsecondsSinceEpoch}_${_randomHex(8)}';

    await File(tempPath).writeAsBytes(combined, flush: true);

    return _UploadTaskResult(
      uploadPath: tempPath,
      fileSize: combined.length,
      sha3Hex: _sha3Hex(combined),
      encryptionKeyHex: _bytesToHex(key),
      generatedTempPath: tempPath,
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final data = Uint8List(length);
    for (var i = 0; i < length; i++) {
      data[i] = random.nextInt(256);
    }
    return data;
  }

  static String _randomHex(int length) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  static String _sha3Hex(Uint8List data) {
    final digest = SHA3Digest(256);
    digest.update(data, 0, data.length);
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return _bytesToHex(output);
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class _UploadTaskPayload {
  const _UploadTaskPayload({
    required this.sourcePath,
    required this.encrypt,
    required this.tempDirPath,
  });

  final String sourcePath;
  final bool encrypt;
  final String tempDirPath;
}

class _UploadTaskResult {
  const _UploadTaskResult({
    required this.uploadPath,
    required this.fileSize,
    required this.sha3Hex,
    this.encryptionKeyHex,
    this.generatedTempPath,
  });

  final String uploadPath;
  final int fileSize;
  final String sha3Hex;
  final String? encryptionKeyHex;
  final String? generatedTempPath;
}