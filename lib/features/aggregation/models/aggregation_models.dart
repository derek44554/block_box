/// 聚集页面的数据模型定义
class AggregationItem {
  const AggregationItem({
    required this.id,
    required this.title,
    required this.model,
    this.count = 0,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String model; // model类型ID
  final int count; // 项中的块数量
  final List<String> tags; // 标签列表

  AggregationItem copyWith({
    String? id,
    String? title,
    String? model,
    int? count,
    List<String>? tags,
  }) {
    return AggregationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      model: model ?? this.model,
      count: count ?? this.count,
      tags: tags ?? this.tags,
    );
  }

  factory AggregationItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>?;
    return AggregationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      model: json['model'] as String,
      count: json['count'] as int? ?? 0,
      tags: rawTags?.map((tag) => tag.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'model': model,
        'count': count,
        'tags': tags,
      };

}

