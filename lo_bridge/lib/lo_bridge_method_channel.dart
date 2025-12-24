import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lo_bridge_platform_interface.dart';

/// An implementation of [LoBridgePlatform] that uses method channels.
class MethodChannelLoBridge extends LoBridgePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('lo_bridge');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
