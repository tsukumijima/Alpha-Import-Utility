// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportedFileRecord _$ImportedFileRecordFromJson(Map<String, dynamic> json) => ImportedFileRecord(
  sourcePath: json['sourcePath'] as String,
  xxHash: json['xxHash'] as String,
  sourceCreatedTimeUtcMs: (json['sourceCreatedTimeUtcMs'] as num).toInt(),
  sourceModifiedTimeUtcMs: (json['sourceModifiedTimeUtcMs'] as num).toInt(),
  fileSize: (json['fileSize'] as num).toInt(),
  lightweightSignature: json['lightweightSignature'] == null
      ? null
      : FileLightweightSignature.fromJson(
          json['lightweightSignature'] as Map<String, dynamic>,
        ),
  importedAt: DateTime.parse(json['importedAt'] as String),
  destinationPath: json['destinationPath'] as String,
  appVersion: json['appVersion'] as String,
);

Map<String, dynamic> _$ImportedFileRecordToJson(ImportedFileRecord instance) => <String, dynamic>{
  'sourcePath': instance.sourcePath,
  'xxHash': instance.xxHash,
  'sourceCreatedTimeUtcMs': instance.sourceCreatedTimeUtcMs,
  'sourceModifiedTimeUtcMs': instance.sourceModifiedTimeUtcMs,
  'fileSize': instance.fileSize,
  'lightweightSignature': instance.lightweightSignature,
  'importedAt': instance.importedAt.toIso8601String(),
  'destinationPath': instance.destinationPath,
  'appVersion': instance.appVersion,
};

FileLightweightSignature _$FileLightweightSignatureFromJson(
  Map<String, dynamic> json,
) => FileLightweightSignature(
  chunkSize: (json['chunkSize'] as num).toInt(),
  headHash: json['headHash'] as String,
  middleHash: json['middleHash'] as String,
  tailHash: json['tailHash'] as String,
);

Map<String, dynamic> _$FileLightweightSignatureToJson(
  FileLightweightSignature instance,
) => <String, dynamic>{
  'chunkSize': instance.chunkSize,
  'headHash': instance.headHash,
  'middleHash': instance.middleHash,
  'tailHash': instance.tailHash,
};

ImportMetadata _$ImportMetadataFromJson(Map<String, dynamic> json) => ImportMetadata(
  version: json['version'] as String? ?? '2.0.0',
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  files: (json['files'] as List<dynamic>).map((e) => ImportedFileRecord.fromJson(e as Map<String, dynamic>)).toList(),
);

Map<String, dynamic> _$ImportMetadataToJson(ImportMetadata instance) => <String, dynamic>{
  'version': instance.version,
  'lastUpdated': instance.lastUpdated.toIso8601String(),
  'files': instance.files,
};
