import 'dart:io';
import 'dart:ui' as ui;
import 'package:PiliPlus/common/widgets/canvas_dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/login/view.dart';
import 'package:PiliPlus/pages/setting/storage_view.dart';
import 'package:PiliPlus/utils/cache_manager.dart' as app;
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

class LocalLogin extends LoginPageController {
  @override
  Future<void> refreshQRCode() async {
    codeInfo.value = const Success((authCode: 'test-only', url: 'https://example.invalid/qr'));
    qrCodeLeftTime.value = 180;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('bili-canvas-v8-tests-');
    appSupportDirPath = root.path;
    downloadPath = '${root.path}/downloads';
    Hive.init(root.path);
    GStorage.setting = await Hive.openBox('v8-settings');
    app.CacheManager.manager = await DefaultCacheManager.init(cacheDirectoryProvider: () async => root, maxNrOfCacheLength: 1024 * 1024 * 1024);
  });
  tearDownAll(() async {
    await app.CacheManager.manager.dispose();
    await Hive.close();
    if (!root.path.startsWith(Directory.systemTemp.path) || !root.path.contains('bili-canvas-v8-tests-')) throw StateError('Unexpected test root');
    await root.delete(recursive: true);
  });
  ThemeData theme() => ThemeUtils.getThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFB7299)), isDynamic: false);
  final boundary = GlobalKey();
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await render.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory('preview/v8').create(recursive: true);
      await File('preview/v8/$name.png').writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    });
  }
  test('live cache capacity guards shrinking and bounds new writes', () async {
    final manager = app.CacheManager.manager;
    await manager.emptyCache();
    manager.setCapacity(20);
    await manager.putFile('https://example.invalid/one', List.filled(8, 1));
    expect(() => manager.setCapacity(7), throwsStateError);
    await manager.putFile('https://example.invalid/two', List.filled(8, 2));
    await manager.putFile('https://example.invalid/three', List.filled(8, 3));
    expect(manager.getTotalLength(), lessThanOrEqualTo(20));
    expect(await manager.getFileFromCache('https://example.invalid/one'), isNull);
    expect(await manager.getFileFromCache('https://example.invalid/three'), isNotNull);
    await manager.emptyCache();
    expect(manager.getTotalLength(), 0);
    manager.setCapacity(1024 * 1024 * 1024);
  });
  testWidgets('login fields, password reset, compact QR and responsive centering', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final login = Get.put<LoginPageController>(LocalLogin());
    await tester.pumpWidget(GetMaterialApp(theme: theme(), home: RepaintBoundary(key: boundary, child: const LoginPage())));
    await tester.pumpAndSettle();
    expect(find.text('Cookie'), findsNothing);
    expect(find.text('忘记密码'), findsNothing);
    expect(find.byTooltip('显示密码'), findsNothing);
    expect(find.byTooltip('清空账户'), findsNothing);
    final fields = find.byType(TextField).hitTestable();
    await tester.enterText(fields.first, 'example');
    await tester.enterText(fields.last, 'example-password');
    await tester.pump();
    expect(find.byTooltip('清空账户'), findsOneWidget);
    expect(find.byTooltip('显示密码'), findsOneWidget);
    await tester.tap(find.byTooltip('显示密码')); await tester.pump();
    expect(tester.widget<TextField>(fields.last).obscureText, false);
    await tester.tap(find.byTooltip('清空密码')); await tester.pump();
    await tester.enterText(fields.last, 'next');
    expect(tester.widget<TextField>(fields.last).obscureText, true);
    await capture(tester, 'password-landscape');
    login.tabController.animateTo(1); await tester.pumpAndSettle();
    await capture(tester, 'sms-landscape');
    login.tabController.animateTo(2); await tester.pumpAndSettle();
    expect(find.text('180秒'), findsOneWidget);
    expect(find.textContaining('使用 bilibili'), findsNothing);
    await capture(tester, 'qr-landscape');
    login.tabController.animateTo(0); await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(430, 860); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'password-portrait');
    tester.view.viewInsets = const FakeViewPadding(bottom: 350); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpWidget(const SizedBox()); await tester.pumpAndSettle();
    Get.reset();
  });
  testWidgets('storage and confirmation dialog render without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1000, 760); tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MaterialApp(theme: theme(), home: RepaintBoundary(key: boundary, child: Scaffold(body: Center(child: SizedBox(width: 780, child: SingleChildScrollView(child: Column(children: [
      const StorageManagement(),
      Builder(builder: (context) => TextButton(onPressed: () => canvasConfirm(context, title: '退出当前账号？', message: '退出后可重新登录。', action: '退出登录'), child: const Text('测试弹窗'))),
    ]))))))));
    await tester.pumpAndSettle(); await capture(tester, 'storage');
    await tester.tap(find.text('测试弹窗')); await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget); expect(tester.takeException(), isNull);
    // Capture full overlay rather than the page underneath.
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/v8-dialog.png'));
    await tester.tap(find.text('取消')); await tester.pumpAndSettle();
  });
}
