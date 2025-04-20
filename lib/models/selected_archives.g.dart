// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_archives.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SelectedArchiveInfo _$SelectedArchiveInfoFromJson(Map<String, dynamic> json) =>
    SelectedArchiveInfo(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      time: json['time'] as String,
      place: json['place'] as String,
      desc: json['desc'] as String,
    );

Map<String, dynamic> _$SelectedArchiveInfoToJson(
  SelectedArchiveInfo instance,
) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'time': instance.time,
  'place': instance.place,
  'desc': instance.desc,
};
