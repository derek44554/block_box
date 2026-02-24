import 'package:block_app/features/trace/services/trace_settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/utils/formatters/time_formatter.dart';
import '../../../core/utils/generators/bid_generator.dart';
import '../../../state/connection_provider.dart';

/// 自动GPS记录服务
class AutoGpsService {
  AutoGpsService._();

  /// 尝试自动创建GPS记录
  /// 
  /// 在App启动时调用，会检查：
  /// 1. 是否开启了自动记录GPS
  /// 2. 是否配置了痕迹节点BID
  /// 3. 距离上次记录是否已经超过设置的时间间隔
  /// 4. 如果满足条件，则自动获取位置并创建GPS记录
  static Future<void> tryAutoCreateGpsRecord(
    BuildContext context,
    ConnectionProvider connectionProvider,
  ) async {
    try {
      // 1. 检查是否应该创建GPS记录
      final shouldCreate = await TraceSettingsManager.shouldCreateGpsRecord();
      if (!shouldCreate) {
        debugPrint('AutoGpsService: 不满足自动记录条件，跳过');
        return;
      }

      // 2. 检查是否配置了痕迹节点BID
      final traceBid = await TraceSettingsManager.loadTraceNodeBid();
      if (traceBid.trim().isEmpty || traceBid.length < 10) {
        debugPrint('AutoGpsService: 未配置痕迹节点BID，跳过');
        return;
      }

      debugPrint('AutoGpsService: 开始自动创建GPS记录');

      // 3. 获取GPS位置
      final position = await _getLocation();
      if (position == null) {
        debugPrint('AutoGpsService: 无法获取GPS位置，跳过');
        return;
      }

      // 4. 读取自定义的介绍和标签
      final intro = await TraceSettingsManager.loadGpsAutoIntro();
      final tags = await TraceSettingsManager.loadGpsAutoTags();

      // 5. 创建GPS记录
      await _createGpsRecord(
        traceBid: traceBid,
        longitude: position.longitude,
        latitude: position.latitude,
        intro: intro,
        tags: tags,
        connectionProvider: connectionProvider,
      );

      // 6. 更新最后记录时间
      await TraceSettingsManager.saveLastGpsRecordTime(DateTime.now());

      debugPrint('AutoGpsService: GPS记录创建成功（介绍: $intro, 标签: $tags）');
    } catch (e, stackTrace) {
      debugPrint('AutoGpsService: 自动创建GPS记录失败: $e');
      debugPrint('AutoGpsService: $stackTrace');
    }
  }

  /// 获取当前位置
  static Future<Position?> _getLocation() async {
    try {
      // 检查位置服务是否启用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('AutoGpsService: 位置服务未启用');
        return null;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('AutoGpsService: 位置权限被拒绝');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('AutoGpsService: 位置权限被永久拒绝');
        return null;
      }

      // 获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      debugPrint('AutoGpsService: 获取位置失败: $e');
      return null;
    }
  }

  /// 创建GPS记录
  static Future<void> _createGpsRecord({
    required String traceBid,
    required double longitude,
    required double latitude,
    required String intro,
    required List<String> tags,
    required ConnectionProvider connectionProvider,
  }) async {
    final bid = generateBidV2(traceBid);
    final now = nowIso8601WithOffset();

    final data = <String, dynamic>{
      'bid': bid,
      'model': '5b877cf0259538958f4ce032a1de7ae7', // GPS model ID
      'node_bid': traceBid,
      'intro': intro,
      'add_time': now,
      'gps': {
        'longitude': longitude,
        'latitude': latitude,
      },
      'permission_level': 0,
      'tag': tags,
      'link': <String>[],
    };

    final api = BlockApi(connectionProvider: connectionProvider);
    await api.saveBlock(
      data: data,
      receiverBid: traceBid.substring(0, 10),
    );
  }
}

