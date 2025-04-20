import '../models/archive.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/archive_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // 导入 foundation 包，用于 debugPrint
import 'api_service.dart';
import 'conversation_service.dart';
import 'dart:convert';

// 提供 ApiService 的 Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// 提供 ConversationService 的 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService();
});

// 提供 ArchiveService 的 Provider
final archiveServiceProvider = Provider<ArchiveService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final conversationService = ref.watch(conversationServiceProvider);
  return ArchiveService(apiService: apiService, conversationService: conversationService);
});

class ArchiveService {
  final ApiService apiService;
  final ConversationService conversationService;

  ArchiveService({required this.apiService, required this.conversationService});

  // 创建新存档
  Future<Archive?> createArchive({
    required String name,
    required Conversation conversation,
    required int startIndex,
    required int endIndex,
  }) async {
    try {
      // 验证索引范围
      if (startIndex < 0 || endIndex >= conversation.messages.length || startIndex > endIndex) {
        debugPrint("[ArchiveService] Invalid index range: $startIndex to $endIndex");
        return null;
      }

      // 提取指定范围的消息
      final messages = conversation.messages.sublist(startIndex, endIndex + 1);

      // 创建存档
      final archive = Archive.create(
        name: name,
        conversationUuid: conversation.uuid,
        messages: messages,
        startIndex: startIndex,
        endIndex: endIndex,
      );

      // 保存存档
      final success = await archive.save();
      if (success) {
        return archive;
      }

      return null;
    } catch (e) {
      debugPrint("[ArchiveService] Error creating archive: $e");
      return null;
    }
  }

  // 加载所有存档
  Future<List<Archive>> loadAllArchives() async {
    return await Archive.loadAll();
  }

  // 加载特定存档
  Future<Archive?> loadArchive(String uuid) async {
    return await Archive.read(uuid);
  }

  // 删除存档
  Future<bool> deleteArchive(String uuid) async {
    return await Archive.delete(uuid);
  }

  // 重命名存档
  Future<bool> renameArchive(String uuid, String newName) async {
    try {
      final archive = await Archive.read(uuid);
      if (archive != null) {
        final updatedArchive = archive.copyWith(name: newName);
        return await updatedArchive.save();
      }
      return false;
    } catch (e) {
      debugPrint("[ArchiveService] Error renaming archive: $e");
      return false;
    }
  }

  // 查找特定对话的所有存档
  Future<List<Archive>> findArchivesByConversation(String conversationUuid) async {
    final allArchives = await loadAllArchives();
    return allArchives.where((archive) => archive.conversationUuid == conversationUuid).toList();
  }

  // 查找最近的存档点
  Future<int?> findLastArchivePoint(String conversationUuid, int currentIndex) async {
    try {
      final conversationArchives = await findArchivesByConversation(conversationUuid);

      // 按结束索引排序
      conversationArchives.sort((a, b) => b.endIndex.compareTo(a.endIndex));

      // 查找最近的存档点（小于当前索引）
      for (final archive in conversationArchives) {
        if (archive.endIndex < currentIndex) {
          return archive.endIndex;
        }
      }

      // 如果没有找到，返回 null（表示从开始）
      return null;
    } catch (e) {
      debugPrint("[ArchiveService] Error finding last archive point: $e");
      return null;
    }
  }

  // 获取所有存档点
  Future<List<Map<String, dynamic>>> getAllArchivePoints(String conversationUuid, int currentIndex) async {
    try {
      final conversationArchives = await findArchivesByConversation(conversationUuid);

      // 过滤出在当前索引之前的存档点
      final filteredArchives = conversationArchives.where((archive) => archive.endIndex < currentIndex).toList();

      // 按结束索引排序（从大到小）
      filteredArchives.sort((a, b) => b.endIndex.compareTo(a.endIndex));

      // 转换为简单的数据结构，方便在UI中使用
      return filteredArchives.map((archive) => {
        'uuid': archive.uuid,
        'name': archive.name,
        'endIndex': archive.endIndex,
        'displayText': '${archive.name} (消息 ${archive.endIndex + 1})'
      }).toList();
    } catch (e) {
      debugPrint("[ArchiveService] Error getting all archive points: $e");
      return [];
    }
  }

  // 为存档生成AI摘要
  Future<bool> generateSummary(String archiveUuid) async {
    try {
      // 加载存档
      final archive = await loadArchive(archiveUuid);
      if (archive == null) {
        debugPrint("[ArchiveService] Archive not found: $archiveUuid");
        return false;
      }

      // 准备消息内容
      final messagesText = archive.messages.map((msg) => msg.text).join("\n\n");

      // 获取对话的系统提示词
      String worldSetting = "";
      try {
        final conversation = await conversationService.loadConversation(archive.conversationUuid);
        if (conversation != null && conversation.systemPrompt != null && conversation.systemPrompt!.isNotEmpty) {
          // 将完整的系统提示词添加到世界观设定中
          worldSetting = "\n# 世界观设定\n${conversation.systemPrompt}";

          // 仅打印简短的日志，避免在控制台显示完整的提示词
          debugPrint("[ArchiveService] 成功加载对话系统提示词，长度: ${conversation.systemPrompt!.length}");

          // 打印系统提示词的前100个字符作为预览
          final previewText = conversation.systemPrompt!.length > 100
              ? "${conversation.systemPrompt!.substring(0, 100)}..."
              : conversation.systemPrompt!;
          debugPrint("[ArchiveService] 提示词预览: $previewText");
        } else {
          debugPrint("[ArchiveService] 对话没有系统提示词");
        }
      } catch (e) {
        debugPrint("[ArchiveService] 加载对话系统提示词时出错: $e");
      }

      // 准备系统提示词
      final systemPrompt = """<system_prompt>
#角色
你是一个经验丰富的小说读者，你对于小说中的线索整理和剧情分析十分有经验
# 任务
你需要把下面的文本按小说进行解析，分析出时间（早中晚或者文中提到了某个明显的事件的相对时间）、地点、人物，以及每个人物做的事。最后再输出一个总的对这个故事片段的重述，200字以内。
# 输出格式
请直接输出原始的JSON字符串，不要使用```json和```标记包裹输出内容。输出的内容要确保可直接序列化，你只需要输出下面格式对应的内容，无需再输出其他内容：
{
   "time":"时间",
"place":"地点",
"keywords":["这个故事中的重要信息，词汇/短语维度，2-12个字",...如果有继续添加],
"desc":"这一段故事的概要，200-400个字。"
"characters":[{
"name":"角色名",
"events":[{"name":"事件名", "desc":"该角色在事件中做的事描述一下，50-100字"},...如果有其他继续添加]
},...如果有继续添加]
}$worldSetting
</system_prompt>""";

      // 调用 API 生成摘要
      final response = await apiService.getChatCompletion(
        [ChatMessage(sender: MessageSender.user, text: messagesText, timestamp: DateTime.now())],
        systemPromptOverride: systemPrompt
      );

      if (response == null || response.isEmpty) {
        debugPrint("[ArchiveService] Failed to generate summary: Empty response");
        return false;
      }

      // 解析 JSON 响应
      try {
        // 处理可能被包裹在```json和```标记中的内容
        String cleanedResponse = response;

        // 检查是否包含```json标记
        final jsonCodeBlockRegex = RegExp(r'```(?:json)?(.*?)```', dotAll: true);
        final match = jsonCodeBlockRegex.firstMatch(response);
        if (match != null && match.groupCount >= 1) {
          cleanedResponse = match.group(1)?.trim() ?? response;
          debugPrint("[ArchiveService] 检测到代码块标记，已提取内容");
        }

        debugPrint("[ArchiveService] 清理后的响应: $cleanedResponse");
        final jsonResponse = jsonDecode(cleanedResponse) as Map<String, dynamic>;

        // 创建摘要对象
        final summary = ArchiveSummary(
          time: jsonResponse['time'] as String? ?? '',
          place: jsonResponse['place'] as String? ?? '',
          keywords: (jsonResponse['keywords'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
          desc: jsonResponse['desc'] as String? ?? '',
          characters: (jsonResponse['characters'] as List<dynamic>?)?.map((c) {
            final character = c as Map<String, dynamic>;
            return Character(
              name: character['name'] as String? ?? '',
              events: (character['events'] as List<dynamic>?)?.map((e) {
                final event = e as Map<String, dynamic>;
                return CharacterEvent(
                  name: event['name'] as String? ?? '',
                  desc: event['desc'] as String? ?? ''
                );
              }).toList() ?? []
            );
          }).toList() ?? []
        );

        // 更新存档并保存
        final updatedArchive = archive.copyWith(summary: summary);
        final success = await updatedArchive.save();

        return success;
      } catch (e) {
        debugPrint("[ArchiveService] Error parsing summary JSON: $e");
        debugPrint("[ArchiveService] Raw response: $response");
        return false;
      }
    } catch (e) {
      debugPrint("[ArchiveService] Error generating summary: $e");
      return false;
    }
  }
}
