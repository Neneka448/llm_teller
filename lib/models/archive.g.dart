// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Archive _$ArchiveFromJson(Map<String, dynamic> json) => Archive(
  uuid: json['uuid'] as String,
  name: json['name'] as String,
  conversationUuid: json['conversationUuid'] as String,
  messages:
      (json['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
  startIndex: (json['startIndex'] as num).toInt(),
  endIndex: (json['endIndex'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  summary:
      json['summary'] == null
          ? null
          : ArchiveSummary.fromJson(json['summary'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ArchiveToJson(Archive instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'conversationUuid': instance.conversationUuid,
  'messages': instance.messages.map((e) => e.toJson()).toList(),
  'startIndex': instance.startIndex,
  'endIndex': instance.endIndex,
  'createdAt': instance.createdAt.toIso8601String(),
  'summary': instance.summary?.toJson(),
};
