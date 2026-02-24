/// API 错误
class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.code,
    this.statusCode,
  });
  
  final String message;
  final String? code;
  final int? statusCode;
  
  @override
  String toString() => 'ApiError: $message (code: $code, status: $statusCode)';
}
