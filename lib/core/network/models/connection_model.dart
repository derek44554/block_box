class ConnectionModel {
  const ConnectionModel({
    required this.name,
    required this.address,
    required this.keyBase64,
    required this.status,
    this.nodeData,
    this.isActive = false,
    this.enableIpfsStorage = false,
    this.ipfsUploadPassword,
  });

  final String name;
  final String address;
  final String keyBase64;
  final ConnectionStatus status;
  final Map<String, dynamic>? nodeData;
  final bool isActive;
  final bool enableIpfsStorage;
  final String? ipfsUploadPassword;

  ConnectionModel copyWith({
    String? name,
    String? address,
    String? keyBase64,
    ConnectionStatus? status,
    Map<String, dynamic>? nodeData,
    bool clearNodeData = false,
    bool? isActive,
    bool? enableIpfsStorage,
    String? ipfsUploadPassword,
    bool clearIpfsUploadPassword = false,
  }) {
    final resolvedNodeData = clearNodeData
        ? null
        : (nodeData != null
            ? Map<String, dynamic>.from(nodeData)
            : (this.nodeData != null ? Map<String, dynamic>.from(this.nodeData!) : null));

    return ConnectionModel(
      name: name ?? this.name,
      address: address ?? this.address,
      keyBase64: keyBase64 ?? this.keyBase64,
      status: status ?? this.status,
      nodeData: resolvedNodeData,
      isActive: isActive ?? this.isActive,
      enableIpfsStorage: enableIpfsStorage ?? this.enableIpfsStorage,
      ipfsUploadPassword: clearIpfsUploadPassword ? null : (ipfsUploadPassword ?? this.ipfsUploadPassword),
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
      enableIpfsStorage: json['enableIpfsStorage'] as bool? ?? false,
      ipfsUploadPassword: json['ipfsUploadPassword'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'keyBase64': keyBase64,
      'status': status.index,
      'nodeData': nodeData,
      'isActive': isActive,
      'enableIpfsStorage': enableIpfsStorage,
      'ipfsUploadPassword': ipfsUploadPassword,
    };
  }
}

enum ConnectionStatus { connected, connecting, offline }
