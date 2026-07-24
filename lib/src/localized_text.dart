import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

import 'localization.dart';
import 'state.dart';

class TaploeTextScope extends InheritedWidget {
  final TaploeTextCatalog catalog;

  const TaploeTextScope({
    super.key,
    required this.catalog,
    required super.child,
  });

  static TaploeTextCatalog of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TaploeTextScope>();
    return scope?.catalog ?? taploeState.t;
  }

  @override
  bool updateShouldNotify(TaploeTextScope oldWidget) =>
      oldWidget.catalog.code != catalog.code;
}

String taploeLocalizeText(BuildContext context, String value) =>
    TaploeTextScope.of(context).phrase(value);

String? taploeLocalizeNullableText(BuildContext context, String? value) =>
    value == null ? null : taploeLocalizeText(context, value);

InlineSpan taploeLocalizeInlineSpan(BuildContext context, InlineSpan span) {
  if (span is TextSpan) {
    return TextSpan(
      text: span.text == null ? null : taploeLocalizeText(context, span.text!),
      children: span.children
          ?.map((child) => taploeLocalizeInlineSpan(context, child))
          .toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }
  return span;
}

class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: taploeState,
      builder: (context, _) {
        final localizedSemantics = semanticsLabel == null
            ? null
            : taploeLocalizeText(context, semanticsLabel!);
        if (textSpan != null) {
          return material.Text.rich(
            taploeLocalizeInlineSpan(context, textSpan!),
            style: style,
            strutStyle: strutStyle,
            textAlign: textAlign,
            textDirection: textDirection,
            locale: locale,
            softWrap: softWrap,
            overflow: overflow,
            textScaler: textScaler,
            maxLines: maxLines,
            semanticsLabel: localizedSemantics,
            textWidthBasis: textWidthBasis,
            textHeightBehavior: textHeightBehavior,
            selectionColor: selectionColor,
          );
        }
        return material.Text(
          taploeLocalizeText(context, data ?? ''),
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: localizedSemantics,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        );
      },
    );
  }
}

class IconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;
  final Color? color;
  final material.ButtonStyle? style;
  final bool _outlined;

  const IconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.padding,
    this.iconSize,
    this.color,
    this.style,
  }) : _outlined = false;

  const IconButton.outlined({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.padding,
    this.iconSize,
    this.color,
    this.style,
  }) : _outlined = true;

  static material.ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Size? minimumSize,
    Size? fixedSize,
    EdgeInsetsGeometry? padding,
    BorderSide? side,
    OutlinedBorder? shape,
  }) {
    return material.IconButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      minimumSize: minimumSize,
      fixedSize: fixedSize,
      padding: padding,
      side: side,
      shape: shape,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizedTooltip = taploeLocalizeNullableText(context, tooltip);
    if (_outlined) {
      return material.IconButton.outlined(
        icon: icon,
        onPressed: onPressed,
        tooltip: localizedTooltip,
        padding: padding,
        iconSize: iconSize,
        color: color,
        style: style,
      );
    }
    return material.IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: localizedTooltip,
      padding: padding,
      iconSize: iconSize,
      color: color,
      style: style,
    );
  }
}
