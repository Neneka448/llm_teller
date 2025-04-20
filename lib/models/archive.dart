import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import '../services/persistable.dart';
import 'chat_message.dart';
import 'archive_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

part 'archive.g.dart'; // 将由 build_runner 生成

@JsonSerializable(explicitToJson: true)
class Archive implements Persistable<Archive> {
  final String uuid;
  String name;
  final String conversationUuid; // 关联的对话 UUID
  final List<ChatMessage> messages; // 存档的消息
  final int startIndex; // 开始消息索引
  final int endIndex; // 结束消息索引
  final DateTime createdAt;
  ArchiveSummary? summary; // AI生成的摘要

  Archive({
    required this.uuid,
    required this.name,
    required this.conversationUuid,
    required this.messages,
    required this.startIndex,
    required this.endIndex,
    required this.createdAt,
    this.summary,
  });

  // 创建新存档的工厂方法
  factory Archive.create({
    required String name,
    required String conversationUuid,
    required List<ChatMessage> messages,
    required int startIndex,
    required int endIndex,
  }) {
    return Archive(
      uuid: Uuid().v4(),
      name: name,
      conversationUuid: conversationUuid,
      messages: messages,
      startIndex: startIndex,
      endIndex: endIndex,
      createdAt: DateTime.now(),
    );
  }

  // 从 JSON 反序列化
  factory Archive.fromJson(Map<String, dynamic> json) => _$ArchiveFromJson(json);

  // 序列化为 JSON
  @override
  Map<String, dynamic> toJson() => _$ArchiveToJson(this);

  // 获取存档的预览文本
  String get previewText {
    if (messages.isEmpty) return "空存档";

    // 获取第一条消息的预览
    final firstMessage = messages.first;
    String text = firstMessage.text.replaceAll('\n', ' ');
    const maxLength = 50;
    if (text.length > maxLength) {
      text = text.substring(0, maxLength) + "...";
    }
    return text;
  }

  // 获取存档的范围描述
  String get rangeDescription {
    return "消息 $startIndex 到 $endIndex";
  }

  // 获取存档的摘要描述（用于显示在列表中）
  String get summaryDescription {
    if (summary == null || summary!.desc.isEmpty) {
      return previewText;
    }
    return summary!.desc;
  }

  // 实现 Persistable 接口的 save 方法
  @override
  Future<bool> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存存档数据
      final jsonString = jsonEncode(toJson());
      final archiveKey = 'archive_$uuid';
      final success = await prefs.setString(archiveKey, jsonString);

      if (success) {
        // 更新存档索引
        List<String> archiveUuids = prefs.getStringList('archive_uuids') ?? [];
        if (!archiveUuids.contains(uuid)) {
          archiveUuids.add(uuid);
          await prefs.setStringList('archive_uuids', archiveUuids);
        }
      }

      return success;
    } catch (e) {
      print("[Archive] Error saving archive: $e");
      return false;
    }
  }

  // 实现 Persistable 接口的 read 静态方法
  static Future<Archive?> read(String uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('archive_$uuid');

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return Archive.fromJson(json);
      }

      return null;
    } catch (e) {
      print("[Archive] Error reading archive: $e");
      return null;
    }
  }

  // 加载所有存档
  static Future<List<Archive>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final archiveUuids = prefs.getStringList('archive_uuids') ?? [];
      final archives = <Archive>[];

      for (final uuid in archiveUuids) {
        final archive = await read(uuid);
        if (archive != null) {
          archives.add(archive);
        }
      }

      // 按创建时间排序，最新的在前面
      archives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return archives;
    } catch (e) {
      print("[Archive] Error loading all archives: $e");
      return [];
    }
  }

  // 删除存档
  static Future<bool> delete(String uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 从索引中移除
      List<String> archiveUuids = prefs.getStringList('archive_uuids') ?? [];
      archiveUuids.remove(uuid);
      await prefs.setStringList('archive_uuids', archiveUuids);

      // 删除存档数据
      await prefs.remove('archive_$uuid');

      return true;
    } catch (e) {
      print("[Archive] Error deleting archive: $e");
      return false;
    }
  }
}

// 用于 copyWith 模式的扩展
extension ArchiveCopyWith on Archive {
  Archive copyWith({
    String? uuid,
    String? name,
    String? conversationUuid,
    List<ChatMessage>? messages,
    int? startIndex,
    int? endIndex,
    DateTime? createdAt,
    ArchiveSummary? summary,
  }) {
    return Archive(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      conversationUuid: conversationUuid ?? this.conversationUuid,
      messages: messages ?? this.messages,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      createdAt: createdAt ?? this.createdAt,
      summary: summary ?? this.summary,
    );
  }
}
