import 'package:flutter/material.dart';

import '../utils/arabic_format.dart';

/// Const-compatible Text: numbers are converted only at the presentation layer.
class ArabicText extends Text {
  const ArabicText(
    super.data, {
    super.key,
    super.style,
    super.textAlign,
    super.textDirection,
    super.softWrap,
    super.overflow,
    super.maxLines,
    super.semanticsLabel,
    super.textScaler,
  });
  @override
  Widget build(BuildContext context) => Text(
    ArabicFormat.digits(data ?? ''),
    style: style,
    textAlign: textAlign,
    textDirection: textDirection ?? TextDirection.rtl,
    softWrap: softWrap,
    overflow: overflow,
    maxLines: maxLines,
    textScaler: textScaler,
    semanticsLabel: semanticsLabel == null
        ? null
        : ArabicFormat.digits(semanticsLabel!),
  );
}
