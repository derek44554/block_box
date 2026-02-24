class BlockModel {
  const BlockModel({required this.data});

  final Map<String, dynamic> data;

  T? get<T>(String key) {
    final value = data[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  String getString(String key, {String fallback = ''}) {
    final value = data[key];
    if (value is String) {
      return value;
    }
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  int getInt(String key, {int fallback = 0}) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  double getDouble(String key, {double fallback = 0}) {
    final value = data[key];
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  bool getBool(String key, {bool fallback = false}) {
    final value = data[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return fallback;
  }

  DateTime? getDateTime(String key) {
    final value = data[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  List<T> getList<T>(String key) {
    final value = data[key];
    if (value is List) {
      return value.whereType<T>().toList();
    }
    return <T>[];
  }

  Map<String, dynamic> getMap(String key) {
    final value = data[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    return <String, dynamic>{};
  }

  String call(String key, {String fallback = ''}) => getString(key, fallback: fallback);

  String? maybeString(String key, {bool trim = true}) {
    var value = getString(key);
    if (trim) {
      value = value.trim();
    }
    return value.isEmpty ? null : value;
  }

  bool? maybeBool(String key) {
    final value = data[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  int? maybeInt(String key) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  List<T> list<T>(String key) => getList<T>(key);

  Map<String, dynamic> map(String key) => getMap(key);

  T? value<T>(String key) => get<T>(key);

  bool has(String key, {bool allowEmptyString = false}) {
    if (!data.containsKey(key)) return false;
    final value = data[key];
    if (value == null) return false;
    if (!allowEmptyString && value is String && value.trim().isEmpty) {
      return false;
    }
    return true;
  }

  // Convenience properties
  
  /// 获取 Block 类型 ID
  String? get typeId => maybeString('model');
  
  /// 获取 BID
  String? get bid => maybeString('bid');
  
  /// 获取标题
  String? get title => maybeString('name');
  
  /// 获取简介
  String? get intro => maybeString('intro');
  
  /// 获取创建时间
  DateTime? get createdAt => getDateTime('created_at');
  
  /// 获取更新时间
  DateTime? get updatedAt => getDateTime('updated_at');
  
  /// 复制并更新字段
  BlockModel copyWith(Map<String, dynamic> updates) {
    return BlockModel(data: {...data, ...updates});
  }
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() => data;
}
