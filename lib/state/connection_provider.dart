import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:block_app/core/network/models/connection_model.dart';
import 'package:block_app/core/network/crypto/bridge_transport.dart';

const _kConnectionsKey = 'connections';
const _kIpfsEndpointKey = 'connection_ipfs_endpoint';

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider() {
    _restore();
  }

  List<ConnectionModel> _connections = const [];
  String? _ipfsEndpoint;

  List<ConnectionModel> get connections => List.unmodifiable(_connections);
  String? get ipfsEndpoint => _ipfsEndpoint;

  ConnectionModel? get activeConnection {
    for (final connection in _connections) {
      if (connection.isActive) {
        return connection;
      }
    }
    return _connections.isNotEmpty ? _connections.first : null;
  }

  Map<String, dynamic>? get activeNodeData => activeConnection?.nodeData;

  Future<void> selectConnection(String address) async {
    _connections = _connections.map((connection) {
      final isActive = connection.address == address;
      return connection.copyWith(isActive: isActive);
    }).toList();
    await _persist();
    notifyListeners();
    unawaited(verifyConnection(address));
  }

  Future<void> addConnection(ConnectionModel connection) async {
    final updated = connection.copyWith(isActive: _connections.isEmpty, clearNodeData: true);
    _connections = [..._connections, updated];
    await _persist();
    notifyListeners();
    unawaited(verifyConnection(updated.address));
  }

  Future<void> updateConnection(ConnectionModel original, ConnectionModel updated) async {
    var targetIndex = _connections.indexWhere((connection) => identical(connection, original));
    if (targetIndex == -1) {
      targetIndex = _connections.indexWhere(
        (connection) => connection.address == original.address && connection.name == original.name,
      );
      if (targetIndex == -1) {
        return;
      }
    }

    final wasActive = _connections[targetIndex].isActive;
    final nextConnections = List<ConnectionModel>.from(_connections);
    nextConnections[targetIndex] = updated.copyWith(isActive: wasActive, clearNodeData: true);

    _connections = nextConnections;
    await _persist();
    notifyListeners();
    unawaited(verifyConnection(nextConnections[targetIndex].address));
  }

  Future<void> updateStatus(
    String address,
    ConnectionStatus status, {
    Map<String, dynamic>? nodeData,
    Map<String, dynamic>? signatureData,
  }) async {
    _connections = _connections.map((connection) {
      if (connection.address == address) {
        return connection.copyWith(
          status: status,
          nodeData: nodeData,
          signatureData: signatureData,
        );
      }
      return connection;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> removeConnection(String address) async {
    final connectionToRemove = _connections.firstWhere((c) => c.address == address);

    _connections = _connections.where((c) => c.address != address).toList();

    if (connectionToRemove.isActive && _connections.isNotEmpty) {
      _connections[0] = _connections[0].copyWith(isActive: true);
    }

    await _persist();
    notifyListeners();
  }

  Future<void> verifyConnection(String address) async {
    final connection = _findConnection(address);
    if (connection == null) {
      return;
    }

    await updateStatus(address, ConnectionStatus.connecting);
    final refreshed = _findConnection(address);
    if (refreshed == null) {
      return;
    }

    try {
      // 获取节点信息
      final nodeResponse = await BridgeTransport.post(
        connection: refreshed,
        payload: const {
          'protocol': 'open',
          'routing': '/node/node',
          'data': <String, dynamic>{},
          'receiver': '',
          'wait': true,
          'timeout': 60,
        },
      );

      await updateStatus(
        address,
        ConnectionStatus.connected,
        nodeData: nodeResponse,
      );
    } catch (error) {
      await updateStatus(address, ConnectionStatus.offline);
    }
  }

  Future<void> fetchSignature(String address) async {
    final connection = _findConnection(address);
    if (connection == null) {
      return;
    }

    try {
      final signatureResponse = await BridgeTransport.post(
        connection: connection,
        payload: const {
          'protocol': 'open',
          'routing': '/node/signature',
          'data': <String, dynamic>{},
          'receiver': '',
          'wait': true,
          'timeout': 60,
        },
      );
      
      await updateStatus(
        address,
        connection.status,
        signatureData: signatureResponse,
      );
    } catch (error) {
      // Failed to get signature
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _connections.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_kConnectionsKey, payload);
    if (_ipfsEndpoint != null && _ipfsEndpoint!.isNotEmpty) {
      await prefs.setString(_kIpfsEndpointKey, _ipfsEndpoint!);
    } else {
      await prefs.remove(_kIpfsEndpointKey);
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getStringList(_kConnectionsKey);
    if (payload == null || payload.isEmpty) {
      _connections = const [];
      notifyListeners();
      return;
    }

    _connections = payload
        .map((entry) => ConnectionModel.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();

    if (_connections.isNotEmpty && !_connections.any((connection) => connection.isActive)) {
      final first = _connections.first.copyWith(isActive: true);
      final rest = _connections.skip(1).map((connection) => connection.copyWith(isActive: false)).toList();
      _connections = [first, ...rest];
      await _persist();
    }

    _ipfsEndpoint = prefs.getString(_kIpfsEndpointKey);
    notifyListeners();
    unawaited(_verifyAllConnections());
  }

  Future<void> _verifyAllConnections() async {
    for (final connection in List<ConnectionModel>.from(_connections)) {
      unawaited(verifyConnection(connection.address));
    }
  }

  ConnectionModel? _findConnection(String address) {
    for (final connection in _connections) {
      if (connection.address == address) {
        return connection;
      }
    }
    return null;
  }

  ConnectionModel? get ipfsStorageConnection {
    for (final connection in _connections) {
      if (connection.enableIpfsStorage) {
        return connection;
      }
    }
    return null;
  }

  Future<void> updateIpfsEndpoint(String? endpoint) async {
    _ipfsEndpoint = endpoint?.trim().isEmpty == true ? null : endpoint?.trim();
    await _persist();
    notifyListeners();
  }
}
