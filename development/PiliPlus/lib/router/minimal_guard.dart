import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Removed feature deep links return to the video home instead of loading them.
class MinimalRouteGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) => const RouteSettings(name: '/');
}
