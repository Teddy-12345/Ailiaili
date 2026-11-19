import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/app_centered.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class HttpError extends StatelessWidget {
  const HttpError({
    super.key,
    this.isSliver = true,
    this.errMsg,
    this.onReload,
    this.btnText,
    this.safeArea = true,
  });

  final bool isSliver;
  final String? errMsg;
  final VoidCallback? onReload;
  final String? btnText;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        errMsg == null
            ? SvgPicture.asset(
                'assets/images/shell/no-data.svg',
                width: (MediaQuery.sizeOf(context).shortestSide * .22).clamp(
                  110.0,
                  170.0,
                ),
                height: (MediaQuery.sizeOf(context).shortestSide * .22).clamp(
                  110.0,
                  170.0,
                ),
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.outline.withValues(alpha: .5),
                  BlendMode.srcIn,
                ),
              )
            : SvgPicture.asset(Assets.error, height: 200),
        const SizedBox(height: 30),
        Padding(
          padding: const .symmetric(horizontal: 16, vertical: 5),
          child: Text(
            errMsg ?? '无数据',
            textAlign: .center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (onReload != null)
          FilledButton.tonal(
            onPressed: onReload,
            style: FilledButton.styleFrom(
              tapTargetSize: .padded,
              backgroundColor: theme.colorScheme.primary.withAlpha(20),
            ),
            child: Text(
              btnText ?? '点击重试',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
      ],
    );

    return isSliver
        ? errMsg == null
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppCentered(child: child),
                )
              : SliverToBoxAdapter(child: child)
        : SizedBox(width: double.infinity, child: child);
  }
}
