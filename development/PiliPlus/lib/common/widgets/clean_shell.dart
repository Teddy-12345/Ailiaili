import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:PiliPlus/utils/storage.dart';

import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/history/view.dart';
import 'package:PiliPlus/pages/fav/view.dart';
import 'package:PiliPlus/pages/download/download/view.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/pages/search_result/view.dart';
import 'package:PiliPlus/router/app_pages.dart';

class CleanShell extends StatefulWidget {
  const CleanShell({super.key, required this.child});
  final Widget child;
  static final route = '/'.obs;
  static final handlers =
      <String, ({Object owner, ValueChanged<String> submit})>{};
  static void Function(Widget, String)? present;
  static void showRoute(String name) {
    final page = Routes.getPages.firstWhere((p) => p.name == name);
    present?.call(page.page(), name);
  }

  @override
  State<CleanShell> createState() => _CleanShellState();
}

class _CleanShellState extends State<CleanShell> {
  bool open = false;
  String selected = '/';
  final Map<String, Widget> panels = {};
  final builders = <String, Widget Function()>{
    '/mine': () => const MinePage(),
    '/history': () => const HistoryPage(),
    '/fav': () => const FavPage(),
    '/download': () => const DownloadPage(),
    '/setting': () => const SettingPage(),
  };
  @override
  void initState() {
    super.initState();
    CleanShell.present = present;
  }

  @override
  void dispose() {
    CleanShell.present = null;
    super.dispose();
  }

  void present(Widget panel, String key) {
    setState(() {
      panels[key] = panel;
      selected = key;
    });
    CanvasBody.present?.call(panel, key);
  }

  void go(String key) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (CleanShell.route.value != '/') Get.until((r) => r.isFirst);
    setState(() {
      selected = key;
      if (key != '/') panels.putIfAbsent(key, builders[key]!);
    });
    CanvasBody.present?.call(key == '/' ? null : panels[key], key);
  }

  void submit(String text) {
    final keyword = text.trim();
    if (keyword.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (Pref.recordSearchHistory && !MineController.anonymity.value) {
      final history = List<String>.from(
        GStorage.historyWord.get('cacheList') ?? const <String>[],
      );
      history
        ..remove(keyword)
        ..insert(0, keyword);
      GStorage.historyWord.put('cacheList', history.take(50).toList());
    }
    present(
      SearchResultPage(key: ValueKey(keyword), keyword: keyword),
      '/results',
    );
  }

  Widget icon(String asset, IconData fallback, Color color) => asset.isEmpty
      ? Icon(fallback, size: 24, color: color)
      : SvgPicture.asset(
          'assets/images/shell/$asset.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
  Widget nav(String label, String key, String asset, IconData fallback) =>
      SizedBox(
        width: 64,
        height: 56,
        child: Center(
          child: IconButton(
            tooltip: label,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => go(key),
            icon: icon(
              asset,
              fallback,
              selected == key
                  ? const Color(0xFFFB7299)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Obx(() {
    final route = CleanShell.route.value;
    final video =
        route.startsWith('/videoV') ||
        route == '/pgc' ||
        route == '/horizontalVideo';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      child: SafeArea(
        top: !video,
        bottom: !video,
        left: !video,
        right: !video,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              width: video ? 0 : (open ? 64 : 48),
              color: dark ? const Color(0xFF252629) : const Color(0xFFF1F2F3),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: open ? 64 : 48,
                  maxWidth: open ? 64 : 48,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 64,
                        child: Center(
                          child: IconButton(
                            tooltip: '菜单',
                            onPressed: () => setState(() => open = !open),
                            icon: SvgPicture.asset(
                              'assets/images/shell/menu.svg',
                              width: 26,
                              height: 26,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFFB7299),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (open) ...[
                        nav('首页', '/', 'home', Icons.home),
                        nav('个人', '/mine', '', Icons.person),
                        nav('历史', '/history', 'clock', Icons.history),
                        nav('收藏', '/fav', 'folder', Icons.folder),
                        nav('缓存', '/download', 'download', Icons.download),
                      ],
                      const Spacer(),
                      if (open) nav('设置', '/setting', '', Icons.settings),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  if (selected == '/' && route == '/')
                    SizedBox(
                      height: 64,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: RawAutocomplete<String>(
                            optionsBuilder: (value) async {
                              final term = value.text.trim();
                              if (term.isEmpty) return const <String>[];
                              final local = List<String>.from(
                                GStorage.historyWord.get('cacheList') ??
                                    const <String>[],
                              ).where((s) => s.contains(term));
                              await Future<void>.delayed(
                                const Duration(milliseconds: 250),
                              );
                              try {
                                final result = await SearchHttp.searchSuggest(
                                  term: term,
                                );
                                if (result case Success(:final response))
                                  return {
                                    ...local,
                                    ...?response.tag
                                        ?.map((e) => e.term)
                                        .whereType<String>(),
                                  }.take(8).toList();
                              } catch (_) {}
                              return local.take(8).toList();
                            },
                            onSelected: submit,
                            fieldViewBuilder: (context, ctr, focus, onSubmit) =>
                                TextField(
                                  controller: ctr,
                                  focusNode: focus,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: submit,
                                  decoration: InputDecoration(
                                    hintText: null,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Color(0xFFFB7299),
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () => submit(ctr.text),
                                    ),
                                  ),
                                ),
                            optionsViewBuilder: (context, select, options) =>
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 420,
                                      child: ListView(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        children: [
                                          for (final text in options)
                                            ListTile(
                                              title: Text(text),
                                              onTap: () => select(text),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  });
}

class ShellOverlay extends StatefulWidget {
  const ShellOverlay({super.key, required this.child});
  final Widget child;
  @override
  State<ShellOverlay> createState() => _ShellOverlayState();
}

class _ShellOverlayState extends State<ShellOverlay> {
  late final OverlayEntry entry;
  @override
  void initState() {
    super.initState();
    entry = OverlayEntry(builder: (_) => CleanShell(child: widget.child));
  }

  @override
  void didUpdateWidget(ShellOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  @override
  void dispose() {
    entry.remove();
    entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [entry]);
}

class CanvasBody extends StatefulWidget {
  const CanvasBody({super.key, required this.home});
  final Widget home;
  static void Function(Widget?, String)? present;
  @override
  State<CanvasBody> createState() => _CanvasBodyState();
}

class _CanvasBodyState extends State<CanvasBody> {
  final Map<String, Widget> panels = {};
  String selected = '/';
  @override
  void initState() {
    super.initState();
    CanvasBody.present = (panel, key) {
      if (!mounted) return;
      setState(() {
        if (panel != null) panels[key] = panel;
        selected = key;
      });
    };
  }

  @override
  void dispose() {
    CanvasBody.present = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = panels.keys.toList();
    final index = selected == '/' ? 0 : keys.indexOf(selected) + 1;
    return IndexedStack(
      index: index,
      children: [
        widget.home,
        ...keys.map(
          (key) => KeyedSubtree(key: ValueKey(key), child: panels[key]!),
        ),
      ],
    );
  }
}
