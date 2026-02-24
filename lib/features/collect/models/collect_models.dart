/// 收藏页面的数据模型定义
class CollectTag {
  const CollectTag({required this.name});

  final String name;

  CollectTag copyWith({String? name}) => CollectTag(name: name ?? this.name);

  factory CollectTag.fromJson(Map<String, dynamic> json) {
    return CollectTag(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'name': name};
}

class CollectItem {
  const CollectItem({required this.name, required this.bid});

  final String name;
  final String bid;

  CollectItem copyWith({String? name, String? bid}) {
    return CollectItem(
      name: name ?? this.name,
      bid: bid ?? this.bid,
    );
  }

  factory CollectItem.fromJson(Map<String, dynamic> json) {
    return CollectItem(
      name: json['name'] as String,
      bid: json['bid'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'bid': bid,
      };
}

class CollectEntry {
  const CollectEntry({
    required this.id,
    required this.title,
    this.items = const [],
  });

  final String id;
  final String title;
  final List<CollectItem> items;

  CollectEntry copyWith({
    String? id,
    String? title,
    List<CollectItem>? items,
  }) {
    return CollectEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  factory CollectEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    return CollectEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      items: rawItems == null
          ? const []
          : rawItems
              .map((item) => CollectItem.fromJson(item as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((item) => item.toJson()).toList(),
      };
}
