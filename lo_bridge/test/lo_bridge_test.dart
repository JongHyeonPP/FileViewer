import 'package:flutter_test/flutter_test.dart';
import 'package:lo_bridge/lo_bridge.dart';
import 'package:lo_bridge/lo_bridge_platform_interface.dart';
import 'package:lo_bridge/lo_bridge_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLoBridgePlatform
    with MockPlatformInterfaceMixin
    implements LoBridgePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LoBridgePlatform initialPlatform = LoBridgePlatform.instance;

  test('$MethodChannelLoBridge is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLoBridge>());
  });

  test('getPlatformVersion', () async {
    LoBridge loBridgePlugin = LoBridge();
    MockLoBridgePlatform fakePlatform = MockLoBridgePlatform();
    LoBridgePlatform.instance = fakePlatform;

    expect(await loBridgePlugin.getPlatformVersion(), '42');
  });
}
