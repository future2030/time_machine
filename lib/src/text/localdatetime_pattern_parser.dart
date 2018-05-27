// https://github.com/nodatime/nodatime/blob/master/src/NodaTime/Text/LocalDateTimePatternParser.cs
// 69dedbc  on Apr 23

import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_utilities.dart';
import 'package:time_machine/time_machine_calendars.dart';
import 'package:time_machine/time_machine_timezones.dart';
import 'package:time_machine/time_machine_text.dart';
import 'package:time_machine/time_machine_patterns.dart';


/// <summary>
/// Parser for patterns of <see cref="LocalDateTime"/> values.
/// </summary>
@internal /*sealed*/ class LocalDateTimePatternParser implements IPatternParser<LocalDateTime> {
// Split the template value into date and time once, to avoid doing it every time we parse.
  @private final LocalDate templateValueDate;
  @private final LocalTime templateValueTime;

  @private static final Map<String /*char*/, CharacterHandler<LocalDateTime, LocalDateTimeParseBucket>> PatternCharacterHandlers =
  {
    '%': SteppedPatternBuilder.HandlePercent /**<LocalDateTime, LocalDateTimeParseBucket>*/,
    '\'': SteppedPatternBuilder.HandleQuote /**<LocalDateTime, LocalDateTimeParseBucket>*/,
    '\"': SteppedPatternBuilder.HandleQuote /**<LocalDateTime, LocalDateTimeParseBucket>*/,
    '\\': SteppedPatternBuilder.HandleBackslash /**<LocalDateTime, LocalDateTimeParseBucket>*/,
    '/': (pattern, builder) => builder.AddLiteral1(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch /**<LocalDateTime>*/),
    'T': (pattern, builder) => builder.AddLiteral2('T', ParseResult.MismatchedCharacter /**<LocalDateTime>*/),
    'y': DatePatternHelper.CreateYearOfEraHandler<LocalDateTime, LocalDateTimeParseBucket>((value) => value.YearOfEra, (bucket, value) =>
    bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField /**<LocalDateTime, LocalDateTimeParseBucket>*/
      (4, PatternFields.year, -9999, 9999, (value) => value.Year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<LocalDateTime, LocalDateTimeParseBucket>
      ((value) => value.Month, (bucket, value) => bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<LocalDateTime, LocalDateTimeParseBucket>
      ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.Date.DayOfMonth = value, (bucket, value) =>
    bucket.Date.DayOfWeek = value),
    '.': TimePatternHelper.CreatePeriodHandler<LocalDateTime, LocalDateTimeParseBucket>(
        9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<LocalDateTime, LocalDateTimeParseBucket>(
        9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral1(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch /**<LocalDateTime>*/),
    'h': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimeParseBucket>
      (2, PatternFields.hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimeParseBucket>
      (2, PatternFields.hours24, 0, 24, (value) => value.Hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimeParseBucket>
      (2, PatternFields.minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimeParseBucket>
      (2, PatternFields.seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<LocalDateTime, LocalDateTimeParseBucket>(
        9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<LocalDateTime, LocalDateTimeParseBucket>(
        9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<LocalDateTime, LocalDateTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.Time.AmPm = value),
    'c': DatePatternHelper.CreateCalendarHandler<LocalDateTime, LocalDateTimeParseBucket>((value) => value.Calendar, (bucket, value) =>
    bucket.Date.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<LocalDateTime, LocalDateTimeParseBucket>((value) => value.era, (bucket) => bucket.Date),
    'l': (cursor, builder) =>
        builder.AddEmbeddedLocalPartial(cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.Date, (value) => value.TimeOfDay, null),
  };

  @internal LocalDateTimePatternParser(LocalDateTime templateValue)
      : templateValueDate = templateValue.Date,
        templateValueTime = templateValue.TimeOfDay;

// Note: to implement the interface. It does no harm, and it's simpler than using explicit
// interface implementation.
  IPattern<LocalDateTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in LocalDateTimePattern.
    if (patternText.length == 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      String /*char*/ patternCharacter = patternText[0];
      if (patternCharacter == 'o' || patternCharacter == 'O') {
        return LocalDateTimePattern.Patterns.BclRoundtripPatternImpl;
      }
      if (patternCharacter == 'r') {
        return LocalDateTimePattern.Patterns.FullRoundtripPatternImpl;
      }
      if (patternCharacter == 'R') {
        return LocalDateTimePattern.Patterns.FullRoundtripWithoutCalendarImpl;
      }
      if (patternCharacter == 's') {
        return LocalDateTimePattern.Patterns.GeneralIsoPatternImpl;
      }
      patternText = ExpandStandardFormatPattern(patternCharacter, formatInfo);
      if (patternText == null) {
        throw new InvalidPatternError.format(TextErrorMessages.UnknownStandardFormat, [patternCharacter, 'LocalDateTime']);
      }
    }

    var patternBuilder = new SteppedPatternBuilder<LocalDateTime, LocalDateTimeParseBucket>(formatInfo,
            () => new LocalDateTimeParseBucket(templateValueDate, templateValueTime));
    patternBuilder.ParseCustomPattern(patternText, PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    return patternBuilder.Build(templateValueDate.At(templateValueTime));
  }

  @private String ExpandStandardFormatPattern(/*char*/ String patternCharacter, NodaFormatInfo formatInfo) {
    switch (patternCharacter) {
      case 'f':
        return formatInfo.DateTimeFormat.LongDatePattern + " " + formatInfo.DateTimeFormat.ShortTimePattern;
      case 'F':
        return formatInfo.DateTimeFormat.FullDateTimePattern;
      case 'g':
        return formatInfo.DateTimeFormat.ShortDatePattern + " " + formatInfo.DateTimeFormat.ShortTimePattern;
      case 'G':
        return formatInfo.DateTimeFormat.ShortDatePattern + " " + formatInfo.DateTimeFormat.LongTimePattern;
      default:
        // Will be turned into an exception.
        return null;
    }
  }
}

@internal /*sealed*/ class LocalDateTimeParseBucket extends ParseBucket<LocalDateTime> {
  @internal final /*LocalDatePatternParser.*/LocalDateParseBucket Date;
  @internal final /*LocalTimePatternParser.*/LocalTimeParseBucket Time;

  @internal LocalDateTimeParseBucket(LocalDate templateValueDate, LocalTime templateValueTime)
      : Date = new /*LocalDatePatternParser.*/LocalDateParseBucket(templateValueDate),
        Time = new /*LocalTimePatternParser.*/LocalTimeParseBucket(templateValueTime);

  /// <summary>
  /// Combines the values in a date bucket with the values in a time bucket.
  /// </summary>
  /// <remarks>
  /// This would normally be the <see cref="CalculateValue"/> method, but we want
  /// to be able to use the same logic when parsing an <see cref="OffsetDateTime"/>
  /// and <see cref="ZonedDateTime"/>.
  /// </remarks>
  @internal static ParseResult<LocalDateTime> CombineBuckets(PatternFields usedFields,
/*LocalDatePatternParser.*/LocalDateParseBucket dateBucket,
/*LocalTimePatternParser.*/LocalTimeParseBucket timeBucket,
      String text) {
    // Handle special case of hour = 24
    bool hour24 = false;
    if (timeBucket.Hours24 == 24) {
      timeBucket.Hours24 = 0;
      hour24 = true;
    }

    ParseResult<LocalDate> dateResult = dateBucket.CalculateValue(usedFields & PatternFields.allDateFields, text);
    if (!dateResult.Success) {
      return dateResult.ConvertError<LocalDateTime>();
    }
    ParseResult<LocalTime> timeResult = timeBucket.CalculateValue(usedFields & PatternFields.allTimeFields, text);
    if (!timeResult.Success) {
      return timeResult.ConvertError<LocalDateTime>();
    }

    LocalDate date = dateResult.Value;
    LocalTime time = timeResult.Value;

    if (hour24) {
      if (time != LocalTime.Midnight) {
        return ParseResult.InvalidHour24<LocalDateTime>(text);
      }
      date = date.PlusDays(1);
    }
    return ParseResult.ForValue<LocalDateTime>(date.At(time));
  }

  @internal
  @override
  ParseResult<LocalDateTime> CalculateValue(PatternFields usedFields, String text) =>
      CombineBuckets(usedFields, Date, Time, text);
}
