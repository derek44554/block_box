/// 操作结果封装
sealed class Result<T> {
  const Result();
}

/// 成功结果
class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

/// 失败结果
class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
  
  String get message {
    if (error is Exception) {
      return error.toString();
    }
    return error.toString();
  }
}

/// Result 扩展方法
extension ResultExtensions<T> on Result<T> {
  /// 是否成功
  bool get isSuccess => this is Success<T>;
  
  /// 是否失败
  bool get isFailure => this is Failure<T>;
  
  /// 获取数据（如果成功）
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  
  /// 获取错误（如果失败）
  Object? get errorOrNull => this is Failure<T> ? (this as Failure<T>).error : null;
  
  /// 映射数据
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final data) => Success(transform(data)),
      Failure(error: final error, stackTrace: final stackTrace) => 
        Failure(error, stackTrace),
    };
  }
  
  /// 处理结果
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error) failure,
  }) {
    return switch (this) {
      Success(data: final data) => success(data),
      Failure(error: final error) => failure(error),
    };
  }
}
