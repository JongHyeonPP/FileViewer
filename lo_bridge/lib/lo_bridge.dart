import 'lo_bridge_platform_interface.dart';

class LoBridge {
  Future<String?> getPlatformVersion() {
    return LoBridgePlatform.instance.getPlatformVersion();
  }
}
