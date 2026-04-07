import 'package:block_app/state/connection_provider.dart';
import 'package:block_app/utils/recent_blocks_manager.dart';
import 'package:block_flutter/block_flutter.dart' as sdk;

class BlockApi {
  BlockApi({required ConnectionProvider connectionProvider}) : _connectionProvider = connectionProvider;

  final ConnectionProvider _connectionProvider;

  Future<Map<String, dynamic>> getBlock({required dynamic bid}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getBlock(bid: bid);
  }

  Future<Map<String, dynamic>> getBlocksByTag({required String name, int page = 1, int limit = 10}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getBlocksByTag(name: name, page: page, limit: limit);
  }

  Future<Map<String, dynamic>> getLinksByTarget({required dynamic bid, int page = 1, int limit = 10, String? order}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getLinksByTarget(bid: bid, page: page, limit: limit, order: order);
  }

  Future<Map<String, dynamic>> getLinksByMain({required dynamic bid, int page = 1, int limit = 10, String? model, String? tag, String? order}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getLinksByMain(bid: bid, page: page, limit: limit, model: model, tag: tag, order: order);
  }

  Future<Map<String, dynamic>> getLinksByTargets({required List<String> bids, int page = 1, int limit = 10, String? order}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getLinksByTargets(bids: bids, page: page, limit: limit, order: order);
  }

  Future<Map<String, dynamic>> saveBlock({required Map<String, dynamic> data, String? receiverBid}) async {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    final response = await sdk.BlockApi(connection: connection).saveBlock(data: data, receiverBid: receiverBid);
    await RecentBlocksManager.addRecentBlock(data['bid']);
    return response;
  }

  Future<Map<String, dynamic>> getRecentBlocks({int limit = 20, int page = 1}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getRecentBlocks(limit: limit, page: page);
  }

  Future<Map<String, dynamic>> getMultipleBlocks({required List<String> bids}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getMultipleBlocks(bids: bids);
  }

  Future<Map<String, dynamic>> getAllBlocks({int page = 1, int limit = 20, String order = 'asc', String? receiverBid, String? model, String? tag, List<String>? excludeModels}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).getAllBlocks(page: page, limit: limit, order: order, receiverBid: receiverBid, model: model, tag: tag, excludeModels: excludeModels);
  }

  Future<Map<String, dynamic>> deleteBlock({required dynamic bid}) {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) throw StateError('No active connection available. Cannot perform request.');
    return sdk.BlockApi(connection: connection).deleteBlock(bid: bid);
  }
}
