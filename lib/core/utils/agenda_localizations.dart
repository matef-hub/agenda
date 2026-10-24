import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'arabic_format.dart';

class AgendaMaterialLocalizations extends MaterialLocalizationAr {
  AgendaMaterialLocalizations()
    : super(
        localeName: 'ar',
        fullYearFormat: DateFormat.y('ar'),
        compactDateFormat: DateFormat('d/M/y', 'ar'),
        shortDateFormat: DateFormat.yMMMd('ar'),
        mediumDateFormat: DateFormat.MMMEd('ar'),
        longDateFormat: DateFormat.yMMMMEEEEd('ar'),
        yearMonthFormat: DateFormat.yMMMM('ar'),
        shortMonthDayFormat: DateFormat.MMMd('ar'),
        decimalFormat: NumberFormat.decimalPattern('ar'),
        twoDigitZeroPaddedFormat: NumberFormat('00', 'ar'),
      );
  @override
  String formatDecimal(int number) => ArabicFormat.digits(number);
  @override
  String formatYear(DateTime date) => ArabicFormat.digits(date.year);
  @override
  String formatCompactDate(DateTime date) => ArabicFormat.date(date);
  @override
  String formatShortDate(DateTime date) =>
      ArabicFormat.digits(super.formatShortDate(date));
  @override
  String formatMediumDate(DateTime date) =>
      ArabicFormat.digits(super.formatMediumDate(date));
  @override
  String formatFullDate(DateTime date) =>
      ArabicFormat.digits(super.formatFullDate(date));
  @override
  String formatMonthYear(DateTime date) =>
      ArabicFormat.digits(super.formatMonthYear(date));
  @override
  String formatShortMonthDay(DateTime date) =>
      ArabicFormat.digits(super.formatShortMonthDay(date));
  @override
  String formatMinute(TimeOfDay timeOfDay) =>
      ArabicFormat.digits(super.formatMinute(timeOfDay));
  @override
  String formatHour(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => ArabicFormat.digits(
    super.formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat),
  );
  @override
  DateTime? parseCompactDate(String? inputString) =>
      inputString == null ? null : ArabicFormat.parseDate(inputString);
}

class AgendaLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const AgendaLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Initialize intl data using Flutter's delegate before constructing formats.
    await GlobalMaterialLocalizations.delegate.load(locale);
    return AgendaMaterialLocalizations();
  }

  @override
  bool shouldReload(AgendaLocalizationsDelegate old) => false;
}
