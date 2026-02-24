// 公共格式化工具：BID、日期、URL

/// 将长字符串（如 BID）格式化为固定前后段显示
String formatBid(String bid) {
  const visible = 4;
  if (bid.length <= visible * 2) {
    return bid;
  }
  final prefix = bid.substring(0, visible);
  final suffix = bid.substring(bid.length - visible);
  return '$prefix...$suffix';
}

/// 将日期格式化为 yyyy-MM-dd
String formatDate(DateTime? date, {String fallback = ''}) {
  if (date == null) {
    return fallback;
  }
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// 规范化 URL（可去协议，过长时尾部省略）
String formatUrl(String? url, {int maxLength = 30, bool stripProtocol = true, String fallback = ''}) {
  if (url == null) {
    return fallback;
  }
  var value = url.trim();
  if (value.isEmpty) {
    return fallback;
  }
  if (stripProtocol) {
    value = value.replaceFirst(RegExp(r'^https?://'), '');
  }
  if (value.length <= maxLength || maxLength <= 3) {
    return value;
  }
  return '${value.substring(0, maxLength - 3)}...';
}
