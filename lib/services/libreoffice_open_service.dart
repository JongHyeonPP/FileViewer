import 'package:flutter/services.dart';

class LibreOfficeOpenService {
  static const MethodChannel _channel = MethodChannel(
    'app.channel/libreoffice_open',
  );

  Future<bool> open({
    required String fileId,
    required String displayPath,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>('open', <String, dynamic>{
      'fileId': fileId,
      'displayPath': displayPath,
    });
    return ok ?? false;
  }
}
