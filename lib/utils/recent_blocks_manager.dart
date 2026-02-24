import 'package:shared_preferences/shared_preferences.dart';

/// 最近创建的Block管理器
/// 
/// 负责管理本地最近创建的Block BID列表，最多保留30个
class RecentBlocksManager {
  static const String _key = 'recent_blocks_bids';
  static const int _maxCount = 30;

  /// 添加新创建的Block BID到最近列表
  static Future<void> addRecentBlock(String bid) async {
    if (bid.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> recentBids = await getRecentBids();
    
    // 移除已存在的相同BID（如果存在）
    recentBids.remove(bid);
    
    // 将新BID添加到列表开头
    recentBids.insert(0, bid);
    
    // 限制最多30个
    if (recentBids.length > _maxCount) {
      recentBids.removeRange(_maxCount, recentBids.length);
    }
    
    // 保存到本地存储
    await prefs.setStringList(_key, recentBids);
  }

  /// 获取最近创建的Block BID列表
  static Future<List<String>> getRecentBids() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? bids = prefs.getStringList(_key);
    return bids ?? [];
  }

  /// 清空最近创建的Block列表
  static Future<void> clearRecentBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// 移除指定的BID
  static Future<void> removeBid(String bid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> recentBids = await getRecentBids();
    
    recentBids.remove(bid);
    await prefs.setStringList(_key, recentBids);
  }

  /// 获取最近创建的Block数量
  static Future<int> getRecentBlocksCount() async {
    final bids = await getRecentBids();
    return bids.length;
  }
}
