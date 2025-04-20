// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArchiveSummary _$ArchiveSummaryFromJson(Map<String, dynamic> json) =>
    ArchiveSummary(
      time: json['time'] as String,
      place: json['place'] as String,
      keywords:
          (json['keywords'] as List<dynamic>).map((e) => e as String).toList(),
      desc: json['desc'] as String,
      characters:
          (json['characters'] as List<dynamic>)
              .map((e) => Character.fromJson(e as Map<String, dynamic>))
              .toList(),
    );

Map<String, dynamic> _$ArchiveSummaryToJson(ArchiveSummary instance) =>
    <String, dynamic>{
      'time': instance.time,
      'place': instance.place,
      'keywords': instance.keywords,
      'desc': instance.desc,
      'characters': instance.characters.map((e) => e.toJson()).toList(),
    };

Character _$CharacterFromJson(Map<String, dynamic> json) => Character(
  name: json['name'] as String,
  events:
      (json['events'] as List<dynamic>)
          .map((e) => CharacterEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$CharacterToJson(Character instance) => <String, dynamic>{
  'name': instance.name,
  'events': instance.events.map((e) => e.toJson()).toList(),
};

CharacterEvent _$CharacterEventFromJson(Map<String, dynamic> json) =>
    CharacterEvent(name: json['name'] as String, desc: json['desc'] as String);

Map<String, dynamic> _$CharacterEventToJson(CharacterEvent instance) =>
    <String, dynamic>{'name': instance.name, 'desc': instance.desc};
