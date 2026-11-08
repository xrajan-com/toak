import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_bar.dart'
    show actionBarHeight, kActionButtonFaceHeight;

/// How the game screen shares its canvas between the table and the controls.
///
/// The game is drawn on a canvas 576 units tall (viewport.dart) and zoomed to
/// fit the screen. Zooming everything alike made the controls small on a
/// phone and oversized on a laptop or tablet, so the controls are sized by
/// the finger instead: a hero button's face is kept between [minFaceDp] and
/// [maxFaceDp] logical pixels tall, and the whole action bar (buttons, side
/// circles, text, gaps) scales with it by [controlScale], so its proportions
/// never change. Taps stay at least 44 logical pixels.
///
/// The table takes the room that is left. Its top rail stays where it always
/// was, so the scene strip above keeps its room; its bottom comes down to
/// [tableClearance] units above the controls with the raise slider open, so
/// nothing ever covers it. Seats, cards and the dealer grow with the table by
/// [contentScale], so the scene inside it keeps its proportions; they never
/// shrink below their phone size and never get more crowded across the table
/// than they are on a 16:9 screen.
///
/// On a phone (a canvas 576 units tall at about 0.6-0.7 logical pixels a
/// unit) this is the layout phones already had: [controlScale] near 1 and
/// [contentScale] exactly 1. Laptops and tablets get a smaller bar and a
/// bigger table.
@immutable
class GameLayout {
  const GameLayout._({
    required this.controlScale,
    required this.contentScale,
    required this.tableWidth,
    required this.tableHeight,
    required this.tableTop,
    required this.tableVerticalShift,
    required this.actionBarMaxWidth,
    required this.raisedControlsTop,
  });

  /// A hero button's face, in logical pixels.
  static const double minFaceDp = 32;
  static const double maxFaceDp = 40;

  /// The table group is drawn this much larger than its layout box, rails,
  /// seats and all, around its centre.
  static const double tableVisualScale = 1.06;
  static const double tableWidthShare = 0.94;

  /// Gap under the action bar, as before.
  static const double barBottomMargin = 10;

  /// Units between the table and the controls with the raise slider open.
  static const double tableClearance = 4;

  /// The widest the action bar is drawn at [controlScale] 1, and the most of
  /// the canvas width it may take.
  static const double barMaxWidth = 1120;
  static const double barMaxWidthShare = 0.92;

  /// How much bigger than on a phone seats and cards may get.
  static const double maxContentScale = 1.3;

  /// The table's top sits where a table 0.59 of the height high, lifted a
  /// little, always put it.
  static const double _topAnchorShare = 0.59;

  /// The narrowest canvas (16:9). Seats are spaced for this width at
  /// [contentScale] 1, so they may only grow as far as a wider table allows.
  static const double _narrowestCanvasWidth = 1024;
  static const double _phoneCanvasHeight = 576;

  /// The action bar is drawn this much larger (or smaller) than its own
  /// units, everything in it alike.
  final double controlScale;

  /// Seats, cards and the dealer, relative to their size on a phone.
  final double contentScale;

  /// The table's layout box, before [tableVisualScale].
  final double tableWidth;
  final double tableHeight;

  /// The top of the drawn table, in canvas units.
  final double tableTop;

  /// How far the table's centre sits from the canvas middle (negative is up).
  final double tableVerticalShift;

  /// The most width the action bar row may take, in canvas units.
  final double actionBarMaxWidth;

  /// Where the top of the action bar reaches with the raise slider open.
  final double raisedControlsTop;

  /// The drawn table's bottom, in canvas units.
  double get tableBottom => tableTop + tableHeight * tableVisualScale;

  /// How much the action bar is scaled from its own units on a screen where
  /// one canvas unit measures [viewportScale] logical pixels. 1 when the
  /// scale is unknown (outside the game viewport, as in some tests).
  static double controlScaleFor(double? viewportScale) {
    final double? s = viewportScale;
    if (s == null || !s.isFinite || s <= 0) return 1.0;
    final double faceDp = kActionButtonFaceHeight * s;
    return faceDp.clamp(minFaceDp, maxFaceDp).toDouble() / faceDp;
  }

  static GameLayout resolve(Size canvas, {double? viewportScale}) {
    final double w = canvas.width;
    final double h = canvas.height;
    final double c = controlScaleFor(viewportScale);

    // The controls at their tallest (raise slider open), on screen.
    final double raisedControls = _raisedControlsHeight(viewportScale, c);
    final double raisedControlsTop = h - barBottomMargin - raisedControls;

    final double tableWidth = _tableWidthFor(w);
    final double top = _tableTopFor(h);
    final double tableHeight = _tableHeightBetween(
      top,
      raisedControlsTop - tableClearance,
    );
    final double drawnHeight = tableHeight * tableVisualScale;

    double contentScale = 1.0;
    if (viewportScale != null && viewportScale.isFinite && viewportScale > 0) {
      final double tallerBy = drawnHeight / _phoneDrawnTableHeight();
      final double widerBy = tableWidth / _tableWidthFor(_narrowestCanvasWidth);
      contentScale = math
          .min(tallerBy, widerBy)
          .clamp(1.0, maxContentScale)
          .toDouble();
    }

    return GameLayout._(
      controlScale: c,
      contentScale: contentScale,
      tableWidth: tableWidth,
      tableHeight: tableHeight,
      tableTop: top,
      tableVerticalShift: top + drawnHeight / 2 - h / 2,
      actionBarMaxWidth: math.min(barMaxWidth * c, w * barMaxWidthShare),
      raisedControlsTop: raisedControlsTop,
    );
  }

  static double _raisedControlsHeight(double? viewportScale, double c) {
    final double unitOnScreen =
        (viewportScale != null && viewportScale > 0 ? viewportScale : 1.0) *
            c;
    return actionBarHeight(raising: true, viewportScale: unitOnScreen) * c;
  }

  static double _tableWidthFor(double w) {
    final double margin = (w * 0.012).clamp(10.0, 30.0).toDouble();
    final double raw = (w - margin * 2) * tableWidthShare;
    final double minWidth = math.min(300.0, w);
    final double maxWidth = math.max(minWidth, w - margin * 2);
    return raw.clamp(minWidth, maxWidth).toDouble();
  }

  static double _tableTopFor(double h) {
    final double anchor = (h * _topAnchorShare).clamp(260.0, 780.0).toDouble();
    final double lift = (h * 0.024).clamp(12.0, 24.0).toDouble();
    return h / 2 - lift - anchor * tableVisualScale / 2;
  }

  static double _tableHeightBetween(double top, double bottom) {
    return ((bottom - top) / tableVisualScale).clamp(260.0, 780.0).toDouble();
  }

  /// The drawn table's height on a phone, where seats and cards are 1.
  static double _phoneDrawnTableHeight() {
    const double h = _phoneCanvasHeight;
    final double bottom =
        h - barBottomMargin - _raisedControlsHeight(null, 1.0) - tableClearance;
    return _tableHeightBetween(_tableTopFor(h), bottom) * tableVisualScale;
  }
}

/// Lays [child] out as if it had 1/[scale] of the room, then draws it [scale]
/// times as large, so a whole control cluster grows or shrinks as one: text,
/// borders, gaps and tap areas alike. Taps and global positions (tooltips,
/// effects anchored to a button) follow the drawn size.
class ScaledLayout extends SingleChildRenderObjectWidget {
  const ScaledLayout({super.key, required this.scale, super.child})
      : assert(scale > 0);

  final double scale;

  @override
  RenderScaledLayout createRenderObject(BuildContext context) =>
      RenderScaledLayout(scale);

  @override
  void updateRenderObject(
      BuildContext context, RenderScaledLayout renderObject) {
    renderObject.scale = scale;
  }
}

class RenderScaledLayout extends RenderProxyBox {
  RenderScaledLayout(this._scale);

  double _scale;
  double get scale => _scale;
  set scale(double value) {
    assert(value > 0);
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1.0);

  BoxConstraints _inner(BoxConstraints outer) => BoxConstraints(
        minWidth: outer.minWidth / _scale,
        maxWidth: outer.maxWidth / _scale,
        minHeight: outer.minHeight / _scale,
        maxHeight: outer.maxHeight / _scale,
      );

  @override
  void performLayout() {
    final RenderBox? box = child;
    if (box == null) {
      size = constraints.smallest;
      return;
    }
    box.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(box.size * _scale);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? box = child;
    if (box == null) return constraints.smallest;
    return constraints.constrain(box.getDryLayout(_inner(constraints)) * _scale);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height / _scale) ?? 0) * _scale;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height / _scale) ?? 0) * _scale;

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width / _scale) ?? 0) * _scale;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width / _scale) ?? 0) * _scale;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final double? distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _scale;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? box = child;
    if (box == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (PaintingContext context, Offset offset) =>
          context.paintChild(box, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? box = child;
    if (box == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          box.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
