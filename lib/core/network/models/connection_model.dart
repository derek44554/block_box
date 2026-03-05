class ConnectionModel {
  const ConnectionModel({
    required this.name,
    required this.address,
    required this.keyBase64,
    required this.status,
    this.nodeData,
    this.signatureData,
    this.isActive = false,
    this.enableIpfsStorage = false,
  });

  final String name;
  final String address;
  final String keyBase64;
  final ConnectionStatus status;
  final Map<String, dynamic>? nodeData;
  final Map<String, dynamic>? signatureData;
  final bool isActive;
  final bool enableIpfsStorage;

  ConnectionModel copyWith({
    String? name,
    String? address,
    String? keyBase64,
    ConnectionStatus? status,
    Map<String, dynamic>? nodeData,
    bool clearNodeData = false,
    Map<String, dynamic>? signatureData,
    bool clearSignatureData = false,
    bool? isActive,
    bool? enableIpfsStorage,
  }) {
    final resolvedNodeData = clearNodeData
        ? null
        : (nodeData != null
            ? Map<String, dynamic>.from(nodeData)
            : (this.nodeData != null ? Map<String, dynamic>.from(this.nodeData!) : null));

    final resolvedSignatureData = clearSignatureData
        ? null
        : (signatureData != null
            ? Map<String, dynamic>.from(signatureData)
            : (this.signatureData != null ? Map<String, dynamic>.from(this.signatureData!) : null));

    return ConnectionModel(
      name: name ?? this.name,
      address: address ?? this.address,
      keyBase64: keyBase64 ?? this.keyBase64,
      status: status ?? this.status,
      nodeData: resolvedNodeData,
      signatureData: resolvedSignatureData,
      isActive: isActive ?? this.isActive,
      enableIpfsStorage: enableIpfsStorage ?? this.enableIpfsStorage,
    );
  }

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    return ConnectionModel(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      keyBase64: json['keyBase64'] as String? ?? '',
      status: ConnectionStatus.values[json['status'] as int? ?? 0],
      isActive: json['isActive'] as bool? ?? false,
      nodeData: json['nodeData'] as Map<String, dynamic>?,
      signatureData: json['signatureData'] as Map<String, dynamic>?,
      enableIpfsStorage: json['enableIpfsStorage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'keyBase64': keyBase64,
      'status': status.index,
      'nodeData': nodeData,
      'signatureData': signatureData,
      'isActive': isActive,
      'enableIpfsStorage': enableIpfsStorage,
    };
  }
}

enum ConnectionStatus { connected, connecting, offline }
