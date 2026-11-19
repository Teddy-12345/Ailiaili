import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Empty states use the application's viewport centre, independent of toolbars.
class AppCentered extends SingleChildRenderObjectWidget {
  const AppCentered({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AppCentered(MediaQuery.sizeOf(context));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _AppCentered renderObject,
  ) {
    renderObject.viewport = MediaQuery.sizeOf(context);
  }
}

class _AppCentered extends RenderShiftedBox {
  _AppCentered(this._viewport) : super(null);
  Size _viewport;
  set viewport(Size value) {
    if (value != _viewport) {
      _viewport = value;
      markNeedsPaint();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    child?.layout(constraints.loosen(), parentUsesSize: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final centre = globalToLocal(
      Offset(_viewport.width / 2, _viewport.height / 2),
    );
    (c.parentData as BoxParentData).offset =
        centre - Offset(c.size.width / 2, c.size.height / 2);
    super.paint(context, offset);
  }
}
