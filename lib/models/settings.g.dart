// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportSettings _$ImportSettingsFromJson(Map<String, dynamic> json) =>
    ImportSettings(
      destinationFolder: json['destinationFolder'] as String,
      subfolderPattern:
          $enumDecodeNullable(
            _$SubfolderPatternEnumMap,
            json['subfolderPattern'],
          ) ??
          SubfolderPattern.DateOnly,
      dateFormat:
          $enumDecodeNullable(_$DateFormatStyleEnumMap, json['dateFormat']) ??
          DateFormatStyle.YYYYMMDD,
      dateSeparator:
          $enumDecodeNullable(_$DateSeparatorEnumMap, json['dateSeparator']) ??
          DateSeparator.Underscore,
      cameraTimezone: json['cameraTimezone'] as String? ?? 'Asia/Tokyo',
      isRestoreDateTimeFromExif:
          json['isRestoreDateTimeFromExif'] as bool? ?? true,
      dateRestoreToleranceSeconds:
          (json['dateRestoreToleranceSeconds'] as num?)?.toInt() ?? 30,
      isImportVideoXML: json['isImportVideoXML'] as bool? ?? false,
      isImportProxyVideos: json['isImportProxyVideos'] as bool? ?? true,
    );

Map<String, dynamic> _$ImportSettingsToJson(ImportSettings instance) =>
    <String, dynamic>{
      'destinationFolder': instance.destinationFolder,
      'subfolderPattern': _$SubfolderPatternEnumMap[instance.subfolderPattern]!,
      'dateFormat': _$DateFormatStyleEnumMap[instance.dateFormat]!,
      'dateSeparator': _$DateSeparatorEnumMap[instance.dateSeparator]!,
      'cameraTimezone': instance.cameraTimezone,
      'isRestoreDateTimeFromExif': instance.isRestoreDateTimeFromExif,
      'dateRestoreToleranceSeconds': instance.dateRestoreToleranceSeconds,
      'isImportVideoXML': instance.isImportVideoXML,
      'isImportProxyVideos': instance.isImportProxyVideos,
    };

const _$SubfolderPatternEnumMap = {
  SubfolderPattern.DateOnly: 'DateOnly',
  SubfolderPattern.YearAndDate: 'YearAndDate',
  SubfolderPattern.YearMonthAndDate: 'YearMonthAndDate',
};

const _$DateFormatStyleEnumMap = {
  DateFormatStyle.YYYYMMDD: 'YYYYMMDD',
  DateFormatStyle.YYMMDD: 'YYMMDD',
};

const _$DateSeparatorEnumMap = {
  DateSeparator.None: 'None',
  DateSeparator.Underscore: 'Underscore',
  DateSeparator.Hyphen: 'Hyphen',
};

WindowSettings _$WindowSettingsFromJson(Map<String, dynamic> json) =>
    WindowSettings(
      width: (json['width'] as num?)?.toDouble() ?? 800,
      height: (json['height'] as num?)?.toDouble() ?? 600,
      positionX: (json['positionX'] as num?)?.toDouble(),
      positionY: (json['positionY'] as num?)?.toDouble(),
      isMaximized: json['isMaximized'] as bool? ?? false,
    );

Map<String, dynamic> _$WindowSettingsToJson(WindowSettings instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'positionX': instance.positionX,
      'positionY': instance.positionY,
      'isMaximized': instance.isMaximized,
    };
