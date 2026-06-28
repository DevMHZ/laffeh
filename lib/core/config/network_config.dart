/// HTTP client tuning shared by every Dio instance.
class NetworkConfig {
  NetworkConfig._();

  /// Connect / receive / send timeout. The AI request can take a while,
  /// so this is generous.
  static const Duration timeout = Duration(seconds: 60);
}
