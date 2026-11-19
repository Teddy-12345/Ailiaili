import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class NoteHistoryPage extends StatefulWidget {
  const NoteHistoryPage({super.key});
  static final revision = 0.obs;
  static String get storageKey => 'read_notes_${Accounts.main.mid}';
  static void record(String url, String title) {
    if (MineController.anonymity.value) return;
    if (GStorage.localCache.get(
          LocalCacheKey.historyPause,
          defaultValue: false,
        ) ==
        true)
      return;
    final rows = List<Map>.from(
      GStorage.localCache.get(storageKey) ?? const <Map>[],
    );
    rows.removeWhere((r) => r['url'] == url);
    rows.insert(0, {'url': url, 'title': title});
    GStorage.localCache.put(storageKey, rows.take(200).toList());
    revision.value++;
  }

  @override
  State<NoteHistoryPage> createState() => _NoteHistoryPageState();
}

class _NoteHistoryPageState extends State<NoteHistoryPage> {
  @override
  Widget build(BuildContext context) => Obx(() {
    NoteHistoryPage.revision.value;
    final rows = List<Map>.from(
      GStorage.localCache.get(NoteHistoryPage.storageKey) ?? const <Map>[],
    );
    if (rows.isEmpty) return const Center(child: Text('暂无笔记阅读记录'));
    return ListView(
      children: [
        for (final row in rows)
          ListTile(
            title: Text(row['title'] as String),
            onTap: () =>
                PageUtils.handleWebview(row['url'] as String, inApp: true),
          ),
      ],
    );
  });
}
