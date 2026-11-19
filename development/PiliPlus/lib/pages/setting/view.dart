import 'package:PiliPlus/common/widgets/clean_shell.dart';
import 'package:PiliPlus/common/widgets/canvas_dialog.dart';
import 'package:PiliPlus/pages/setting/storage_view.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/canvas/data.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/catalog.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// WebTV-style category rail and bounded content panel. This retains the
/// original user-setting models, with inline keyword and enum editors.
class SettingPage extends StatefulWidget {
  const SettingPage({super.key, this.onLoggedOut});
  final VoidCallback? onLoggedOut;
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late final groups = canvasSettingsCatalog();
  String selected = '通用';
  String? preview, expanded;
  bool? lastWide;
  bool loggingOut = false;
  ThemeType theme = Pref.themeType;
  ThemeType? themePreview;
  final themeKeys = <ThemeType, GlobalKey>{};
  final keys = <String, GlobalKey>{};
  static const icons = {
    '通用': Icons.settings,
    '播放': Icons.play_circle_outline,
    '画质与音质': Icons.tune,
    '手势': Icons.touch_app_outlined,
    '推荐过滤': Icons.filter_alt_outlined,
    '评论': Icons.comment_outlined,
    '弹幕': Icons.subtitles_outlined,
    '存储': Icons.storage_outlined,
    '隐私与屏蔽': Icons.block,
  };
  void choose(String value) => setState(() {
    selected = value;
    preview = null;
    expanded = null;
    revealSelected();
  });
  void revealSelected() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = keys[selected]?.currentContext;
    if (mounted && target != null)
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 180),
        alignment: .5,
      );
  });
  void hover(Offset global) {
    String? target;
    for (final name in groups.keys) {
      final box = keys[name]?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).contains(global)) {
        target = name;
        break;
      }
    }
    setState(() => preview = target);
  }

  Future<void> chooseTheme(ThemeType value) async {
    await GStorage.setting.put(SettingBoxKey.themeMode, value.index);
    if (mounted)
      setState(() {
        theme = value;
        themePreview = null;
      });
    Get.changeThemeMode(ThemeUtils.themeMode = value.toThemeMode);
  }

  void hoverTheme(Offset global) {
    ThemeType? value;
    for (final entry in themeKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).contains(global)) {
        value = entry.key;
        break;
      }
    }
    setState(() => themePreview = value);
  }

  Widget themeCard(ThemeType value) {
    final dark = value == ThemeType.dark;
    return SizedBox(
      key: themeKeys.putIfAbsent(value, GlobalKey.new),
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => chooseTheme(value),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 105,
              width: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (themePreview ?? theme) == value
                      ? const Color(0xFFFB7299)
                      : Theme.of(context).dividerColor,
                  width: (themePreview ?? theme) == value ? 2 : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: value == ThemeType.system
                      ? [const Color(0xFFF2F1F4), const Color(0xFF282832)]
                      : dark
                      ? [const Color(0xFF282832), const Color(0xFF282832)]
                      : [const Color(0xFFF3F3F6), const Color(0xFFF3F3F6)],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Transform.rotate(
                      angle: -.06,
                      child: Container(
                        width: 70,
                        height: 76,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF3B3B47) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x17000000),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 5,
                              color: const Color(0xFFFB9CB8),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 5,
                              color: dark
                                  ? const Color(0xFF626170)
                                  : const Color(0xFFE5E2E8),
                            ),
                            const SizedBox(height: 7),
                            Container(
                              width: 34,
                              height: 5,
                              color: dark
                                  ? const Color(0xFF626170)
                                  : const Color(0xFFE5E2E8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if ((themePreview ?? theme) == value)
                    const Positioned(
                      top: 7,
                      right: 7,
                      child: Icon(
                        Icons.check_circle,
                        size: 19,
                        color: Color(0xFFFB7299),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            value.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget item(SettingsModel model) {
    if (model is PopupModel) {
      final title = model.effectiveTitle;
      final current = model.value();
      return Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(expanded == title ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: () =>
                setState(() => expanded = expanded == title ? null : title),
          ),
          if (expanded == title)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in model.items)
                    ChoiceChip(
                      label: Text(value.label),
                      selected: current == value,
                      onSelected: (_) {
                        model.onSelected(value, () {
                          if (mounted) setState(() {});
                        });
                        setState(() => expanded = null);
                      },
                    ),
                ],
              ),
            ),
        ],
      );
    }
    return model.widget;
  }

  Widget nav(bool wide) => GestureDetector(
    onPanDown: (e) => hover(e.globalPosition),
    onPanUpdate: (e) => hover(e.globalPosition),
    onPanEnd: (_) {
      if (preview != null)
        choose(preview!);
      else
        setState(() => preview = null);
    },
    onPanCancel: () => setState(() => preview = null),
    child: wide
        ? Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [for (final name in groups.keys) navButton(name)],
                  ),
                ),
              ),
              logoutButton(),
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in groups.keys) navButton(name),
                logoutButton(),
              ],
            ),
          ),
  );
  Widget navButton(String name) => Container(
    key: keys.putIfAbsent(name, GlobalKey.new),
    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: InkWell(
      onTap: () => choose(name),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 152,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (preview ?? selected) == name
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .1)
              : null,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              icons[name],
              size: 19,
              color: (preview ?? selected) == name
                  ? const Color(0xFFFB7299)
                  : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: (preview ?? selected) == name
                    ? const Color(0xFFFB7299)
                    : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> logout() async {
    if (loggingOut ||
        !await canvasConfirm(
          context,
          title: '退出当前账号？',
          message: '退出后可重新登录。',
          action: '退出登录',
        ))
      return;
    if (!mounted) return;
    setState(() => loggingOut = true);
    try {
      await CanvasData.logout();
      widget.onLoggedOut?.call();
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  Widget logoutButton() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: TextButton(
      onPressed: Accounts.main.isLogin ? logout : null,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout, size: 18),
          SizedBox(width: 10),
          Text('退出登录'),
        ],
      ),
    ),
  );
  Widget content() => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: ListView(
        key: PageStorageKey('settings:$selected'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            selected,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          if (selected == '存储') const StorageManagement(),
          if (selected == '通用') ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                '外观主题',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            GestureDetector(
              onHorizontalDragStart: (e) => hoverTheme(e.globalPosition),
              onHorizontalDragUpdate: (e) => hoverTheme(e.globalPosition),
              onHorizontalDragEnd: (_) {
                if (themePreview != null) chooseTheme(themePreview!);
              },
              onHorizontalDragCancel: () => setState(() => themePreview = null),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final value in ThemeType.values) themeCard(value),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (selected == '隐私与屏蔽') ...[
            Obx(
              () => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('无痕模式'),
                value: MineController.anonymity.value,
                onChanged: (_) async {
                  await MineController.onChangeAnonymity();
                  await GStorage.setting.put(
                    'canvasIncognito',
                    MineController.anonymity.value,
                  );
                },
              ),
            ),
            ListTile(
              title: const Text('黑名单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => CleanShell.showRoute('/blackListPage'),
            ),
          ],
          for (final model in groups[selected]!)
            KeyedSubtree(
              key: ValueKey('$selected:${model.effectiveTitle}'),
              child: item(model),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    child: LayoutBuilder(
      builder: (_, size) {
        final wide = size.maxWidth >= 720;
        if (lastWide != wide) {
          lastWide = wide;
          revealSelected();
        }
        return wide
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 166, child: nav(true)),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: .35),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: content()),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: .35),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: nav(false),
                  ),
                  Expanded(child: content()),
                ],
              );
      },
    ),
  );
}
