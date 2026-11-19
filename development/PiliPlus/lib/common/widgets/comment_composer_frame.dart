import 'package:material_ui/material_ui.dart';

class CommentComposerFrame extends StatelessWidget {
  const CommentComposerFrame({
    super.key,
    required this.children,
    required this.panel,
  });
  final List<Widget> children;
  final Widget panel;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('comment-composer-card'),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colors.surface,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
            Flexible(child: panel),
          ],
        ),
      ),
    );
  }
}
