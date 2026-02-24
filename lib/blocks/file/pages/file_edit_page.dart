import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:block_app/core/network/models/connection_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:provider/provider.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/sha3.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/utils/formatters/time_formatter.dart';
import '../../../core/utils/generators/bid_generator.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../models/file_card_data.dart';

/// 统一的文件上传页面，支持所有文件类型（包括图片）
/// 对图片文件会提取EXIF信息（GPS、拍摄时间等）
class FileEditPage extends StatefulWidget {
  const FileEditPage({super.key, this.block, this.traceNodeBid, this.isImageMode = false});

  final BlockModel? block;
  final String? traceNodeBid;
  final bool isImageMode; // 是否为图片模式（影响选择器类型）

  bool get isEditing => block != null;

  @override
  State<FileEditPage> createState() => _FileEditPageState();
}

class _FileEditPageState extends State<FileEditPage> with BlockEditMixin {
  static const String _fileModelId = 'c4238dd0d3d95db7b473adb449f6d282';

  late final TextEditingController _nameController;
  late final TextEditingController _introController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();

  File? _selectedFile;
  Uint8List? _previewBytes; // 用于图片预览
  String? _fileName;
  String? _fileExtension;
  int? _fileSize;
  DateTime? _fileTimestamp;
  Map<String, double>? _gpsCoordinates; // GPS信息（仅图片）
  bool _isPreviewLoading = false;
  bool _isSubmitting = false;
  bool _encryptFile = true;

  bool get _hasSelectedNode {
    final nodeBid = effectiveBasicBlock.maybeString('node_bid');
    return nodeBid != null && nodeBid.length >= 10;
  }

  bool get _isImageFile {
    if (_fileExtension == null) return false;
    final ext = _fileExtension!.toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(ext);
  }

  String get _pageTitle => widget.isImageMode ? '图片' : '文件';

  @override
  void initState() {
    super.initState();

    // 初始化基础配置
    config = EditPageConfig(
      modelId: _fileModelId,
      pageTitle: _pageTitle,
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
      _loadExistingFile();
    } else {
      _nameController = TextEditingController();
      _introController = TextEditingController();
      
      final data = <String, dynamic>{
        'bid': '',
        'tag': <String>[],
        'link': <String>[],
        'permission_level': 0,
        'model': _fileModelId,
        'name': '',
        'intro': '',
        'ipfs': <String, dynamic>{},
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
    _nameFocusNode.dispose();
    _introFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingFile() async {
    if (!widget.isEditing || widget.block == null) return;

    final data = FileCardData.fromBlock(widget.block!);
    if (data.cid == null || data.cid!.isEmpty) return;

    setState(() {
      _fileName = data.fileName;
      _fileExtension = data.ipfsExt;
      _fileSize = data.ipfsSize;
      _gpsCoordinates = data.gps != null 
          ? {'latitude': data.gps!.latitude, 'longitude': data.gps!.longitude}
          : null;
      _isPreviewLoading = true;
    });

    // 如果是图片文件，尝试加载预览
    if (_isImageFile) {
      try {
        final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
        if (endpoint != null && endpoint.isNotEmpty) {
          final result = await BlockImageLoader.instance.loadVariant(
            data: data,
            endpoint: endpoint,
            variant: ImageVariant.original,
          );
          if (mounted) {
            setState(() {
              _previewBytes = result.bytes;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载图片预览失败: $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isPreviewLoading = false;
      });
    }
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
    final fields = <Widget>[
      _buildFileSelector(),
      const SizedBox(height: 28),
      _buildNameField(),
      const SizedBox(height: 22),
      _buildIntroField(),
    ];

    if (_fileTimestamp != null || _fileSize != null || _gpsCoordinates != null) {
      fields.addAll([
        const SizedBox(height: 22),
        _buildMetadataInfo(),
      ]);
    }

    if (!widget.isEditing) {
      fields.addAll([
        const SizedBox(height: 18),
        _buildEncryptionToggle(),
      ]);
    }

    return fields;
  }

  bool _validateData() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    if (!widget.isEditing && _selectedFile == null) return false;
    return true;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'intro': _introController.text.trim(),
    };

    if (_fileTimestamp != null) {
      data['add_time'] = iso8601WithOffset(_fileTimestamp!);
    }
    if (_gpsCoordinates != null) {
      data['gps'] = _gpsCoordinates;
    }

    return data;
  }
  Widget _buildFileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _pageTitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: widget.isEditing ? null : _handleSelectFile,
          child: _isImageFile && (_previewBytes != null || widget.isEditing)
              ? _buildImagePreview()
              : _buildFileContainer(),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF18181A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _previewBytes != null
                    ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                    : _buildImagePlaceholder(),
              ),
            ),
            if (_isPreviewLoading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xAA000000)),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isEditing
                ? Icons.image_outlined
                : Icons.add_photo_alternate_outlined,
            color: Colors.white38,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            widget.isEditing ? '图片无法修改' : '点击选择图片',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: _selectedFile != null || widget.isEditing
          ? _buildFileInfo()
          : _buildFilePlaceholder(),
    );
  }

  Widget _buildFileInfo() {
    final displayName = _fileName ?? _selectedFile?.path.split('/').last ?? '未知文件';
    final sizeText = _fileSize != null ? _formatFileSize(_fileSize!) : '';
    
    return Column(
      children: [
        Icon(
          _getFileIcon(),
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
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          Text(
            '文件无法修改',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.isImageMode ? Icons.add_photo_alternate_outlined : Icons.upload_file_outlined,
          color: Colors.white38,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          widget.isImageMode ? '点击选择图片' : '点击选择文件',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isImageMode ? '支持 JPG、PNG、GIF 等格式' : '支持各种文件类型',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon() {
    final ext = _fileExtension?.toLowerCase() ?? '';
    
    // 图片文件
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(ext)) {
      return Icons.image_outlined;
    }
    
    // 视频文件
    if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'].contains(ext)) {
      return Icons.video_file_outlined;
    }
    
    // 音频文件
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(ext)) {
      return Icons.audio_file_outlined;
    }
    
    // 文档文件
    if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(ext)) {
      return Icons.description_outlined;
    }
    
    // 表格文件
    if (['xls', 'xlsx', 'csv'].contains(ext)) {
      return Icons.table_chart_outlined;
    }
    
    // 演示文件
    if (['ppt', 'pptx'].contains(ext)) {
      return Icons.slideshow_outlined;
    }
    
    // 压缩文件
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip_outlined;
    }
    
    // 代码文件
    if (['js', 'ts', 'dart', 'py', 'java', 'cpp', 'c', 'html', 'css', 'json', 'xml', 'yaml', 'yml'].contains(ext)) {
      return Icons.code_outlined;
    }
    
    return Icons.insert_drive_file_outlined;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '名称',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '输入文件名称',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFF1C1C1F),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
            ),
            suffixIcon: _fileExtension != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 18.0),
                    child: Align(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      alignment: Alignment.center,
                      child: Text(
                        _fileExtension!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _buildIntroField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '简介',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _introController,
          focusNode: _introFocusNode,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText: '描述文件内容、用途或其他信息...',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1C1C1F),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fileTimestamp != null)
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: '时间',
            value: iso8601WithOffset(_fileTimestamp!),
          ),
        if (_fileSize != null) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.storage_outlined,
            label: '大小',
            value: _formatFileSize(_fileSize!),
          ),
        ],
        if (_gpsCoordinates != null) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'GPS',
            value:
                '${_gpsCoordinates!['latitude']!.toStringAsFixed(6)}, ${_gpsCoordinates!['longitude']!.toStringAsFixed(6)}',
          ),
        ],
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
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '加密上传 (PPE-001)',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSelectFile() async {
    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      if (!mounted) return;
      return;
    }

    setState(() => _isPreviewLoading = true);

    try {
      File? file;
      String? fileName;
      String? fileExtension;
      int? fileSize;

      if (widget.isImageMode) {
        // 图片模式：使用 ImagePicker
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: true,
        );
        if (pickedFile == null) {
          if (mounted) setState(() => _isPreviewLoading = false);
          return;
        }

        file = File(pickedFile.path);
        fileName = p.basenameWithoutExtension(pickedFile.path);
        fileExtension = p.extension(pickedFile.path);
        fileSize = await file.length();
      } else {
        // 文件模式：使用 FilePicker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) {
          if (mounted) setState(() => _isPreviewLoading = false);
          return;
        }

        final pickedFile = result.files.first;
        file = File(pickedFile.path!);
        fileName = p.basenameWithoutExtension(pickedFile.name);
        fileExtension = p.extension(pickedFile.name);
        fileSize = pickedFile.size;
      }

      // 获取文件基本时间信息
      final fileStat = await file.stat();
      final createdTime = fileStat.changed;
      final modifiedTime = fileStat.modified;
      DateTime? timestamp = createdTime.isBefore(modifiedTime) ? createdTime : modifiedTime;

      // 读取文件字节用于EXIF处理和图片预览
      final bytes = await file.readAsBytes();
      Uint8List? previewBytes;
      Map<String, double>? gps;

      // 检查是否为图片文件
      final ext = fileExtension.toLowerCase().replaceAll('.', '');
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(ext);

      if (isImage) {
        // 设置图片预览
        previewBytes = bytes;

        // 提取EXIF信息（仅对支持EXIF的格式）
        if (['jpg', 'jpeg', 'tiff', 'tif'].contains(ext)) {
          try {
            final exifData = await readExifFromBytes(bytes);

            // 1. 提取拍摄时间（优先级最高）
            final dateTimeOriginal = exifData['EXIF DateTimeOriginal']?.toString();
            if (dateTimeOriginal != null) {
              // EXIF format is "YYYY:MM:DD HH:MM:SS"
              final formattedString = dateTimeOriginal
                  .replaceFirst(':', '-')
                  .replaceFirst(':', '-');
              final exifTimestamp = DateTime.tryParse(formattedString);
              if (exifTimestamp != null) {
                timestamp = exifTimestamp; // 拍摄时间优先于文件时间
              }
            }

            // 2. 提取GPS信息
            gps = _getGpsCoordinates(exifData);
          } catch (e) {
            debugPrint('EXIF提取失败: $e');
            // 继续使用文件时间，不影响整体流程
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedFile = file;
          _previewBytes = previewBytes;
          _fileName = fileName;
          _nameController.text = fileName ?? '';
          _fileExtension = fileExtension;
          _fileSize = fileSize;
          _fileTimestamp = timestamp;
          _gpsCoordinates = gps;
          _isPreviewLoading = false;

          // 更新 BlockModel
          final data = Map<String, dynamic>.from(effectiveBasicBlock.data);
          data['name'] = fileName ?? '';
          if (timestamp != null) {
            data['add_time'] = iso8601WithOffset(timestamp);
          }
          if (gps != null) {
            data['gps'] = gps;
          }
          updateBasicBlock(BlockModel(data: data));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  Map<String, double>? _getGpsCoordinates(Map<String, IfdTag> data) {
    final latTag = data['GPS GPSLatitude'];
    final lonTag = data['GPS GPSLongitude'];
    final latRefTag = data['GPS GPSLatitudeRef']?.toString();
    final lonRefTag = data['GPS GPSLongitudeRef']?.toString();

    if (latTag == null ||
        lonTag == null ||
        latRefTag == null ||
        lonRefTag == null) {
      return null;
    }

    try {
      final lat = _dmsToDecimal(latTag.values.toList().cast<Ratio>());
      final lon = _dmsToDecimal(lonTag.values.toList().cast<Ratio>());

      final finalLat = latRefTag == 'S' ? -lat : lat;
      final finalLon = lonRefTag == 'W' ? -lon : lon;

      return {'latitude': finalLat, 'longitude': finalLon};
    } catch (_) {
      return null;
    }
  }

  double _dmsToDecimal(List<Ratio> dms) {
    if (dms.length != 3) return 0.0;
    double degrees = dms[0].toDouble();
    double minutes = dms[1].toDouble();
    double seconds = dms[2].toDouble();
    return degrees + (minutes / 60) + (seconds / 3600);
  }

  Future<bool> _ensurePermissions() async {
    if (Platform.isIOS) {
      if (widget.isImageMode) {
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted || photosStatus.isLimited) {
          return true;
        }
        final requestResult = await Permission.photos.request();
        return requestResult.isGranted || requestResult.isLimited;
      }
      return true; // iOS 文件选择不需要特殊权限
    }

    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      if (widget.isImageMode) {
        // 图片模式权限处理
        Permission storageOrPhotosPermission;

        // Android 13 (SDK 33) 及以上版本使用 Permission.photos
        if (sdkInt >= 33) {
          storageOrPhotosPermission = Permission.photos;
        } else {
          storageOrPhotosPermission = Permission.storage;
        }

        final storageStatus = await storageOrPhotosPermission.status;
        final locationStatus = await Permission.accessMediaLocation.status;

        if (storageStatus.isGranted && locationStatus.isGranted) {
          return true;
        }

        // 请求存储/照片权限
        if (!storageStatus.isGranted) {
          final storageResult = await storageOrPhotosPermission.request();
          if (!storageResult.isGranted) {
            return false;
          }
        }

        // 请求媒体位置权限（用于GPS信息）
        if (!locationStatus.isGranted) {
          final locationResult = await Permission.accessMediaLocation.request();
          if (!locationResult.isGranted) {
            // 如果用户仅授予存储而拒绝位置，也允许操作，只是没有GPS信息
          }
        }

        // 检查最终状态
        final finalStorageStatus = await storageOrPhotosPermission.status;
        if (finalStorageStatus.isGranted) {
          return true;
        }

        if (await storageOrPhotosPermission.isPermanentlyDenied ||
            await Permission.accessMediaLocation.isPermanentlyDenied) {
          await _openAppSettings();
        }
        return false;
      } else {
        // 文件模式权限处理
        if (sdkInt >= 33) {
          // Android 13+ 不需要存储权限来访问用户选择的文件
          return true;
        } else {
          final storagePermission = Permission.storage;
          final storageStatus = await storagePermission.status;
          if (storageStatus.isGranted) {
            return true;
          }

          final storageResult = await storagePermission.request();
          if (storageResult.isGranted) {
            return true;
          }

          if (await storagePermission.isPermanentlyDenied) {
            await _openAppSettings();
          }
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _openAppSettings() async {
    if (!mounted) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1F),
          title: const Text('权限提示', style: TextStyle(color: Colors.white)),
          content: Text(
            widget.isImageMode 
                ? '需要相册与"读取媒体位置信息"权限才能访问照片的 GPS 数据，请前往系统设置授予权限。'
                : '需要存储权限才能访问文件，请前往系统设置授予权限。',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('前往设置'),
            ),
          ],
        );
      },
    );

    if (shouldOpen == true) {
      await openAppSettings();
    }
  }

  Future<void> _handleCustomSubmit() async {
    await _handleSubmit();
  }
  Future<void> _handleSubmit() async {
    if (!widget.isEditing && _selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择文件')));
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件名称不能为空')));
      return;
    }

    if (widget.isEditing) {
      _handleUpdate();
      return;
    }

    final rawNodeBid = effectiveBasicBlock.maybeString('node_bid') ?? '';
    final String? blockNodeBid = rawNodeBid.isNotEmpty ? rawNodeBid : null;

    if (blockNodeBid == null || blockNodeBid.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在基础设置中选择节点')));
      return;
    }

    final connectionProvider = context.read<ConnectionProvider>();
    final traceBid = widget.traceNodeBid?.trim();
    final bool isTraceMode = traceBid != null && traceBid.isNotEmpty;

    // 痕迹模式下允许独立的 IPFS 存储连接；否则沿用当前连接
    ConnectionModel? storageConnection;
    if (isTraceMode) {
      storageConnection = connectionProvider.ipfsStorageConnection;
      if (storageConnection == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先在连接设置中启用 IPFS 存储节点')));
        return;
      }
    } else {
      storageConnection = connectionProvider.activeConnection;
      if (storageConnection == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前没有可用的连接')));
        return;
      }
    }

    if (storageConnection.address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('IPFS 节点地址无效')));
      return;
    }

    final uploadUrl = Uri.parse(
      storageConnection.address,
    ).replace(path: '/ipfs/ipfs/upload');

    setState(() => _isSubmitting = true);

    try {
      final ipfsData = await _uploadFile(
        file: _selectedFile!,
        endpoint: uploadUrl.toString(),
        encrypt: _encryptFile,
        uploadPassword: storageConnection.ipfsUploadPassword ?? '',
      );

      // 如果是图片文件，缓存到内存
      final cid = ipfsData['cid'] as String?;
      if (cid != null && cid.isNotEmpty && _previewBytes != null && _isImageFile) {
        await ImageCacheHelper.removeFromCache(cid);
        ImageCacheHelper.cacheMemoryImage(
          cid,
          _previewBytes!,
          variant: ImageVariant.original,
        );
      }

      final blockData = Map<String, dynamic>.from(effectiveBasicBlock.data)
        ..['name'] = name
        ..['intro'] = _introController.text.trim()
        ..['ipfs'] = ipfsData
        ..['bid'] = generateBidV2(blockNodeBid)
        ..['node_bid'] = blockNodeBid
        ..['model'] = _fileModelId;

      if (_fileTimestamp != null) {
        blockData['add_time'] = iso8601WithOffset(_fileTimestamp!);
      }

      final api = BlockApi(connectionProvider: connectionProvider);
      await api.saveBlock(
        data: blockData,
        receiverBid: blockNodeBid,
      );

      if (!mounted) return;

      // Update BlockProvider to notify all listening pages
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(BlockModel(data: Map<String, dynamic>.from(blockData)));

      debugPrint(
        'FileEditPage: saved block ipfs data -> ${blockData['ipfs']}',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件创建成功')));

      final resultBlock = BlockModel(data: blockData);
      if (widget.isEditing) {
        Navigator.of(context).pop(resultBlock);
      } else {
        AppRouter.openBlockDetailPage(context, resultBlock, replace: true);
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('文件创建失败: $error');
      debugPrint(stackTrace.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleUpdate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件名称不能为空')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final blockData = Map<String, dynamic>.from(effectiveBasicBlock.data)
        ..['name'] = name
        ..['intro'] = _introController.text.trim();

      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      await api.saveBlock(data: blockData);

      if (!mounted) return;

      // Update BlockProvider to notify all listening pages
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(BlockModel(data: Map<String, dynamic>.from(blockData)));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件信息已更新')));

      final resultBlock = BlockModel(data: blockData);
      Navigator.of(context).pop(resultBlock);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败：$error')));
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
      fileExtension: _fileExtension,
      uploadPassword: uploadPassword,
    );

    try {
      return await manager.execute();
    } finally {
      await manager.dispose();
    }
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
    return p.extension(sourceFile.path);
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

    final tempPath = p.join(
      payload.tempDirPath,
      'enc_${DateTime.now().microsecondsSinceEpoch}_${_randomHex(8)}',
    );

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}