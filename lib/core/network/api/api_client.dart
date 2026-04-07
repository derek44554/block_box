import 'package:block_app/state/connection_provider.dart';
import 'package:block_flutter/block_flutter.dart' as sdk;

/// ApiClient handles all HTTP requests to the Block backend. All requests use the
/// unified `/bridge/ins` route, even when the payload indicates different protocols or routings.
///
/// This is a thin adapter that delegates to the SDK's ApiClient.
class ApiClient {
  ApiClient({required ConnectionProvider connectionProvider}) : _connectionProvider = connectionProvider;

  final ConnectionProvider _connectionProvider;

  /// Performs a POST request to the `/bridge/ins` endpoint using the active connection's address.
  /// The request body is encrypted with AES-CBC (PKCS7 padding) and base64-encoded, matching the backend expectations.
  Future<Map<String, dynamic>> postToBridge({
    required String routing,
    required Map<String, dynamic> data,
    String protocol = 'cert',
    String receiver = '',
    bool wait = true,
    int timeout = 60,
    String? receiverBid,
  }) async {
    final connection = _connectionProvider.activeConnection;
    if (connection == null) {
      throw StateError('No active connection available. Cannot perform request.');
    }
    return sdk.ApiClient(connection: connection).postToBridge(
      routing: routing,
      data: data,
      protocol: protocol,
      receiver: receiver,
      wait: wait,
      timeout: timeout,
      receiverBid: receiverBid,
    );
  }
}
