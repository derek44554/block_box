import 'package:flutter/material.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';

import '../services/trace_settings_manager.dart';

/// 痕迹设置页面，可配置痕迹节点 BID
class TraceSettingPage extends StatefulWidget {
  const TraceSettingPage({
    super.key,
    required this.showGps,
    required this.onShowGpsChanged,
  });

  final bool showGps;
  final ValueChanged<bool> onShowGpsChanged;

  @override
  State<TraceSettingPage> createState() => _TraceSettingPageState();
}

class _TraceSettingPageState extends State<TraceSettingPage> {
  late final TextEditingController _bidController;
  late final TextEditingController _intervalController;
  late final TextEditingController _gpsIntroController;
  late final TextEditingController _gpsTagInputController;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _autoRecordGps = false;
  int _gpsIntervalMinutes = 5;
  List<String> _gpsTags = [];

  @override
  void initState() {
    super.initState();
    _bidController = TextEditingController();
    _intervalController = TextEditingController();
    _gpsIntroController = TextEditingController();
    _gpsTagInputController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _bidController.dispose();
    _intervalController.dispose();
    _gpsIntroController.dispose();
    _gpsTagInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final bid = await TraceSettingsManager.loadTraceNodeBid();
      final autoRecord = await TraceSettingsManager.loadAutoRecordGps();
      final interval = await TraceSettingsManager.loadGpsIntervalMinutes();
      final intro = await TraceSettingsManager.loadGpsAutoIntro();
      final tags = await TraceSettingsManager.loadGpsAutoTags();
      if (!mounted) return;
      setState(() {
        _bidController.text = bid;
        _autoRecordGps = autoRecord;
        _gpsIntervalMinutes = interval;
        _intervalController.text = interval.toString();
        _gpsIntroController.text = intro;
        _gpsTags = tags;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '加载痕迹节点设置失败：$error';
        _isLoading = false;
      });
    }
  }

  void _addGpsTag() {
    final tag = _gpsTagInputController.text.trim();
    if (tag.isEmpty) {
      return;
    }
    if (_gpsTags.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签已存在')),
      );
      return;
    }
    setState(() {
      _gpsTags.add(tag);
      _gpsTagInputController.clear();
    });
  }

  void _removeGpsTag(String tag) {
    setState(() {
      _gpsTags.remove(tag);
    });
  }

  Future<void> _saveBid() async {
    final bid = _bidController.text.trim();
    if (bid.isEmpty) {
      setState(() => _error = 'BID 不能为空');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await TraceSettingsManager.saveTraceNodeBid(bid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('痕迹节点 BID 已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: '重置痕迹节点',
        content: const Text(
          '确定要清空当前的痕迹节点 BID 吗？',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清空'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _bidController.clear();
        _error = null;
      });
      await TraceSettingsManager.saveTraceNodeBid('');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('痕迹节点 BID 已清空')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '痕迹配置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '为痕迹功能指定默认节点。保存后，痕迹记录与同步操作将优先使用该节点。',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(Icons.visibility_outlined, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '显示 GPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '在痕迹记录列表中显示或隐藏 GPS 记录。此设置不会持久化，下次进入痕迹页面时会重置为关闭状态。',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.showGps ? '已开启' : '已关闭',
                        style: TextStyle(
                          color: widget.showGps ? Colors.greenAccent : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: widget.showGps,
                        onChanged: widget.onShowGpsChanged,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.white.withOpacity(0.3),
                        inactiveThumbColor: Colors.white.withOpacity(0.5),
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(Icons.gps_fixed, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '自动记录 GPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '开启后，每次打开 App 时会自动记录 GPS 位置。需要配合时间间隔使用，避免频繁记录。',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _autoRecordGps ? '已开启' : '已关闭',
                        style: TextStyle(
                          color: _autoRecordGps ? Colors.greenAccent : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: _autoRecordGps,
                        onChanged: (value) async {
                          setState(() => _autoRecordGps = value);
                          await TraceSettingsManager.saveAutoRecordGps(value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(value ? '自动记录GPS已开启' : '自动记录GPS已关闭')),
                            );
                          }
                        },
                        activeColor: Colors.white,
                        activeTrackColor: Colors.white.withOpacity(0.3),
                        inactiveThumbColor: Colors.white.withOpacity(0.5),
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                      ),
                    ],
                  ),
                  if (_autoRecordGps) ...[
                    const SizedBox(height: 18),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 18),
                    const Text(
                      '记录时间间隔（分钟）',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '设置两次GPS记录之间的最小时间间隔。例如设置为3分钟，则距离上次记录不足3分钟时不会自动记录。',
                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '输入间隔分钟数',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        suffixText: '分钟',
                        suffixStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF101015),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                      ),
                      onChanged: (value) {
                        final minutes = int.tryParse(value);
                        if (minutes != null && minutes > 0) {
                          _gpsIntervalMinutes = minutes;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final minutes = int.tryParse(_intervalController.text);
                        if (minutes == null || minutes <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效的分钟数')),
                          );
                          return;
                        }
                        await TraceSettingsManager.saveGpsIntervalMinutes(minutes);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('GPS记录间隔已设置为 $minutes 分钟')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('保存间隔设置', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 18),
                    const Text(
                      '自动记录的介绍文本',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '设置自动创建GPS记录时的介绍文本，例如"自动记录"、"每日打卡"等。',
                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gpsIntroController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '例如：自动记录',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF101015),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '自动记录的标签',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '设置自动创建GPS记录时添加的标签。输入标签后点击"添加"按钮。',
                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gpsTagInputController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addGpsTag(),
                            decoration: InputDecoration(
                              hintText: '输入标签，例如：打卡',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF101015),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addGpsTag,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.12),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('添加', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (_gpsTags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _gpsTags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _removeGpsTag(tag),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        final intro = _gpsIntroController.text.trim();
                        if (intro.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('介绍文本不能为空')),
                          );
                          return;
                        }
                        
                        await TraceSettingsManager.saveGpsAutoIntro(intro);
                        await TraceSettingsManager.saveGpsAutoTags(_gpsTags);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已保存：介绍"$intro"，标签${_gpsTags.isEmpty ? "无" : _gpsTags.length.toString() + "个"}')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('保存介绍和标签', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.hub_outlined, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '痕迹节点 BID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '请填写 34 位 BID，用于标识痕迹节点。确保与目标节点保持连接。',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  _buildBidField(context),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Text(
                            _error!,
                            key: const ValueKey('trace_bid_error'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.12),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                )
                              : const Text('保存设置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _confirmClear,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('清空', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidField(BuildContext context) {
    return TextField(
      controller: _bidController,
      style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 0.4),
      maxLength: 34,
      decoration: InputDecoration(
        counterText: '',
        hintText: '输入痕迹节点 BID（34位）',
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF101015),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }
}
