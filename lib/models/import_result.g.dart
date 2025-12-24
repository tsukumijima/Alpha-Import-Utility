// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportedFileRecord _$ImportedFileRecordFromJson(Map<String, dynamic> json) =>
    ImportedFileRecord(
      sourcePath: json['sourcePath'] as String,
      xxHash: json['xxHash'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      importedAt: DateTime.parse(json['importedAt'] as String),
      destinationPath: json['destinationPath'] as String,
      appVersion: json['appVersion'] as String,
    );

Map<String, dynamic> _$ImportedFileRecordToJson(ImportedFileRecord instance) =>
    <String, dynamic>{
      'sourcePath': instance.sourcePath,
      'xxHash': instance.xxHash,
      'fileSize': instance.fileSize,
      'importedAt': instance.importedAt.toIso8601String(),
      'destinationPath': instance.destinationPath,
      'appVersion': instance.appVersion,
    };

ImportMetadata _$ImportMetadataFromJson(Map<String, dynamic> json) =>
    ImportMetadata(
      version: json['version'] as String? ?? '1.0.0',
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      files: (json['files'] as List<dynamic>)
          .map((e) => ImportedFileRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ImportMetadataToJson(ImportMetadata instance) =>
    <String, dynamic>{
      'version': instance.version,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'files': instance.files,
    };
