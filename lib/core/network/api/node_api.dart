import 'package:block_app/state/connection_provider.dart';
import 'package:block_flutter/block_flutter.dart' as sdk;

class NodeApi {
  NodeApi({required ConnectionProvider connectionProvider}) : _connectionProvider = connectionProvider;
  final ConnectionProvider _connectionProvider;

  Future<Map<String, dynamic>> getSignature() {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) {
      throw StateError('No active connection available. Cannot perform request.');
    }
    return sdk.NodeApi(connection: connection).getSignature();
  }
}
