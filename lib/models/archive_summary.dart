import 'package:json_annotation/json_annotation.dart';

part 'archive_summary.g.dart'; // Will be generated

@JsonSerializable(explicitToJson: true)
class ArchiveSummary {
  final String time;
  final String place;
  final List<String> keywords;
  final String desc;
  final List<Character> characters;

  ArchiveSummary({
    required this.time,
    required this.place,
    required this.keywords,
    required this.desc,
    required this.characters,
  });

  // Factory constructor for JSON deserialization
  factory ArchiveSummary.fromJson(Map<String, dynamic> json) => _$ArchiveSummaryFromJson(json);

  // Method for JSON serialization
  Map<String, dynamic> toJson() => _$ArchiveSummaryToJson(this);

  // Create an empty summary
  factory ArchiveSummary.empty() {
    return ArchiveSummary(
      time: '',
      place: '',
      keywords: [],
      desc: '',
      characters: [],
    );
  }
}

@JsonSerializable(explicitToJson: true)
class Character {
  final String name;
  final List<CharacterEvent> events;

  Character({
    required this.name,
    required this.events,
  });

  // Factory constructor for JSON deserialization
  factory Character.fromJson(Map<String, dynamic> json) => _$CharacterFromJson(json);

  // Method for JSON serialization
  Map<String, dynamic> toJson() => _$CharacterToJson(this);
}

@JsonSerializable()
class CharacterEvent {
  final String name;
  final String desc;

  CharacterEvent({
    required this.name,
    required this.desc,
  });

  // Factory constructor for JSON deserialization
  factory CharacterEvent.fromJson(Map<String, dynamic> json) => _$CharacterEventFromJson(json);

  // Method for JSON serialization
  Map<String, dynamic> toJson() => _$CharacterEventToJson(this);
}
