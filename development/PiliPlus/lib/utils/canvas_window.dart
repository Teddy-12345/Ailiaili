import 'dart:io';

import 'package:flutter/services.dart';

abstract final class CanvasWindow {
  static Future<void> apply() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel('bili/window').invokeMethod<void>('apply');
    } on MissingPluginException {
      /* Widget tests. */
    }
  }
}
