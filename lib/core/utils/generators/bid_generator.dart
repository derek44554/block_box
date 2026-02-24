import 'dart:math';

/// 生成一个基于节点BID的BID（节点BID前10个字符 + 11字节随机字符串）。
/// 
/// 这是新的BID生成规则，需要节点BID作为前缀。
/// 
/// [nodeBid] 节点的BID，将取其前10个字符作为前缀
/// 返回 21个字符的十六进制字符串（10个字符前缀 + 11字节随机字符串）
String generateBidV2(String nodeBid) {
  if (nodeBid.length < 10) {
    throw ArgumentError('节点BID长度不足10个字符: $nodeBid');
  }
  
  final prefix = nodeBid.substring(0, 10);
  final random = Random.secure();
  final buffer = StringBuffer();
  
  // 生成11字节的随机字符串（22个十六进制字符）
  for (var i = 0; i < 11; i++) {
    final value = random.nextInt(256);
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  
  return '$prefix${buffer.toString()}';
}
