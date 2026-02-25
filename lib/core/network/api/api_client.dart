import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:block_app/state/connection_provider.dart';
import 'package:block_app/core/network/crypto/bridge_transport.dart';

/// ApiClient handles all HTTP requests to the Block backend. All requests use the
/// unified `/bridge/ins` route, even when the payload indicates different protocols or routings.
///
/// Most requests share the same structure; the main difference lies in the contents of the `data` field.
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

    final receiverField = receiverBid != null && receiverBid.isNotEmpty ? receiverBid : receiver;

    final payload = <String, dynamic>{
      'protocol': protocol,
      'routing': routing,
      'data': data,
      'receiver': receiverField,
      'wait': wait,
      'timeout': timeout,
    };

    return BridgeTransport.post(connection: connection, payload: payload);
  }
}
