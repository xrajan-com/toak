import 'package:flutter/material.dart';

/// Extension for padding widgets easily
extension PaddingExtension on Widget {
  Widget padAll(double value) => Padding(padding: EdgeInsets.all(value), child: this);
  Widget padSymmetric({double vertical = 0, double horizontal = 0}) =>
      Padding(padding: EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal), child: this);
  Widget padOnly({double top = 0, double bottom = 0, double left = 0, double right = 0}) =>
      Padding(padding: EdgeInsets.only(top: top, bottom: bottom, left: left, right: right), child: this);
}

/// Extension for spacing numbers as SizedBox
extension SpaceExtension on num {
  SizedBox get h => SizedBox(height: toDouble());
  SizedBox get w => SizedBox(width: toDouble());
}

/// Extension to make color opacity quick
extension ColorOpacity on Color {
  Color get o80 => withValues(alpha: 0.8);
  Color get o50 => withValues(alpha: 0.5);
  Color get o20 => withValues(alpha: 0.2);
}
