import 'dart:async';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Only the visible feed item owns a player. Full playback changes presentation
/// and manual orientation without opening another player or media source.
class CanvasStoryPage extends StatefulWidget {
  const CanvasStoryPage({
    super.key,
    required this.bvid,
    this.position = Duration.zero,
  });
  final String bvid;
  final Duration position;
  @override
  State<CanvasStoryPage> createState() => _CanvasStoryPageState();
}

class _CanvasStoryPageState extends State<CanvasStoryPage>
    with WidgetsBindingObserver {
  final pager = PageController();
  final rows = <Map<String, dynamic>>[];
  Player? player;
  VideoController? video;
  Map<String, dynamic>? info;
  int current = 0, generation = 0;
  String? error;
  bool loading = true, fetching = false, closing = false, purePlayback = false;
  bool get verticalVideo {
    final d = info?['dimension'];
    return d is Map && (d['height'] as num? ?? 0) > (d['width'] as num? ?? 0);
  }

  Future<void> togglePure() async {
    if (info == null) return;
    final next = !purePlayback;
    setState(() => purePlayback = next);
    if (next && !verticalVideo) {
      await landscapeLeftMode();
    } else {
      await portraitUpMode();
    }
  }

  String clock(Duration value) {
    final n = value.inSeconds;
    return '${n ~/ 60}:' + (n % 60).toString().padLeft(2, '0');
  }

  Future<void> serial = Future.value();
  Future<Map> api(
    String path,
    Map<String, dynamic> params, {
    bool signed = false,
  }) async {
    final response = await Request().get(
      path,
      queryParameters: signed
          ? await WbiSign.makSign(Map<String, Object>.from(params))
          : params,
      options: Options(extra: {'account': Accounts.main}),
    );
    final data = response.data;
    if (data is! Map || data['code'] != 0)
      throw StateError(data is Map ? '${data['message'] ?? '加载失败'}' : '加载失败');
    return data['data'] is Map ? data['data'] : {'list': data['data']};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    portraitUpMode();
    rows.add({'bvid': widget.bvid});
    select(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player?.pause();
  }

  void select(int index) {
    current = index;
    final token = ++generation;
    setState(() {
      loading = true;
      video = null;
      info = null;
      error = null;
    });
    final old = player;
    player = null;
    serial = serial.catchError((_) {}).then((_) async {
      await old?.dispose();
      if (!mounted || token != generation) return;
      Player? next;
      try {
        final detail = Map<String, dynamic>.from(
          await api('/x/web-interface/view', {'bvid': rows[index]['bvid']}),
        );
        if (!mounted || token != generation) return;
        rows[index] = detail;
        final cid = detail['cid'];
        final result = await api('/x/player/wbi/playurl', {
          'bvid': detail['bvid'],
          'cid': cid,
          'qn': 80,
          'fnval': 4048,
          'fourk': 1,
        }, signed: true);
        final dash = result['dash'];
        String source;
        if (dash is Map) {
          final variants = List<Map>.from(dash['video'] ?? []);
          if (variants.isEmpty) throw StateError('暂无可播放视频');
          variants.sort((a, b) => (b['id'] as num).compareTo(a['id'] as num));
          final v = variants.first;
          final vurl = '${v['baseUrl'] ?? v['base_url']}';
          final audios = List<Map>.from(dash['audio'] ?? []);
          if (audios.isEmpty) {
            source = vurl;
          } else {
            final aurl =
                '${audios.first['baseUrl'] ?? audios.first['base_url']}';
            source =
                'edl://!no_chapters;%${vurl.length}%$vurl;!new_stream;!no_chapters;%${aurl.length}%$aurl';
          }
        } else {
          final durl = List<Map>.from(result['durl'] ?? []);
          if (durl.isEmpty) throw StateError('当前视频暂不支持此播放模式');
          source = '${durl.first['url']}';
        }
        if (!mounted || token != generation) return;
        next = await Player.create(configuration: const PlayerConfiguration());
        next.setMediaHeader(
          userAgent: 'Mozilla/5.0',
          referer: 'https://www.bilibili.com/',
        );
        final controller = await VideoController.create(
          next,
          configuration: const VideoControllerConfiguration(
            androidAttachSurfaceAfterVideoParameters: false,
          ),
        );
        if (!mounted || token != generation) {
          await next.dispose();
          return;
        }
        player = next;
        video = controller;
        info = detail;
        await next.open(
          Media(source, start: index == 0 ? widget.position : null),
          play: true,
        );
        if (!mounted || token != generation) return;
        setState(() => loading = false);
        unawaited(append(detail['bvid']));
      } catch (e) {
        if (next != null && next != player) await next.dispose();
        if (mounted && token == generation)
          setState(() {
            loading = false;
            error = '$e';
          });
      }
    });
  }

  Future<void> append(dynamic bvid) async {
    if (fetching || rows.length - current > 5) return;
    fetching = true;
    try {
      final data = await api('/x/web-interface/archive/related', {
        'bvid': bvid,
      });
      if (!mounted) return;
      final ids = rows.map((v) => v['bvid']).toSet();
      final items = List<Map>.from(data['list'] ?? []);
      if (items.isEmpty) {
        final fallback = await VideoHttp.rcmdVideoList(
          ps: 12,
          freshIdx: rows.length,
        );
        if (fallback case Success(:final response)) {
          items.addAll(response.map((v) => {'bvid': v.bvid, 'title': v.title}));
        }
      }
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          if (item['bvid'] != null &&
              ids.add(item['bvid']) &&
              item['ad_info'] == null &&
              item['is_ad'] != true)
            rows.add(Map<String, dynamic>.from(item));
        }
      });
    } catch (_) {
      /* Existing queue remains playable. */
    } finally {
      fetching = false;
    }
  }

  Future<void> detail() async {
    if (closing || info == null) return;
    closing = true;
    final value = Map<String, dynamic>.from(info!);
    value['position'] = player?.state.position.inMilliseconds ?? 0;
    await player?.pause();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    closing = true;
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    pager.dispose();
    final old = player;
    player = null;
    serial.whenComplete(() => old?.dispose());
    portraitUpMode();
    super.dispose();
  }

  Widget transport() => StreamBuilder<Duration>(
    stream: player!.stream.position,
    builder: (_, snap) {
      final position = snap.data ?? player!.state.position;
      final duration = player!.state.duration;
      if (purePlayback && !verticalVideo) {
        return SizedBox(
          height: 40,
          child: Row(
            children: [
              StreamBuilder<bool>(
                stream: player!.stream.playing,
                builder: (_, state) => IconButton(
                  onPressed: () => player?.playOrPause(),
                  icon: Icon(
                    (state.data ?? player!.state.playing)
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, box) {
                    final total = duration.inMilliseconds.toDouble();
                    void seek(double x) {
                      if (total > 0)
                        player?.seek(
                          Duration(
                            milliseconds: (x / box.maxWidth * total)
                                .clamp(0, total)
                                .round(),
                          ),
                        );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => seek(d.localPosition.dx),
                      onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: LinearProgressIndicator(
                            value: total > 0
                                ? (position.inMilliseconds / total).clamp(0, 1)
                                : 0,
                            minHeight: 2,
                            color: const Color(0xFFFB7299),
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${clock(position)} / ${clock(duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: '切换详情播放',
                onPressed: detail,
                icon: const Icon(
                  Icons.crop_free,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              IconButton(
                tooltip: '退出全屏',
                onPressed: togglePure,
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (purePlayback)
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: player!.stream.playing,
                  builder: (_, playing) => IconButton(
                    onPressed: () => player?.playOrPause(),
                    icon: Icon(
                      (playing.data ?? player!.state.playing)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${clock(position)} / ${clock(duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          LayoutBuilder(
            builder: (_, box) {
              final total = duration.inMilliseconds.toDouble();
              void seek(double x) {
                if (total > 0)
                  player?.seek(
                    Duration(
                      milliseconds: (x / box.maxWidth * total)
                          .clamp(0, total)
                          .round(),
                    ),
                  );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => seek(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: LinearProgressIndicator(
                      value: total > 0
                          ? (position.inMilliseconds / total).clamp(0, 1)
                          : 0,
                      minHeight: 2,
                      color: const Color(0xFFFB7299),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '切换详情播放',
                onPressed: info == null ? null : detail,
                icon: const Icon(
                  Icons.crop_free,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                tooltip: purePlayback
                    ? '退出纯播放'
                    : verticalVideo
                    ? '竖屏纯播放'
                    : '横屏全屏',
                onPressed: info == null ? null : togglePure,
                icon: Icon(
                  purePlayback
                      ? Icons.fullscreen_exit
                      : verticalVideo
                      ? Icons.stay_current_portrait
                      : Icons.fullscreen,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !purePlayback,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && purePlayback) togglePure();
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: pager,
              physics: purePlayback
                  ? const NeverScrollableScrollPhysics()
                  : null,
              scrollDirection: Axis.vertical,
              itemCount: rows.length,
              onPageChanged: select,
              itemBuilder: (_, index) {
                if (index != current)
                  return const ColoredBox(color: Colors.black);
                return GestureDetector(
                  onTap: () => player?.playOrPause(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video != null)
                        Video(
                          controller: video!,
                          fit: BoxFit.contain,
                          controls: NoVideoControls,
                        ),
                      if (loading)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      if (error != null)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error!,
                                style: const TextStyle(color: Colors.white),
                              ),
                              TextButton(
                                onPressed: () => select(current),
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: '返回',
                onPressed: () =>
                    purePlayback ? togglePure() : Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            if (!purePlayback) ...[
              Positioned(
                right: 10,
                bottom: 190,
                child: Column(
                  children: [
                    IconButton(
                      tooltip: '评论',
                      onPressed: info == null ? null : detail,
                      icon: const Icon(
                        Icons.chat_bubble,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Text(
                      '${info?['stat']?['reply'] ?? ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 65,
                bottom: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (info?['owner']?['face'] case final String face)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: CircleAvatar(
                              radius: 21,
                              backgroundImage: NetworkImage(face),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${info?['owner']?['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${info?['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
            if (player != null)
              Positioned(left: 12, right: 12, bottom: 4, child: transport()),
          ],
        ),
      ),
    ),
  );
}

Future<void> openCanvasStory(
  String bvid, {
  Duration position = Duration.zero,
  Future<void> Function(Map<String, dynamic>)? onDetail,
}) async {
  if (!RegExp(r'^BV[0-9A-Za-z]+$').hasMatch(bvid)) return;
  final result = await Get.to<Map<String, dynamic>>(
    () => CanvasStoryPage(bvid: bvid, position: position),
  );
  if (result != null && onDetail != null) {
    await onDetail(result);
    return;
  }
  if (result != null)
    await PageUtils.toVideoPage(
      bvid: result['bvid'],
      cid: (result['cid'] as num).toInt(),
      title: result['title'],
      cover: result['pic'],
      progress: result['position'],
    );
}
