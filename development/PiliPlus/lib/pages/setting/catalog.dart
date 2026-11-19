import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';

/// User-facing controls supported by this canvas; developer/retired navigation
/// controls are intentionally absent. Original storage keys/callbacks survive.
Map<String, List<SettingsModel>> canvasSettingsCatalog() {
  final groups = <String, List<SettingsModel>>{
    '通用': [],
    '播放': [],
    '画质与音质': [],
    '手势': [],
    '推荐过滤': [],
    '评论': [],
    '弹幕': [],
    '存储': [],
    '隐私与屏蔽': [],
  };
  const extraKeep = {
    '使用外部浏览器打开链接',
    '搜索建议',
    '记录搜索历史',
    '预览 Live Photo',
    '静默下载图片',
    '长按/右键显示图片菜单',
    '震动反馈',
    '快速收藏',
  };
  const videoKeep = {'默认画质', '蜂窝网络画质', '默认音质', '蜂窝网络音质'};
  const styleKeep = {'视频播放页使用深色主题', '播放页移除安全边距', '图片质量', '查看大图质量', '深色下图片颜色叠加'};
  const rejected = [
    '片头',
    '片尾',
    '反诈',
    '播放器音量',
    '音量均衡',
    '最高音量',
    '直播',
    'SuperChat',
    '截图',
    '提前初始化',
    '播放器设置仅对当前生效',
    '倾斜角度阈值',
    'HTTP',
    'WebDAV',
    'Navbar',
    '启动页',
    '弹簧参数',
    '屏幕帧率',
    '气泡提示不透明度',
  ];
  for (final type in [
    SettingType.recommendSetting,
    SettingType.videoSetting,
    SettingType.playSetting,
    SettingType.replySetting,
    SettingType.dmSetting,
    SettingType.styleSetting,
    SettingType.extraSetting,
  ]) {
    for (final item in type.settings) {
      final title = item.effectiveTitle;
      if (rejected.any(title.contains)) continue;
      String? category;
      switch (type) {
        case SettingType.recommendSetting:
          if (title.contains('app端推荐') ||
              title.contains('保留首页') ||
              title.contains('上次看到'))
            continue;
          category = '推荐过滤';
        case SettingType.videoSetting:
          if (!videoKeep.contains(title)) continue;
          category = '画质与音质';
        case SettingType.playSetting:
          category = RegExp('双击|长按|滑动|双指|拖拽|滚轮|手势|亮度').hasMatch(title)
              ? '手势'
              : '播放';
        case SettingType.replySetting:
          category = '评论';
        case SettingType.dmSetting:
          category = '弹幕';
        case SettingType.styleSetting:
          if (!styleKeep.contains(title)) continue;
          category = '播放';
        case SettingType.extraSetting:
          if (!extraKeep.contains(title)) continue;
          category = title.contains('缓存') ? '存储' : '通用';
        default:
          continue;
      }
      groups[category]!.add(item);
    }
  }
  return groups;
}
