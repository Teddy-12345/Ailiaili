import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Lives inside the player's existing bar, inheriting its hide/show animation.
class PlayerDanmakuControls extends StatelessWidget {
  const PlayerDanmakuControls({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.onSettings,
    required this.onSend,
    this.compact = false,
  });
  final bool enabled, compact;
  final VoidCallback onToggle, onSettings, onSend;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: enabled ? '关闭弹幕' : '开启弹幕',
        onPressed: onToggle,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: Icon(
          enabled ? CustomIcons.dm_on : CustomIcons.dm_off,
          color: Colors.white,
          size: 21,
        ),
      ),
      IconButton(
        tooltip: '弹幕设置',
        onPressed: onSettings,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: const Icon(
          CustomIcons.dm_settings,
          color: Colors.white,
          size: 21,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Material(
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    compact ? '发弹幕' : '点击发送弹幕',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
