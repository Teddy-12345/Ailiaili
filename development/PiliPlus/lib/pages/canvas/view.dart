import 'dart:async';
import 'dart:convert';
import 'package:PiliPlus/pages/canvas/story.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';

import 'package:PiliPlus/common/widgets/clean_shell.dart';
import 'package:PiliPlus/pages/canvas/data.dart';
import 'package:PiliPlus/pages/canvas/video_actions.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/pages/download/download/view.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';

import 'package:PiliPlus/utils/canvas_window.dart';
import 'package:PiliPlus/pages/history/note_history.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as html;
import 'package:material_ui/material_ui.dart';

/// Bundled canvas UI, backed by the existing account/network/player services.
/// Only local application assets receive the bridge; no arbitrary URL proxy.
class BiliCanvasPage extends StatefulWidget {
  const BiliCanvasPage({super.key});
  @override
  State<BiliCanvasPage> createState() => _BiliCanvasPageState();
}

class _BiliCanvasPageState extends State<BiliCanvasPage> {
  static const origin = 'https://appassets.androidplatform.net';
  static const assetUrl =
      '$origin/assets/flutter_assets/assets/canvas/index.html?android=1';
  InAppWebViewController? web;
  bool rail = false, canBack = false;
  String section = 'home';
  Widget? detail;
  final openedPanels = <String>{};
  final downloadKey = GlobalKey<DownloadPageState>();
  late final settingsPanel = SettingPage(
    onLoggedOut: () {
      web?.evaluateJavascript(source: 'window.canvasLoggedOut?.()');
    },
  );
  late final downloadsPanel = DownloadPage(key: downloadKey, embedded: true);
  final cursors = <String, Map<String, dynamic>>{};
  StreamSubscription? settingsSubscription;
  late final dataApi = CanvasData(get);
  final videoActions = CanvasVideoActions();
  List<Map>? featured;

  @override
  void initState() {
    super.initState();
    if (!DeviceUtils.isTablet) portraitUpMode();
    settingsSubscription = GStorage.setting.watch().listen((_) {
      web?.evaluateJavascript(
        source: 'window.canvasTheme?.(${jsonEncode(Pref.themeType.name)})',
      );
    });
    CleanShell.present = (panel, _) {
      if (mounted) setState(() => detail = panel);
    };
  }

  @override
  void dispose() {
    CleanShell.present = null;
    settingsSubscription?.cancel();
    dataApi.cancelCovers();
    super.dispose();
  }

  Future<void> changed() async {
    if (!mounted) return;
    await web?.evaluateJavascript(source: 'window.canvasRefresh?.()');
  }

  String clean(dynamic value) =>
      html.parseFragment('${value ?? ''}').text ?? '';
  String image(dynamic value) {
    final s = '${value ?? ''}';
    return s.startsWith('//')
        ? 'https:$s'
        : s.replaceFirst('http://', 'https://');
  }

  Map<String, dynamic> entry(Map item) {
    final owner = item['owner'] ?? item['upper'] ?? {};
    var duration = item['duration'] ?? item['length'] ?? 0;
    if (duration is String) {
      duration = duration
          .split(':')
          .fold<int>(0, (v, s) => v * 60 + (int.tryParse(s) ?? 0));
    }
    return {
      'id':
          item['bvid'] ??
          item['bv_id'] ??
          item['history']?['bvid'] ??
          '${item['id']}',
      'title': clean(item['title']),
      'aid': item['aid'] ?? item['id'] ?? item['history']?['oid'],
      if (item['history'] != null)
        'removeKey':
            '${item['history']['business']}_${item['kid'] ?? item['history']['oid']}',
      'creator': clean(
        owner['name'] ?? item['author'] ?? item['author_name'] ?? '',
      ),
      'mid': owner['mid'] ?? item['mid'] ?? item['author_mid'],
      'duration': duration,
      'views':
          item['stat']?['view'] ??
          item['cnt_info']?['play'] ??
          item['play'] ??
          0,
      'cover': image(
        item['pic'] ?? item['cover'] ?? item['covers']?.firstOrNull,
      ),
      'description': clean(item['description'] ?? ''),
    };
  }

  Future<Map> get(
    String path, [
    Map<String, dynamic>? params,
    bool signed = false,
  ]) async {
    final response = await Request().get(
      path,
      queryParameters: signed
          ? await WbiSign.makSign(Map<String, Object>.from(params ?? {}))
          : params,
      options: Options(extra: {'account': Accounts.main}),
    );
    final body = response.data;
    if (body is! Map || body['code'] != 0) {
      throw StateError(body is Map ? '${body['message'] ?? '请求失败'}' : '网络请求失败');
    }
    return body['data'] is Map ? body['data'] as Map : {'list': body['data']};
  }

  Future<Object?> load(Map args) async {
    final tab = '${args['section']}';
    final category = '${args['category']}';
    final page = (args['page'] as num?)?.toInt() ?? 1;
    final keyword = '${args['keyword'] ?? ''}'.trim();
    if (tab == 'featured') {
      if (page == 1 || featured == null) {
        final result = await get(Api.popularPrecious);
        featured = List<Map>.from(result['list'] ?? []);
      }
      final start = (page - 1) * 24,
          end = (page * 24).clamp(0, featured!.length);
      return {
        'rows': start >= featured!.length
            ? []
            : featured!.sublist(start, end).map(entry).toList(),
        'more': end < featured!.length,
      };
    }
    if (tab == 'home') {
      final result = Pref.appRcmd
          ? await VideoHttp.rcmdVideoListApp(freshIdx: page - 1)
          : await VideoHttp.rcmdVideoList(ps: 24, freshIdx: page - 1);
      if (result case Success(:final response)) {
        return {
          'rows': response
              .map(
                (v) => {
                  'id': v.bvid,
                  'title': v.title,
                  'creator': v.owner.name ?? '',
                  'mid': v.owner.mid,
                  'duration': v.duration,
                  'views': v.stat.view ?? 0,
                  'cover': image(v.cover),
                  'description': '',
                  if (v is RcmdVideoItemAppModel)
                    'feedback': videoActions.remember(v),
                },
              )
              .toList(),
          'more': response.isNotEmpty,
        };
      }
      throw StateError('推荐加载失败，请重试');
    }
    if (tab == 'search') {
      if (page == 1 &&
          Pref.recordSearchHistory &&
          !MineController.anonymity.value) {
        final term = '${args['query'] ?? ''}'.trim();
        if (term.isNotEmpty) {
          final words = List<String>.from(
            GStorage.historyWord.get('cacheList') ?? [],
          );
          words.remove(term);
          words.insert(0, term);
          await GStorage.historyWord.put('cacheList', words.take(50).toList());
        }
      }
      final data = await get(Api.searchByType, {
        'search_type': args['searchKind'] == 'user' ? 'bili_user' : 'video',
        'keyword': args['query'],
        'page': page,
      }, true);
      if (args['searchKind'] == 'user')
        return {
          'people': (data['result'] as List? ?? [])
              .map(
                (p) => {
                  'mid': p['mid'],
                  'name': clean(p['uname']),
                  'face': image(p['upic']),
                  'sign': clean(p['usign']),
                  'level': p['level'],
                },
              )
              .toList(),
          'more': page < (data['numPages'] ?? 0),
        };
      final rows = (data['result'] as List? ?? [])
          .whereType<Map>()
          .where((v) => v['type'] == null || v['type'] == 'video')
          .map(entry)
          .toList();
      return {'rows': rows, 'more': page < (data['numPages'] ?? 0)};
    }
    if (tab == 'profile' && args['author'] != null) {
      final mid = int.parse('${args['author']}');
      final requests = await Future.wait([
        get('/x/space/wbi/arc/search', {
          'mid': mid,
          'pn': page,
          'ps': 30,
          'order': 'pubdate',
          'keyword': keyword,
        }, true),
        if (page == 1) dataApi.profile(mid),
      ]);
      final list = requests[0]['list']?['vlist'] as List? ?? [];
      return {
        'rows': list.whereType<Map>().map(entry).toList(),
        if (page == 1)
          'authorProfile': {
            ...requests[1],
            'videos': requests[0]['page']?['count'] ?? 0,
          },
        'more': page * 30 < (requests[0]['page']?['count'] ?? 0),
      };
    }
    if (!Accounts.main.isLogin) throw StateError('账号未登录');
    if (tab == 'profile') {
      final profileFuture = page == 1
          ? dataApi.profile(Accounts.main.mid)
          : Future<Map>.value({});
      final data = await Future.wait([
        get('/x/web-interface/nav'),
        get('/x/relation/stat', {'vmid': Accounts.main.mid}),
        get(keyword.isEmpty ? Api.followings : Api.followSearch, {
          'vmid': Accounts.main.mid,
          'pn': page,
          'ps': 30,
          'order': 'desc',
          if (keyword.isNotEmpty) 'name': keyword,
          if (keyword.isNotEmpty) 'order_type': 'attention',
          if (keyword.isNotEmpty) 'gaia_source': 'main_web',
          if (keyword.isNotEmpty) 'web_location': 333.999,
        }, keyword.isNotEmpty),
      ]);
      final info = await profileFuture;
      return {
        if (page == 1)
          'profile': {
            ...info,
            'name': info['name']?.toString().isNotEmpty == true
                ? info['name']
                : data[0]['uname'],
            'face': info['face']?.toString().isNotEmpty == true
                ? info['face']
                : image(data[0]['face']),
            'level': data[0]['level_info']?['current_level'] ?? info['level'],
            'currentExp': data[0]['level_info']?['current_exp'],
            'nextExp': data[0]['level_info']?['next_exp'],
            'vip': info['vip'] == true || data[0]['vipStatus'] == 1,
            'following': data[1]['following'] ?? 0,
          },
        'following': (data[2]['list'] as List? ?? [])
            .map(
              (f) => {
                'mid': f['mid'],
                'name': f['uname'],
                'face': image(f['face']),
                'sign': f['sign'] ?? '',
              },
            )
            .toList(),
        'more': page * 30 < (data[2]['total'] ?? 0),
      };
    }
    if (tab == 'history') {
      if (category == '笔记') {
        final notes = List<Map>.from(
          GStorage.localCache.get(NoteHistoryPage.storageKey) ?? [],
        );
        return {
          'rows': notes
              .map(
                (n) => {
                  'id': n['url'],
                  'title': n['title'],
                  'url': n['url'],
                  'cover': '',
                  'creator': '',
                  'views': 0,
                  'duration': 0,
                  'description': '',
                },
              )
              .toList(),
          'more': false,
        };
      }
      final type = category == '专栏' ? 'article' : 'archive';
      if (page == 1) cursors.remove(type);
      final data = keyword.isEmpty
          ? await get(Api.historyList, {
              'type': type,
              'ps': 30,
              ...?cursors[type],
            })
          : await get(Api.searchHistory, {
              'pn': page,
              'keyword': keyword,
              'business': type,
            });
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .where((v) => v['history']?['business'] != 'live')
          .toList();
      final last = list.lastOrNull;
      if (last != null)
        cursors[type] = {
          'max': last['history']?['oid'],
          'view_at': last['view_at'],
        };
      return {
        'rows': list
            .map(
              (v) => {
                ...entry(v),
                if (category == '专栏')
                  'url':
                      v['uri'] ??
                      'https://www.bilibili.com/read/cv${v['history']?['oid']}',
              },
            )
            .toList(),
        'more': keyword.isEmpty ? list.length == 30 : list.isNotEmpty,
      };
    }
    if (tab == 'favorites') {
      if (category == '专栏') {
        final data = await get(Api.favArticle, {'page': page, 'page_size': 20});
        return {
          'rows': (data['items'] as List? ?? [])
              .map(
                (v) => {
                  'id': v['opus_id'],
                  'title': clean(v['content']),
                  'url': 'https://www.bilibili.com/opus/${v['opus_id']}',
                  'cover': image(v['cover']?['url']),
                  'creator': v['author']?['name'] ?? '',
                  'duration': 0,
                  'views': 0,
                  'description': '',
                },
              )
              .toList(),
          'more': data['has_more'] == true,
        };
      }
      if (category == '笔记') {
        final data = await get(Api.noteList, {
          'pn': page,
          'ps': 10,
          'csrf': Accounts.main.csrf,
        });
        final list = data['list'] as List? ?? [];
        return {
          'rows': list
              .map(
                (v) => {
                  'id': '${v['note_id']}',
                  'url': v['web_url'],
                  'title': clean(v['title'] ?? v['summary']),
                  'cover': image(v['arc']?['pic']),
                  'creator': '',
                  'duration': 0,
                  'views': 0,
                  'description': '',
                },
              )
              .toList(),
          'more': list.length == 10,
        };
      }
      if (args['folder'] != null) {
        final data = await get(Api.favResourceList, {
          'media_id': args['folder'],
          'pn': page,
          'ps': 30,
          'platform': 'web',
          'order': 'mtime',
          if (args['order'] != null) 'order': args['order'],
          'keyword': keyword,
        });
        return {
          'rows': (data['medias'] as List? ?? [])
              .whereType<Map>()
              .where((v) => v['type'] == 2)
              .map(entry)
              .toList(),
          'more': data['has_more'] == true,
        };
      }
      return dataApi.folders(page);
    }
    return {'rows': [], 'more': false};
  }

  Future<Object?> call(String method, Map args) async {
    switch (method) {
      case 'cancelCover':
        dataApi.cancelCover('${args['id']}');
        return null;
      case 'folderCover':
        return dataApi.folderCover(args);
      case 'remove':
        return dataApi.remove(args);
      case 'manage':
        return dataApi.manage(args);
      case 'logout':
        await CanvasData.logout();
        await web?.evaluateJavascript(source: 'window.canvasLoggedOut?.()');
        return null;
      case 'preferences':
        return {'theme': Pref.themeType.name};
      case 'panel':
        final nextSection = '${args['section']}';
        final nextRail = args['rail'] == true;
        final nextCanBack = args['canBack'] == true;
        if (mounted &&
            (section != nextSection ||
                rail != nextRail ||
                canBack != nextCanBack))
          setState(() {
            if (section != nextSection) {
              detail = null;
              dataApi.cancelCovers();
            }
            if (nextSection == 'settings' || nextSection == 'downloads')
              openedPanels.add(nextSection);
            section = nextSection;
            rail = nextRail;
            canBack = nextCanBack;
          });
        if (nextSection == 'downloads')
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        return null;
      case 'load':
        return load(args);
      case 'videoActions':
        return videoActions.show(context, '${args['id']}');
      case 'suggest':
        if (!Pref.searchSuggestion) return [];
        final text = '${args['text']}'.trim();
        if (text.isEmpty) return [];
        // Search history stays on device and never enters the JS bridge.
        final data = await get(Api.searchSuggest, {
          'term': text,
          'highlight': 0,
          'web_location': 333.1365,
        }, true);
        return (data['result']?['tag'] as List? ?? [])
            .map((s) => clean(s['term']))
            .toList();
      case 'login':
        await Get.toNamed('/loginPage');
        if (Accounts.main.isLogin)
          await web?.evaluateJavascript(
            source: 'window.canvasAuthenticated?.()',
          );
        return null;
      case 'story':
        await openCanvasStory('${args['bvid']}');
        if (!DeviceUtils.isTablet) await portraitUpMode();
        return null;
      case 'play':
        final bvid = '${args['bvid']}';
        if (!RegExp(r'^BV[0-9A-Za-z]+$').hasMatch(bvid))
          throw StateError('无效视频');
        final data = await get(Api.videoIntro, {'bvid': bvid});
        final cid = (data['cid'] as num?)?.toInt();
        if (cid == null) throw StateError('无法获取视频信息');
        await PageUtils.toVideoPage(
          bvid: bvid,
          cid: cid,
          title: clean(data['title']),
          cover: image(data['pic']),
          isVertical: (data['dimension']?['height'] ?? 0) > (data['dimension']?['width'] ?? 0),
        );
        if (!DeviceUtils.isTablet) await portraitUpMode();
        await changed();
        return null;
      case 'createFolder':
        if (!Accounts.main.isLogin) throw StateError('账号未登录');
        final title = '${args['title'] ?? ''}'.trim();
        if (title.isEmpty || title.length > 80) throw StateError('请输入有效名称');
        final res = await Request().post(
          Api.addFolder,
          data: {
            'title': title,
            'privacy': 0,
            'intro': '',
            'cover': '',
            'csrf': Accounts.main.csrf,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        if (res.data['code'] != 0)
          throw StateError('${res.data['message'] ?? '创建失败'}');
        return null;
      case 'read':
        final url = Uri.tryParse('${args['url']}');
        if (url == null ||
            !{'www.bilibili.com', 'm.bilibili.com'}.contains(url.host))
          throw StateError('无效阅读地址');
        final cv =
            RegExp(r'cv(\d+)').firstMatch(url.path)?.group(1) ??
            url.queryParameters['cvid'];
        List<String> paragraphs;
        String title = clean(args['title']);
        if (cv != null) {
          final data = await get(Api.articleView, {
            'id': cv,
            'gaia_source': 'main_web',
            'web_location': '333.976',
          }, true);
          final doc = html.parseFragment('${data['content'] ?? ''}');
          paragraphs = doc
              .querySelectorAll('p')
              .map((p) => p.text)
              .where((p) => p.trim().isNotEmpty)
              .toList();
          title = clean(data['title'] ?? title);
        } else {
          final id = RegExp(r'/opus/(\d+)').firstMatch(url.path)?.group(1);
          if (id == null) throw StateError('暂不支持此阅读地址');
          final data = await get(Api.opusDetail, {
            'id': id,
            'timezone_offset': '-480',
          }, true);
          paragraphs = [];
          void collect(dynamic v) {
            if (v is Map) {
              if (v['type'] == 'TEXT_NODE_TYPE_WORD' &&
                  v['word']?['words'] is String) {
                paragraphs.add(v['word']['words'] as String);
                return;
              }
              if (v['text'] is String &&
                  v['text'].toString().trim().isNotEmpty) {
                paragraphs.add(v['text'] as String);
                return;
              }
              for (final value in v.values) {
                collect(value);
              }
            } else if (v is List) {
              for (final value in v) {
                collect(value);
              }
            }
          }

          collect(data['item']?['modules'] ?? data);
        }
        if (paragraphs.isEmpty) throw StateError('暂时无法读取正文，请稍后重试');
        if (args['note'] == true) NoteHistoryPage.record(url.toString(), title);
        return {'title': title, 'paragraphs': paragraphs};
      default:
        throw StateError('不支持的操作');
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = !DeviceUtils.isTablet;
    return PopScope(
      canPop: !canBack && detail == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) {
          if (detail != null) {
            setState(() => detail = null);
          } else {
            web?.evaluateJavascript(source: 'window.canvasBack?.()');
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('$assetUrl&device=${phone ? "phone" : "tablet"}')),
                initialSettings: InAppWebViewSettings(
                  webViewAssetLoader: WebViewAssetLoader(
                    pathHandlers: [AssetsPathHandler(path: '/assets/')],
                  ),
                  useShouldOverrideUrlLoading: true,
                  javaScriptEnabled: true,
                  transparentBackground: false,
                  supportZoom: false,
                  disableContextMenu: false,
                ),
                shouldOverrideUrlLoading: (_, action) async =>
                    action.request.url?.toString().startsWith(
                          '$origin/assets/flutter_assets/assets/canvas/',
                        ) ==
                        true
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL,
                onWebViewCreated: (controller) {
                  CanvasWindow.apply();
                  web = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'canvas',
                    callback: (args) async {
                      final uri = await controller.getUrl();
                      if (uri?.host != 'appassets.androidplatform.net' ||
                          uri?.path !=
                              '/assets/flutter_assets/assets/canvas/index.html')
                        return {'error': '无效来源'};
                      try {
                        return await call(
                          args[0] as String,
                          args.length > 1 ? args[1] as Map : {},
                        );
                      } catch (e) {
                        return {
                          'error': e is StateError
                              ? e.message
                              : '请求失败，请检查网络后重试',
                        };
                      }
                    },
                  );
                },
              ),
              for (final name in openedPanels)
                Positioned(
                  top: phone ? 56 : 64,
                  bottom: 0,
                  left: phone ? 0 : 32,
                  right: phone ? 0 : 32,
                  child: Offstage(
                    offstage: section != name || detail != null,
                    child: TickerMode(
                      enabled: section == name && detail == null,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: !phone && rail ? 32.0 : 0.0),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (_, offset, child) => Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        ),
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: name == 'settings'
                              ? settingsPanel
                              : downloadsPanel,
                        ),
                      ),
                    ),
                  ),
                ),
              if (section == 'downloads' && detail == null)
                Positioned(
                  top: 0,
                  height: phone ? 56 : 64,
                  left: phone ? 44 : 72,
                  right: phone ? 12 : 32,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: !phone && rail ? 32.0 : 0.0),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (_, offset, child) => Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    ),
                    child: Builder(
                      builder: (_) => DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF2E3037)
                                  : const Color(0xFFE9EBEF),
                              width: .5,
                            ),
                          ),
                        ),
                        child:
                            downloadKey.currentState?.buildToolbar() ??
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              if (detail != null)
                Positioned(
                  top: phone ? 56 : 64,
                  bottom: 0,
                  left: phone ? 0 : 32,
                  right: phone ? 0 : 32,
                  child: Transform.translate(
                    offset: Offset(!phone && rail ? 32 : 0, 0),
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: detail!,
                    ),
                  ),
                ),
              if (detail != null)
                Positioned(
                  top: 8,
                  right: 58,
                  child: IconButton(
                    tooltip: '返回设置',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => detail = null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
