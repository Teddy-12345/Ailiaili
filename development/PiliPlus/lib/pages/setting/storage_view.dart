import 'dart:io';

import 'package:PiliPlus/common/widgets/canvas_dialog.dart';

import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class StorageManagement extends StatefulWidget {
  const StorageManagement({super.key});
  @override
  State<StorageManagement> createState() => _StorageManagementState();
}

class _StorageManagementState extends State<StorageManagement> {
  static const steps = <double>[.5, 1, 1.5, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  int bytes = 0;
  double quota = Pref.maxCacheSize / (1024 * 1024 * 1024);
  bool working = false;
  String? error;
  @override
  void initState() {
    super.initState();
    bytes = CacheManager.manager.getTotalLength();
  }

  int nearest(double v) {
    var best = 0;
    for (var i = 1; i < steps.length; i++) {
      if ((steps[i] - v).abs() < (steps[best] - v).abs()) best = i;
    }
    return best;
  }

  Future<void> saveQuota(double value) async {
    final used = CacheManager.manager.getTotalLength();
    final limit = (value * 1024 * 1024 * 1024).round();
    if (limit < used) {
      setState(() {
        bytes = used;
        quota = Pref.maxCacheSize / (1024 * 1024 * 1024);
        error = '容量上限不能低于当前占用，请先清理缓存';
      });
      return;
    }
    await GStorage.setting.put(SettingBoxKey.maxCacheSize, limit);
    CacheManager.manager.setCapacity(limit);
    if (mounted)
      setState(() {
        quota = value;
        bytes = used;
        error = null;
      });
  }

  Future<void> clear() async {
    if (!await canvasConfirm(
      context,
      title: '清空图片缓存？',
      message: '已下载视频、账号、收藏和设置会保留。',
      action: '清空',
    ))
      return;
    if (!mounted) return;
    setState(() => working = true);
    try {
      await CacheManager.manager.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      if (mounted)
        setState(() {
          bytes = CacheManager.manager.getTotalLength();
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = '清理失败，请重试');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .35),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
  Widget directory(String label, String path) => Row(
    children: [
      SizedBox(
        width: 72,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: '复制$label',
        icon: const Icon(Icons.copy_outlined, size: 18),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: path));
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制路径'),
                duration: Duration(seconds: 1),
              ),
            );
        },
      ),
      if (!Platform.isAndroid && !Platform.isIOS)
        IconButton(
          tooltip: '打开$label',
          onPressed: () => PathUtils.openDir(path),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '缓存管理',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('图片缓存容量上限')),
                    Text('${quota.toStringAsFixed(1)} G'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: Theme.of(context)
                              .colorScheme
                              .onSurface,
                          inactiveTrackColor: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: .2),
                          thumbColor: Theme.of(context).colorScheme.onSurface,
                          overlayColor: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: .08),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          trackShape: const RoundedRectSliderTrackShape(),
                          tickMarkShape: const RoundSliderTickMarkShape(
                            tickMarkRadius: 0,
                          ),
                          trackGap: 0,
                        ),
                        child: Slider(
                          min: 0,
                          max: (steps.length - 1).toDouble(),
                          divisions: steps.length - 1,
                          value: nearest(quota).toDouble(),
                          onChanged: working
                              ? null
                              : (v) {
                                  if (steps[v.round()] * 1024 * 1024 * 1024 >=
                                      bytes)
                                    setState(() => quota = steps[v.round()]);
                                },
                          onChangeEnd: (v) => saveQuota(steps[v.round()]),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '清空图片缓存',
                      onPressed: working ? null : clear,
                      icon: working
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Text(
                  '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB / ${quota.toStringAsFixed(1)} G',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '文件位置',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          card(
            Column(
              children: [
                directory('缓存目录', CacheManager.manager.cacheDir),
                const Divider(height: 24),
                directory('下载目录', downloadPath),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
