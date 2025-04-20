import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import 'dart:async';

class ConversationService {
  static const _conversationIndexKey = 'conversation_uuids';
  static const _conversationPrefix = 'conversation_';
  static const _lastOpenedConversationUuidKey = 'lastOpenedConversationUuid';

  String _getConversationKey(String uuid) => '$_conversationPrefix$uuid';

  // --- Load Methods ---
  Future<List<String>> _loadConversationUuids() async {
     final prefs = await SharedPreferences.getInstance();
     final uuids = prefs.getStringList(_conversationIndexKey) ?? [];
     print("[ConvService][_loadConversationUuids] Loaded UUIDs from key '$_conversationIndexKey': $uuids"); // DEBUG
     return uuids;
  }

  Future<List<Conversation>> loadConversations() async {
    print("[ConvService][loadConversations] Attempting to load all conversations..."); // DEBUG
    final prefs = await SharedPreferences.getInstance();
    final List<String> uuids = await _loadConversationUuids();
    print("[ConvService][loadConversations] UUIDs to load: $uuids"); // DEBUG
    final List<Conversation> conversations = [];
    int loadErrors = 0;

    for (final uuid in uuids) {
      final jsonString = prefs.getString(_getConversationKey(uuid));
      if (jsonString != null) {
        try {
          conversations.add(Conversation.fromJson(jsonDecode(jsonString) as Map<String, dynamic>));
        } catch (e) {
           print("[ConvService] Error decoding conversation $uuid: $e");
           loadErrors++;
           // Optionally remove corrupted data
           // await prefs.remove(_getConversationKey(uuid));
        }
      } else {
         print("[ConvService] Warning: UUID $uuid found in index but data missing.");
         loadErrors++;
         // Optionally remove dangling UUID from index (needs careful handling)
      }
    }
     print("[ConvService] Loaded ${conversations.length} conversations with $loadErrors errors.");
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  Future<Conversation?> loadConversation(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_getConversationKey(uuid));
    if (jsonString != null) {
       try {
         return Conversation.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
       } catch (e) {
         print("[ConvService] Error decoding conversation $uuid: $e");
         return null;
       }
    }
    return null;
  }

  // --- Save Method ---
  Future<bool> saveConversation(Conversation conversation) async {
    final stopwatch = Stopwatch()..start();
    print("[ConvService] Starting saveConversation for ${conversation.uuid}");
    bool conversationDataSaved = false;
    bool indexSaved = false;

    // 更新时间戳
    conversation.updatedAt = DateTime.now();
    final String conversationKey = _getConversationKey(conversation.uuid);

    // 尝试将对话转换为JSON
    String jsonString = "";
    try {
      jsonString = jsonEncode(conversation.toJson());
      print("[ConvService] JSON encoding complete. Size: ${jsonString.length} chars. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
    } catch (e) {
      print("[ConvService] *** ERROR during JSON encoding: $e. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
      stopwatch.stop();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // 先保存对话数据
    print("[ConvService] Preparing to save data directly for ${conversationKey}. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
    try {
      conversationDataSaved = await prefs.setString(conversationKey, jsonString);
      if (!conversationDataSaved) {
        print("[ConvService] *** WARNING: prefs.setString failed for ${conversation.uuid}. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
        // 尝试再次保存对话数据
        await Future.delayed(Duration(milliseconds: 500));
        conversationDataSaved = await prefs.setString(conversationKey, jsonString);
        if (!conversationDataSaved) {
          print("[ConvService] *** ERROR: Second attempt to save conversation data failed. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
          stopwatch.stop();
          return false;
        }
      }
      print("[ConvService] Saved conversation data directly for ${conversation.uuid}. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
    } catch (e) {
      print("[ConvService] *** ERROR during prefs.setString: $e. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
      stopwatch.stop();
      return false;
    }

    // 然后更新UUID索引
    print("[ConvService] Loading UUID index. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
    List<String> uuids = [];
    try {
      uuids = await _loadConversationUuids();
      print("[ConvService] UUID index loaded (${uuids.length} items). Elapsed: ${stopwatch.elapsedMilliseconds}ms");
    } catch (e) {
      print("[ConvService] *** ERROR loading UUID index: $e. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
      uuids = [];
    }

    // 检查并更新索引
    if (!uuids.contains(conversation.uuid)) {
      uuids.add(conversation.uuid);
      print("[ConvService] Preparing to save UUID index directly with new UUID ${conversation.uuid}. Elapsed: ${stopwatch.elapsedMilliseconds}ms");

      // 尝试保存索引
      try {
        indexSaved = await prefs.setStringList(_conversationIndexKey, uuids);
        if (!indexSaved) {
          print("[ConvService] *** WARNING: prefs.setStringList failed for index. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
          // 尝试再次保存索引
          await Future.delayed(Duration(milliseconds: 500));
          indexSaved = await prefs.setStringList(_conversationIndexKey, uuids);
          if (!indexSaved) {
            print("[ConvService] *** ERROR: Second attempt to save index failed. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
          }
        }
        if (indexSaved) {
          print("[ConvService] Added ${conversation.uuid} to index and saved index directly. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
        }
      } catch (e) {
        print("[ConvService] *** ERROR saving UUID index directly: $e. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
        indexSaved = false;

        // 即使索引保存失败，也返回成功，因为对话数据已经保存成功
        indexSaved = true;
      }
    } else {
      print("[ConvService] UUID ${conversation.uuid} already in index. Elapsed: ${stopwatch.elapsedMilliseconds}ms");
      indexSaved = true;
    }

    stopwatch.stop();
    print("[ConvService] Finished saveConversation for ${conversation.uuid}. Total time: ${stopwatch.elapsedMilliseconds}ms");

    // 即使索引保存失败，也返回成功，因为对话数据已经保存成功
    return conversationDataSaved;
  }

  // --- Delete Method ---
  Future<void> deleteConversation(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final String conversationKey = _getConversationKey(uuid);

    print("[ConvService] Removing conversation data directly for $uuid.");
    await prefs.remove(conversationKey);

    final List<String> uuids = await _loadConversationUuids();
    if (uuids.remove(uuid)) {
      print("[ConvService] Removing $uuid from index directly.");
      await prefs.setStringList(_conversationIndexKey, uuids);
    } else {
       print("[ConvService] Warning: UUID $uuid not found in index during delete.");
    }
  }

  // --- Last Opened Methods ---
  Future<void> saveLastOpenedConversationUuid(String? uuid) async {
     final prefs = await SharedPreferences.getInstance(); // Keep direct write for this small data
     if (uuid == null) {
       await prefs.remove(_lastOpenedConversationUuidKey);
     } else {
       await prefs.setString(_lastOpenedConversationUuidKey, uuid);
     }
     print("[ConvService] Updated last opened UUID: $uuid");
   }

  Future<String?> loadLastOpenedConversationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString(_lastOpenedConversationUuidKey);
    print("[ConvService] Loaded last opened conversation UUID: $uuid");
    return uuid;
  }

  // --- Clear All Method ---
   Future<void> clearAllConversations() async {
      final prefs = await SharedPreferences.getInstance();
      final List<String> uuids = await _loadConversationUuids();
      List<Future<bool>> removalFutures = []; // Still collect futures for potential parallel removal
      for (final uuid in uuids) {
          removalFutures.add(prefs.remove(_getConversationKey(uuid)));
      }
      removalFutures.add(prefs.remove(_conversationIndexKey));
      removalFutures.add(prefs.remove(_lastOpenedConversationUuidKey));
      await Future.wait(removalFutures); // Wait for removals
      print("[ConvService] Cleared all conversations and index directly.");
   }
}