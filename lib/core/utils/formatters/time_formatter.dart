// 封装时间格式化工具，统一输出带时区偏移的 ISO8601 字符串。

String nowIso8601WithOffset() => iso8601WithOffset(DateTime.now());

String iso8601WithOffset(DateTime dateTime) {
  final local = dateTime.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';

  String twoDigits(int value) => value.abs().toString().padLeft(2, '0');

  final datePart = '${local.year.toString().padLeft(4, '0')}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  final timePart = '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';

  final hours = twoDigits(offset.inHours);
  final minutes = twoDigits(offset.inMinutes.remainder(60));

  return '$datePart' 'T' '$timePart$sign$hours:$minutes';
}
