import 'package:json_annotation/json_annotation.dart';
import 'archive.dart';
import 'archive_summary.dart';

part 'selected_archives.g.dart'; // Will be generated

@JsonSerializable(explicitToJson: true)
class SelectedArchiveInfo {
  final String uuid;
  final String name;
  final String time;
  final String place;
  final String desc;

  SelectedArchiveInfo({
    required this.uuid,
    required this.name,
    required this.time,
    required this.place,
    required this.desc,
  });

  // Factory constructor from Archive
  factory SelectedArchiveInfo.fromArchive(Archive archive) {
    if (archive.summary == null) {
      throw Exception('Archive must have a summary');
    }
    
    return SelectedArchiveInfo(
      uuid: archive.uuid,
      name: archive.name,
      time: archive.summary!.time,
      place: archive.summary!.place,
      desc: archive.summary!.desc,
    );
  }

  // From JSON
  factory SelectedArchiveInfo.fromJson(Map<String, dynamic> json) => _$SelectedArchiveInfoFromJson(json);

  // To JSON
  Map<String, dynamic> toJson() => _$SelectedArchiveInfoToJson(this);
}

class SelectedArchives {
  final List<SelectedArchiveInfo> archives;

  SelectedArchives({
    required this.archives,
  });

  // Add an archive
  SelectedArchives add(SelectedArchiveInfo archive) {
    // Check if already exists
    if (archives.any((a) => a.uuid == archive.uuid)) {
      return this;
    }
    
    return SelectedArchives(
      archives: [...archives, archive],
    );
  }

  // Remove an archive
  SelectedArchives remove(String uuid) {
    return SelectedArchives(
      archives: archives.where((a) => a.uuid != uuid).toList(),
    );
  }

  // Clear all archives
  SelectedArchives clear() {
    return SelectedArchives(
      archives: [],
    );
  }

  // Check if empty
  bool get isEmpty => archives.isEmpty;

  // Check if not empty
  bool get isNotEmpty => archives.isNotEmpty;

  // Get count
  int get count => archives.length;

  // Create empty
  factory SelectedArchives.empty() {
    return SelectedArchives(
      archives: [],
    );
  }

  // Generate system prompt prefix
  String generateSystemPromptPrefix() {
    if (archives.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('# 前置事件');
    
    for (final archive in archives) {
      buffer.writeln('【${archive.time}】【${archive.place}】【${archive.desc}】');
    }
    
    buffer.writeln();
    return buffer.toString();
  }
}
