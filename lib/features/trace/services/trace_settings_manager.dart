import 'package:shared_preferences/shared_preferences.dart';

/// 痕迹功能相关的本地设置管理
class TraceSettingsManager {
  TraceSettingsManager._();

  static const String _traceNodeBidKey = 'trace_node_bid';
  static const String _autoRecordGpsKey = 'auto_record_gps';
  static const String _gpsIntervalMinutesKey = 'gps_interval_minutes';
  static const String _lastGpsRecordTimeKey = 'last_gps_record_time';
  static const String _gpsAutoIntroKey = 'gps_auto_intro';
  static const String _gpsAutoTagsKey = 'gps_auto_tags';

  /// 保存痕迹节点的 BID
  static Future<void> saveTraceNodeBid(String bid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_traceNodeBidKey, bid.trim());
  }

  /// 读取痕迹节点的 BID，未设置时返回空字符串
  static Future<String> loadTraceNodeBid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_traceNodeBidKey) ?? '';
  }

  /// 是否已配置痕迹节点BID
  static Future<bool> hasTraceNodeBid() async {
    final bid = await loadTraceNodeBid();
    return bid.trim().isNotEmpty;
  }

  /// 保存自动记录GPS开关状态
  static Future<void> saveAutoRecordGps(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRecordGpsKey, enabled);
  }

  /// 读取自动记录GPS开关状态，默认为 false
  static Future<bool> loadAutoRecordGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRecordGpsKey) ?? false;
  }

  /// 保存GPS记录时间间隔（分钟）
  static Future<void> saveGpsIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gpsIntervalMinutesKey, minutes);
  }

  /// 读取GPS记录时间间隔（分钟），默认为 5 分钟
  static Future<int> loadGpsIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gpsIntervalMinutesKey) ?? 5;
  }

  /// 保存最后一次GPS记录的时间戳
  static Future<void> saveLastGpsRecordTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastGpsRecordTimeKey, time.millisecondsSinceEpoch);
  }

  /// 读取最后一次GPS记录的时间戳
  static Future<DateTime?> loadLastGpsRecordTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastGpsRecordTimeKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// 检查是否应该创建新的GPS记录
  static Future<bool> shouldCreateGpsRecord() async {
    final autoRecord = await loadAutoRecordGps();
    if (!autoRecord) return false;

    final lastTime = await loadLastGpsRecordTime();
    if (lastTime == null) return true;

    final intervalMinutes = await loadGpsIntervalMinutes();
    final now = DateTime.now();
    final difference = now.difference(lastTime);

    return difference.inMinutes >= intervalMinutes;
  }

  /// 保存自动GPS记录的介绍文本
  static Future<void> saveGpsAutoIntro(String intro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gpsAutoIntroKey, intro);
  }

  /// 读取自动GPS记录的介绍文本，默认为"自动记录"
  static Future<String> loadGpsAutoIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gpsAutoIntroKey) ?? '自动记录';
  }

  /// 保存自动GPS记录的标签列表
  static Future<void> saveGpsAutoTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_gpsAutoTagsKey, tags);
  }

  /// 读取自动GPS记录的标签列表，默认为空列表
  static Future<List<String>> loadGpsAutoTags() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_gpsAutoTagsKey) ?? [];
  }
}

