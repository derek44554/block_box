import 'package:block_app/state/connection_provider.dart';
import 'package:block_app/core/network/api/api_client.dart';

class NodeApi {
  NodeApi({required ConnectionProvider connectionProvider})
      : _client = ApiClient(connectionProvider: connectionProvider);

  final ApiClient _client;

  Future<Map<String, dynamic>> getSignature() {
    return _client.postToBridge(
      protocol: 'open',
      routing: '/node/signature',
      data: const {},
    );
  }
}
