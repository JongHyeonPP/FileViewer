import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'lo_bridge_method_channel.dart';

abstract class LoBridgePlatform extends PlatformInterface {
  /// Constructs a LoBridgePlatform.
  LoBridgePlatform() : super(token: _token);

  static final Object _token = Object();

  static LoBridgePlatform _instance = MethodChannelLoBridge();

  /// The default instance of [LoBridgePlatform] to use.
  ///
  /// Defaults to [MethodChannelLoBridge].
  static LoBridgePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LoBridgePlatform] when
  /// they register themselves.
  static set instance(LoBridgePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
