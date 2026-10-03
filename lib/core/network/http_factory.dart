import 'package:dio/dio.dart';

const kDefaultUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

Dio createDio({
  String? userAgent,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 30),
  ResponseType responseType = ResponseType.plain,
  int maxRetry = 2,
  Duration retryDelay = const Duration(milliseconds: 800),
}) {
  final dio = Dio(BaseOptions(
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    responseType: responseType,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      options.headers['User-Agent'] ??= userAgent ?? kDefaultUserAgent;
      handler.next(options);
    },
    onError: (e, handler) async {
      if (maxRetry <= 0) return handler.next(e);
      final attempt = (e.requestOptions.extra['retry'] ?? 0) as int;
      if (attempt >= maxRetry) return handler.next(e);
      e.requestOptions.extra['retry'] = attempt + 1;
      await Future<void>.delayed(retryDelay);
      try {
        final res = await dio.fetch(e.requestOptions);
        return handler.resolve(res);
      } catch (_) {
        return handler.next(e);
      }
    },
  ));
  return dio;
}