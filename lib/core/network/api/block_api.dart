import 'package:block_app/core/models/block_model.dart';
import 'package:block_app/state/connection_provider.dart';
import 'package:block_app/utils/recent_blocks_manager.dart';
import 'package:block_app/core/network/api/api_client.dart';

/// BlockApi wraps the various block-related operations, ensuring consistent use of the
/// shared `/bridge/ins` route. It encapsulates request-building logic, so call sites only
/// need to provide minimal information like a `bid`.
class BlockApi {
  BlockApi({required ConnectionProvider connectionProvider})
      : _client = ApiClient(connectionProvider: connectionProvider);

  final ApiClient _client;

  /// Retrieves a block by the given [bid]. The bid may be provided as a String or a BlockModel instance.
  Future<Map<String, dynamic>> getBlock({required dynamic bid}) async {
    final normalizedBid = _normalizeBid(bid);
    final receiverPrefix = normalizedBid.substring(0, 10);

    final response = await _client.postToBridge(
      routing: '/block/block/get',
      data: {'bid': normalizedBid},
      receiverBid: receiverPrefix,
    );

    return response;
  }

  /// Fetches blocks associated with a given tag [name]. Supports pagination via [page] and [limit].
  Future<Map<String, dynamic>> getBlocksByTag({
    required String name,
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _client.postToBridge(
      routing: '/block/tag/multiple',
      data: {'name': name, 'page': page, 'limit': limit},
    );

    return response;
  }

  Future<Map<String, dynamic>> getLinksByTarget({
    required dynamic bid,
    int page = 1,
    int limit = 10,
    String? order,
  }) async {
    final normalizedBid = _normalizeBid(bid);

    final response = await _client.postToBridge(
      routing: '/block/link/target/multiple',
      data: {
        'bid': normalizedBid,
        'page': page,
        'limit': limit,
        if (order != null && order.isNotEmpty) 'order': order,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> getLinksByMain({
    required dynamic bid,
    int page = 1,
    int limit = 10,
    String? model,
    String? tag,
    String? order,
  }) async {
    final normalizedBid = _normalizeBid(bid);

    final response = await _client.postToBridge(
      routing: '/block/link/main/multiple',
      data: {
        'bid': normalizedBid,
        'page': page,
        'limit': limit,
        if (model != null && model.isNotEmpty) 'model': model,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (order != null && order.isNotEmpty) 'order': order,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> getLinksByTargets({
    required List<String> bids,
    int page = 1,
    int limit = 10,
    String? order,
  }) async {
    final response = await _client.postToBridge(
      routing: '/block/link/main/multiple_by_targets',
      data: {
        'bids': bids,
        'page': page,
        'limit': limit,
        if (order != null && order.isNotEmpty) 'order': order,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> saveBlock({
    required Map<String, dynamic> data,
    String? receiverBid,
  }) async {
    final rawNodeBid = data['node_bid'];
    final String? embeddedNodeBid =
        rawNodeBid is String && rawNodeBid.trim().isNotEmpty ? rawNodeBid.trim() : null;
    final resolvedReceiverBid = receiverBid ?? embeddedNodeBid;

    final response = await _client.postToBridge(
      routing: '/block/write/simple',
      data: data,
      receiverBid: resolvedReceiverBid ?? data['bid'].substring(0, 10),
    );

    await RecentBlocksManager.addRecentBlock(data['bid']);

    return response;
  }

  /// 获取最近创建的Block列表
  Future<Map<String, dynamic>> getRecentBlocks({
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _client.postToBridge(
      routing: '/block/block/recent',
      data: {'limit': limit, 'page': page},
    );

    return response;
  }

  /// 根据BID列表获取多个Block
  Future<Map<String, dynamic>> getMultipleBlocks({
    required List<String> bids,
  }) async {
    final response = await _client.postToBridge(
      routing: '/block/block/multiple',
      data: {'bids': bids},
    );

    return response;
  }

  Future<Map<String, dynamic>> getAllBlocks({
    int page = 1,
    int limit = 20,
    String order = 'asc',
    String? receiverBid,
    String? model,
    String? tag,
    List<String>? excludeModels,
  }) async {
    final response = await _client.postToBridge(
      routing: '/block/block/all',
      data: {
        'page': page,
        'limit': limit,
        'order': order,
        if (model != null && model.isNotEmpty) 'model': model,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (excludeModels != null && excludeModels.isNotEmpty) 'exclude_models': excludeModels,
      },
      receiverBid: receiverBid,
    );

    return response;
  }

  /// 删除Block及其所有关联关系
  /// 删除Block本身、所有相关的Link（作为main或target）、所有相关的Tag
  Future<Map<String, dynamic>> deleteBlock({required dynamic bid}) async {
    final normalizedBid = _normalizeBid(bid);
    final receiverPrefix = normalizedBid.substring(0, 10);

    final response = await _client.postToBridge(
      routing: '/block/delete/simple',
      data: {'bid': normalizedBid},
      receiverBid: receiverPrefix,
    );

    return response;
  }

  String _normalizeBid(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is BlockModel) {
      final bid = value.data['bid'];
      if (bid is String && bid.isNotEmpty) {
        return bid;
      }
    }

    final Object? bid = _extractBid(value);
    if (bid is String) {
      return bid;
    }

    throw ArgumentError('Unable to extract bid from provided value: $value');
  }

  String? _extractBid(dynamic value) {
    try {
      final dynamic bidValue = value.bid;
      return bidValue is String ? bidValue : null;
    } catch (_) {
      return null;
    }
  }
}
