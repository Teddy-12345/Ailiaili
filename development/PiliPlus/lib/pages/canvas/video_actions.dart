import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:material_ui/material_ui.dart';

class CanvasVideoActions {
  final items = <String, RcmdVideoItemAppModel>{};
  List<Map<String, Object>> remember(RcmdVideoItemAppModel item) {
    final options = <Map<String, Object>>[];
    for (final reason in item.threePoint?.dislikeReasons ?? <Reason>[]) {
      if (reason.id == null) continue;
      final name = reason.name ?? '';
      final label = RegExp('UP|up|作者').hasMatch(name)
          ? '不感兴趣：UP'
          : RegExp('社会|关系|关联').hasMatch(name)
          ? '不感兴趣：社会关系'
          : RegExp('视频|内容|当前|不感兴趣|不想看').hasMatch(name)
          ? '不感兴趣：当前视频'
          : null;
      if (label != null && !options.any((r) => r['label'] == label))
        options.add({'id': reason.id!, 'label': label});
    }
    if (options.isNotEmpty && item.bvid != null) {
      items[item.bvid!] = item;
      if (items.length > 1000) items.remove(items.keys.first);
    }
    return options;
  }

  Future<Map> show(BuildContext context, String id) async {
    final item = items[id];
    if (item == null) return {'removed': false};
    final options = remember(item);
    if (options.isEmpty) return {'removed': false};
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const Divider(height: 1, indent: 48),
              ListTile(
                leading: Icon(
                  index == 0 ? Icons.not_interested : Icons.person_off_outlined,
                ),
                title: Text('${options[index]['label']}'),
                onTap: () => Navigator.pop(context, options[index]['id']),
              ),
            ],
          ],
        ),
      ),
    );
    if (choice == null) return {'removed': false};
    if (!Accounts.main.isLogin) throw StateError('请先登录');
    if (item.param == null ||
        item.goto == null ||
        !options.any((o) => o['id'] == choice))
      throw StateError('该操作暂不可用');
    final result = await VideoHttp.feedDislike(
      goto: item.goto!,
      id: item.param!,
      reasonId: choice,
    );
    if (!result.isSuccess) throw StateError(result.toString());
    items.remove(id);
    return {
      'removed': true,
      if (options.any((o) => o['id'] == choice && o['label'] == '不感兴趣：UP'))
        'mid': item.owner.mid,
    };
  }
}
