import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';

import '../../../components/layout/base_block_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/time_formatter.dart';


/// GPS 位置编辑/创建页面
class GpsEditPage extends StatefulWidget {
  const GpsEditPage({super.key, this.block, this.traceNodeBid});

  final BlockModel? block;
  final String? traceNodeBid;

  bool get isEditing => block != null;

  @override
  State<GpsEditPage> createState() => _GpsEditPageState();
}

class _GpsEditPageState extends State<GpsEditPage> with BlockEditMixin {
  late final TextEditingController _introController;
  late final TextEditingController _timeController;
  
  final FocusNode _introFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();
  
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    config = EditPageConfig(
      modelId: '5b877cf0259538958f4ce032a1de7ae7',
      pageTitle: 'GPS位置',
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
      _introController = TextEditingController(
        text: block.maybeString('intro') ?? '',
      );
      
      final gpsData = block.map('gps');
      if (gpsData.isNotEmpty) {
        final lon = gpsData['longitude'];
        final lat = gpsData['latitude'];
        if (lon != null) _longitude = double.tryParse(lon.toString());
        if (lat != null) _latitude = double.tryParse(lat.toString());
      }
      
      final addTime = block.maybeString('add_time');
      _timeController = TextEditingController(text: addTime ?? nowIso8601WithOffset());
    } else {
      _introController = TextEditingController();
      _timeController = TextEditingController(text: nowIso8601WithOffset());
      
      // 如果是从痕迹页面创建，设置 node_bid
      final traceNodeBid = widget.traceNodeBid?.trim();
      if (traceNodeBid != null && traceNodeBid.isNotEmpty) {
        final data = <String, dynamic>{
          'model': '5b877cf0259538958f4ce032a1de7ae7',
          'node_bid': traceNodeBid,
        };
        initBasicBlock(BlockModel(data: data));
      }
      
      // 自动获取位置
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  void disposeControllers() {
    _introController.dispose();
    _timeController.dispose();
    _introFocusNode.dispose();
    _timeFocusNode.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // 检查位置服务是否启用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = '位置服务未启用';
          _isGettingLocation = false;
        });
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = '位置权限被拒绝';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = '位置权限被永久拒绝，请在系统设置中启用';
          _isGettingLocation = false;
        });
        return;
      }

      // 获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _longitude = position.longitude;
        _latitude = position.latitude;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = '获取位置失败: $e';
        _isGettingLocation = false;
      });
    }
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      _buildLocationStatus(),
      const SizedBox(height: 22),
      AppTextField(
        controller: _introController,
        label: '介绍（可选）',
        hintText: '输入位置介绍...',
        focusNode: _introFocusNode,
        minLines: 4,
        maxLines: null,
      ),
      const SizedBox(height: 22),
      _buildTimeField(),
    ];
  }

  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _longitude != null && _latitude != null
              ? Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: _longitude != null && _latitude != null
                    ? Color(0xFF4CAF50)
                    : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'GPS 位置',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (!_isGettingLocation)
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh, size: 20),
                  color: Colors.white54,
                  tooltip: '刷新位置',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isGettingLocation)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '正在获取位置...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            )
          else if (_locationError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_longitude != null && _latitude != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoordinateRow('经度', _longitude!),
                  const SizedBox(height: 6),
                  _buildCoordinateRow('纬度', _latitude!),
                ],
              ),
            )
          else
            Text(
              '未获取到位置信息',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow(String label, double value) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(6),
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _validateData() {
    return _longitude != null && _latitude != null;
  }

  Map<String, dynamic> _prepareSubmitData() {
    final intro = _introController.text.trim();
    final time = _timeController.text.trim();

    final data = <String, dynamic>{
      'intro': intro,
    };

    if (_longitude != null && _latitude != null) {
      data['gps'] = {
        'longitude': _longitude,
        'latitude': _latitude,
      };
    }

    // GPS 位置总是保存时间
    if (time.isNotEmpty) {
      data['add_time'] = time;
    }

    return data;
  }

  String? _getSubmitErrorMessage() {
    if (_longitude == null || _latitude == null) {
      return '请先获取 GPS 位置';
    }

    return super.getSubmitErrorMessage();
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
    final canSubmit = config.isEditing || hasSelectedNode || widget.traceNodeBid != null;
    return buildEditPage(
      context: context,
      fields: config.buildFields(context),
      onBasicPressed: () => handleOpenBasicEditor(),
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
