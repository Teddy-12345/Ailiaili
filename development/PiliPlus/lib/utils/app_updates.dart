import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/widgets/canvas_dialog.dart';
import 'package:PiliPlus/utils/release_signature.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// All Ailiaili platforms share startup/manual checks, dialogs and fallback.
abstract final class AppUpdates {
  static const _site = 'http://teddy-personal.cloud:22830';
  static const _phone = bool.fromEnvironment('bili.phone');
  static const _native = MethodChannel('influence/updates');
  static bool _busy = false;
  static String get _platform =>
      Platform.isWindows ? 'windows' : (_phone ? 'phone' : 'pad');
  static String get _id => 'ailiaili-$_platform';
  static String get _base => '$_site/files/ailiaili/$_platform/';

  static Future<HttpClientResponse> _request(
    HttpClient client,
    String address,
  ) async {
    final uri = Uri.parse(address);
    if (!address.startsWith(_base) && address != '$_site/updates/$_id.json') {
      throw const FormatException('Unexpected update URL');
    }
    if (uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.pathSegments.contains('..')) {
      throw const FormatException('Invalid update URL');
    }
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 12));
    request.followRedirects = false;
    request.headers.set('Cache-Control', 'no-cache');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw const HttpException('Update service unavailable');
    return response;
  }

  static Future<Uint8List> _small(HttpClient client, String address) async {
    final response = await _request(client, address);
    final bytes = BytesBuilder();
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.add(chunk);
      if (bytes.length > 65536)
        throw const FormatException('Manifest too large');
    }
    return bytes.takeBytes();
  }

  static Future<void> _website() async {
    if (!await launchUrl(
      Uri.parse('$_site/projects/ailiaili'),
      mode: LaunchMode.externalApplication,
    )) {
      SmartDialog.showToast('请使用浏览器访问 teddy-personal.cloud:22830');
    }
  }

  static Future<void> check({bool automatic = true}) async {
    if ((!Platform.isWindows && !Platform.isAndroid) || _busy) return;
    _busy = true;
    var offered = false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final raw = await _small(
        client,
        '$_base${Platform.isWindows ? 'latest.json' : 'android.json'}',
      );
      final Map<String, dynamic> release;
      if (Platform.isWindows) {
        final key = jsonDecode(
          await rootBundle.loadString('assets/update-public-key.json'),
        ) as Map<String, dynamic>;
        release = verifyWindowsRelease(raw, key);
      } else {
        release = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
        final package = _phone
            ? 'local.muhuo.piliplus.phone'
            : 'local.muhuo.piliplus.minimal';
        if (release['packageName'] != package)
          throw const FormatException('Wrong Android package');
      }
      if ((release['versionCode'] as int) <= BuildConfig.versionCode) {
        if (!automatic) SmartDialog.showToast('当前已是最新版本');
        return;
      }
      Map<String, dynamic> policy = {};
      try {
        policy = jsonDecode(
          utf8.decode(await _small(client, '$_site/updates/$_id.json')),
        ) as Map<String, dynamic>;
      } catch (_) {
        /* A policy outage never prevents a signed update check. */
      }
      if (policy['enabled'] == false) {
        if (!automatic) SmartDialog.showToast('更新提醒暂未启用');
        return;
      }
      final total = release['bytes'] as int? ?? 0;
      final mode = policy['mode'] as String? ?? 'auto';
      final limit =
          (policy['maxDirectMB'] as num? ?? 128).toInt() * 1024 * 1024;
      final website =
          mode == 'website' ||
          total <= 0 ||
          total > 512 * 1024 * 1024 ||
          (mode == 'auto' && total > limit);
      final context = Get.context;
      if (context == null || !context.mounted) return;
      final message =
          (policy['message'] as String? ?? '{product} {version}\n{notes}')
              .replaceAll('{product}', 'Ailiaili')
              .replaceAll('{version}', '${release['version']}')
              .replaceAll('{notes}', release['notes'] as String? ?? '');
      offered = true;
      final accept = await showCanvasDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(policy['title'] as String? ?? '发现新版本'),
          content: Text(
            '${message.substring(0, message.length.clamp(0, 2400))}${website ? '\n请前往网站下载新版并覆盖安装。' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(website ? '前往网站' : '下载更新'),
            ),
          ],
        ),
      );
      if (accept != true) return;
      if (website) {
        await _website();
        return;
      }
      final folder = Directory(
        '${(await getTemporaryDirectory()).path}/${Platform.isAndroid ? 'influence-updates' : 'ailiaili-updates'}',
      );
      await folder.create(recursive: true);
      final partial = File('${folder.path}/download.part');
      final installer = File(
        '${folder.path}/${Platform.isAndroid ? 'update.apk' : 'Ailiaili-setup.exe'}',
      );
      final progress = ValueNotifier<double>(0);
      if (!context.mounted) return;
      unawaited(
        showCanvasDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('正在下载更新'),
              content: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: value),
                    Text('${(value * 100).floor()}%'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      try {
        final response = await _request(client, release['url'] as String);
        final output = partial.openWrite();
        var received = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            received += chunk.length;
            if (received > total)
              throw const FormatException('Package too large');
            output.add(chunk);
            progress.value = received / total;
          }
          await output.flush();
        } finally {
          await output.close();
        }
        if (received != total ||
            (await sha256.bind(partial.openRead()).first).toString() !=
                release['sha256']) {
          throw const FormatException('Package checksum mismatch');
        }
        if (installer.existsSync()) await installer.delete();
        await partial.rename(installer.path);
      } finally {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        progress.dispose();
        if (partial.existsSync()) await partial.delete();
      }
      if (Platform.isAndroid) {
        await _native.invokeMethod<void>('install', {
          'versionCode': release['versionCode'],
          'sha256': release['sha256'],
        });
      } else {
        await Process.start(installer.path, [
          '/UPDATE',
        ], mode: ProcessStartMode.detached);
        exit(0);
      }
    } catch (_) {
      if (offered) {
        final context = Get.context;
        if (context != null && context.mounted) {
          final open = await showCanvasDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('更新未完成'),
              content: const Text('当前版本和数据保持不变，可前往网站下载新版。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('稍后'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('前往网站'),
                ),
              ],
            ),
          );
          if (open == true) await _website();
        }
      } else if (!automatic) {
        SmartDialog.showToast('暂时无法检查更新，请稍后重试');
      }
    } finally {
      client.close(force: true);
      _busy = false;
    }
  }
}
