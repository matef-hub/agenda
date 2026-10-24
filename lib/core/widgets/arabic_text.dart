import 'package:flutter/material.dart';

import '../utils/arabic_format.dart';

/// Const-compatible text with Arabic digits and right-to-left presentation.
class ArabicText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  const ArabicText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textScaler,
  });
  @override
  Widget build(BuildContext context) => Text(
    ArabicFormat.digits(data),
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
