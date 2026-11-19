import 'package:dio/dio.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/pages/history/note_history.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

typedef CanvasGet = Future<Map> Function(String, [Map<String, dynamic>?, bool]);

class CanvasData {
  CanvasData(this.get);
  final CanvasGet get;
  final covers = <String, String>{};
  final _coverRequests = <String, CancelToken>{};
  void cancelCover(String id) =>
      _coverRequests.remove(id)?.cancel('Screen inactive');
  void cancelCovers() {
    for (final token in _coverRequests.values) {
      token.cancel('Screen inactive');
    }
    _coverRequests.clear();
  }

  String image(dynamic v) {
    final s = '${v ?? ''}';
    return s.startsWith('//')
        ? 'https:$s'
        : s.replaceFirst('http://', 'https://');
  }

  Future<Map<String, dynamic>> profile(int mid, {Map? nav}) async {
    final result = await MemberHttp.memberInfo(mid: mid);
    final m = result.dataOrNull;
    final level = nav?['level_info'];
    return {
      'mid': mid,
      'name': m?.name ?? nav?['uname'] ?? '',
      'face': image(m?.face ?? nav?['face']),
      'sign': m?.sign ?? '',
      'topPhoto': image(m?.topPhoto),
      'level': m?.level ?? level?['current_level'],
      'currentExp': level?['current_exp'],
      'nextExp': level?['next_exp'],
      'vip': m?.vip?.status == 1 || nav?['vipStatus'] == 1,
      'vipLabel': m?.vip?.label?.text ?? nav?['vip_label']?['text'] ?? '大会员',
      'official': m?.official?.desc ?? '',
      if (m == null) 'notice': '部分空间资料暂未加载，请下拉重试',
    };
  }

  Future<Map> folders(int page) async {
    final data = await get(Api.userFavFolder, {
      'up_mid': Accounts.main.mid,
      'pn': page,
      'ps': 20,
    });
    final list = data['list'] as List? ?? [];
    return {
      'folders': list
          .map(
            (f) => {
              'id': f['id'],
              'title': f['title'],
              'count': f['media_count'] ?? 0,
              'cover': image(f['cover']),
              'intro': f['intro'] ?? '',
              'privacy': ((f['attr'] as int? ?? 0) & 1),
            },
          )
          .toList(),
      'more': data['has_more'] == true || data['has_more'] == 1,
    };
  }

  Future<Map> folderCover(Map args) async {
    final id = '${args['id']}';
    if (!RegExp(r'^\d+$').hasMatch(id)) throw StateError('无效收藏夹');
    if (covers.containsKey(id)) return {'cover': covers[id]};
    final token = CancelToken();
    cancelCover(id);
    _coverRequests[id] = token;
    Map data;
    try {
      final response = await Request.dio.get(
        Api.favResourceList,
        queryParameters: {
          'media_id': id,
          'pn': 1,
          'ps': 1,
          'platform': 'web',
          'order': 'mtime',
        },
        options: Options(extra: {'account': Accounts.main}),
        cancelToken: token,
      );
      if (token.isCancelled) return {'cancelled': true};
      final body = response.data;
      if (body is! Map || body['code'] != 0 || body['data'] is! Map)
        throw StateError('封面暂不可用');
      data = body['data'] as Map;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return {'cancelled': true};
      rethrow;
    } finally {
      if (identical(_coverRequests[id], token)) _coverRequests.remove(id);
    }
    final rows = data['medias'] as List? ?? [];
    final cover = image(data['info']?['cover']);
    final url = cover.isNotEmpty
        ? cover
        : rows.isNotEmpty
        ? image(rows.first['cover'])
        : '';
    covers[id] = url;
    if (covers.length > 256) covers.remove(covers.keys.first);
    return {'cover': url};
  }

  static Future<void> logout() async {
    final current = Accounts.main;
    if (current is! LoginAccount) return;
    // Always permit local sign-out, including when the network is unavailable.
    try {
      await LoginHttp.logout(current).timeout(const Duration(seconds: 8));
    } catch (_) {}
    await Accounts.deleteAll({current});
  }

  void check(LoadingState result) {
    if (!result.isSuccess) throw StateError(result.toString());
  }

  Future<Map> remove(Map args) async {
    if (!Accounts.main.isLogin) throw StateError('账号未登录');
    final rows = List<Map>.from(args['items'] as List? ?? []);
    if (rows.isEmpty || rows.length > 200) throw StateError('请选择1至200项');
    final section = args['section'], category = args['category'];
    if (section != 'history' && section != 'favorites')
      throw StateError('不支持此操作');
    final removed = <String>[], failed = <Map>[];
    if (!(section == 'favorites' && category == '专栏')) {
      final ids = rows.map((r) => '${r['id']}').toList();
      try {
        if (section == 'history' && category == '笔记') {
          final notes = List<Map>.from(
            GStorage.localCache.get(NoteHistoryPage.storageKey) ?? [],
          );
          notes.removeWhere((n) => ids.contains(n['url']));
          await GStorage.localCache.put(NoteHistoryPage.storageKey, notes);
          NoteHistoryPage.revision.value++;
        } else if (section == 'history') {
          final keys = rows.map((r) => '${r['removeKey']}').toList();
          if (keys.any(
            (k) => !RegExp(r'^(archive|article|pgc)_\d+$').hasMatch(k),
          ))
            throw StateError('记录缺少删除标识，请刷新');
          check(
            await UserHttp.delHistory(keys.join(','), account: Accounts.main),
          );
        } else if (category == '视频' && args['folder'] == null) {
          if (ids.any((id) => !RegExp(r'^\d+$').hasMatch(id)))
            throw StateError('无效收藏夹');
          check(await FavHttp.deleteFolder(mediaIds: ids.join(',')));
          for (final id in ids) {
            covers.remove(id);
          }
        } else if (category == '视频') {
          final aids = rows.map((r) => '${r['aid']}').toList();
          if (aids.any((id) => !RegExp(r'^\d+$').hasMatch(id)))
            throw StateError('无效视频');
          check(
            await FavHttp.favVideo(
              resources: aids.map((id) => '$id:2').join(','),
              delIds: '${args['folder']}',
            ),
          );
          covers.remove('${args['folder']}');
        } else if (category == '笔记') {
          if (ids.any((id) => !RegExp(r'^\d+$').hasMatch(id)))
            throw StateError('无效笔记');
          check(
            await FavHttp.delNote(isPublish: false, noteIds: ids.join(',')),
          );
        } else {
          throw StateError('不支持此分类');
        }
        return {'removed': ids, 'failed': []};
      } catch (e) {
        return {
          'removed': [],
          'failed': [
            for (final id in ids)
              {'id': id, 'message': e is StateError ? e.message : '删除失败，请重试'},
          ],
        };
      }
    }
    for (final row in rows) {
      final id = '${row['id']}';
      try {
        if (section == 'history' && category == '笔记') {
          final notes = List<Map>.from(
            GStorage.localCache.get(NoteHistoryPage.storageKey) ?? [],
          );
          notes.removeWhere((n) => n['url'] == id);
          await GStorage.localCache.put(NoteHistoryPage.storageKey, notes);
          NoteHistoryPage.revision.value++;
        } else if (section == 'history') {
          final deleteKey = '${row['removeKey']}';
          if (!RegExp(r'^(archive|article|pgc)_\d+$').hasMatch(deleteKey))
            throw StateError('记录缺少删除标识，请刷新');
          check(await UserHttp.delHistory(deleteKey, account: Accounts.main));
        } else if (category == '视频' && args['folder'] == null) {
          if (!RegExp(r'^\d+$').hasMatch(id)) throw StateError('无效收藏夹');
          check(await FavHttp.deleteFolder(mediaIds: id));
          covers.remove(id);
        } else if (category == '视频') {
          final aid = '${row['aid']}';
          if (!RegExp(r'^\d+$').hasMatch(aid)) throw StateError('无效视频');
          check(
            await FavHttp.favVideo(
              resources: '$aid:2',
              delIds: '${args['folder']}',
            ),
          );
        } else if (category == '专栏') {
          if (!RegExp(r'^\d+$').hasMatch(id)) throw StateError('无效专栏');
          check(await FavHttp.communityAction(opusId: id, action: 4));
        } else if (category == '笔记') {
          if (!RegExp(r'^\d+$').hasMatch(id)) throw StateError('无效笔记');
          check(await FavHttp.delNote(isPublish: false, noteIds: id));
        } else {
          throw StateError('不支持此分类');
        }
        removed.add(id);
      } catch (e) {
        failed.add({
          'id': id,
          'message': e is StateError ? e.message : '删除失败，请重试',
        });
      }
    }
    return {'removed': removed, 'failed': failed};
  }

  Future<Map> manage(Map args) async {
    if (!Accounts.main.isLogin) throw StateError('账号未登录');
    switch (args['action']) {
      case 'historyStatus':
        final result = await UserHttp.historyStatus(account: Accounts.main);
        check(result);
        return {'paused': result.data};
      case 'pauseHistory':
        check(
          await UserHttp.pauseHistory(
            args['paused'] == true,
            account: Accounts.main,
          ),
        );
        await GStorage.localCache.put(
          LocalCacheKey.historyPause,
          args['paused'] == true,
        );
        break;
      case 'clearHistory':
        check(await UserHttp.clearHistory(account: Accounts.main));
        await GStorage.localCache.put(NoteHistoryPage.storageKey, <Map>[]);
        NoteHistoryPage.revision.value++;
        break;
      case 'editFolder':
        final title = '${args['title'] ?? ''}'.trim();
        if (title.isEmpty || title.length > 80) throw StateError('请输入有效名称');
        final info = await FavHttp.favFolderInfo(mediaId: args['id']);
        check(info);
        check(
          await FavHttp.addOrEditFolder(
            isAdd: false,
            mediaId: args['id'],
            title: title,
            privacy: args['privacy'] == 1 ? 1 : 0,
            cover: info.data.cover,
            intro: info.data.intro ?? '',
          ),
        );
        covers.remove('${args['id']}');
        break;
      default:
        throw StateError('不支持此操作');
    }
    return {};
  }
}
