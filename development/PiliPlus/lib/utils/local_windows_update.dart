import 'package:PiliPlus/utils/app_updates.dart';

/// Compatibility entry: all behavior is implemented in AppUpdates.
abstract final class LocalWindowsUpdate {
  static Future<void> check({bool automatic = true}) => AppUpdates.check(automatic: automatic);
}
