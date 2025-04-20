import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';
import '../models/chat_message.dart';
import '../providers/api_providers.dart'; // Import API Provider
import '../services/api_service.dart'; // Import API Service
import 'package:uuid/uuid.dart';

// Provider for the ConversationService instance
final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService();
});

// Provider to load the list of all conversations (asynchronously)
final conversationListProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.watch(conversationServiceProvider);
  return service.loadConversations();
});

// Provider for the currently active conversation state
final currentConversationProvider = StateNotifierProvider<CurrentConversationNotifier, Conversation?>((ref) {
   final service = ref.watch(conversationServiceProvider);
   // Pass service and ref to the notifier constructor
   final notifier = CurrentConversationNotifier(service, ref);
   // Asynchronously load the initial state
   notifier._loadInitialConversation();
   return notifier;
});

class CurrentConversationNotifier extends StateNotifier<Conversation?> {
  final ConversationService _conversationService;
  final Ref _ref; // To read other providers or invalidate

  CurrentConversationNotifier(this._conversationService, this._ref) : super(null); // Start with null, load async

  // --- New method to load initial state ---
  Future<void> _loadInitialConversation() async {
     print("[Notifier] Attempting to load initial conversation...");
     final lastUuid = await _conversationService.loadLastOpenedConversationUuid();
     if (lastUuid != null) {
       final conversation = await _conversationService.loadConversation(lastUuid);
       if (conversation != null) {
          print("[Notifier] Loaded last opened conversation: $lastUuid");
         state = conversation;
         return; // Successfully loaded
       } else {
         print("[Notifier] Last opened conversation ($lastUuid) not found in storage, clearing UUID.");
         // If conversation data is missing for the saved UUID, clear it
         await _conversationService.saveLastOpenedConversationUuid(null);
       }
     }

     // If no last UUID or loading failed, check if any conversation exists
     print("[Notifier] No valid last conversation found. Checking if any conversations exist...");
     final allConversations = await _conversationService.loadConversations();
     if (allConversations.isNotEmpty) {
        // Load the most recent one if available
        print("[Notifier] Found existing conversations, loading the most recent one: ${allConversations.first.uuid}");
        state = allConversations.first; // Already sorted by date in service
        await _conversationService.saveLastOpenedConversationUuid(state!.uuid);
     } else {
        // If absolutely no conversations exist, create a default one
        print("[Notifier] No conversations exist. Creating default 'Just Chat'.");
        await createNewConversation('Just Chat'); // This will set state and save UUID
     }
  }

  // Select an existing conversation to be the active one
  Future<void> selectConversation(String uuid) async {
    print("[Notifier] Selecting conversation: $uuid"); // Debug
    final conversation = await _conversationService.loadConversation(uuid);
    state = conversation;
    await _conversationService.saveLastOpenedConversationUuid(uuid); // Save selected UUID
  }

  // Create and select a new conversation
  Future<void> createNewConversation(String title, {String? iconIdentifier, String? systemPrompt, List<ChatMessage>? initialMessages}) async {
    final newConversation = Conversation.create(title, iconIdentifier: iconIdentifier, systemPrompt: systemPrompt, initialMessages: initialMessages);
    print("[Notifier] Creating new conversation: ${newConversation.uuid}");

    // 先设置状态，使UI立即响应
    state = newConversation;

    // 保存最后打开的会话UUID
    await _conversationService.saveLastOpenedConversationUuid(newConversation.uuid);

    // 保存会话数据
    final bool saveSuccess = await _conversationService.saveConversation(newConversation);

    // 无论保存是否成功，都刷新列表
    print("[Notifier] Save result: $saveSuccess, invalidating list provider.");
    _ref.invalidate(conversationListProvider); // 强制刷新列表

    // 如果保存失败，再尝试一次
    if (!saveSuccess) {
      print("[Notifier] First save attempt failed, trying again...");
      // 延迟一秒后再次尝试保存
      await Future.delayed(Duration(seconds: 1));
      final bool retrySuccess = await _conversationService.saveConversation(newConversation);
      print("[Notifier] Retry save result: $retrySuccess");

      // 再次刷新列表
      _ref.invalidate(conversationListProvider);
    }
  }

  // Add a message to the current conversation
  Future<void> addMessage(ChatMessage message) async {
    if (state == null) return;
    final updatedConversation = state!.copyWith(
      messages: [...state!.messages, message],
      updatedAt: DateTime.now(),
    );
    state = updatedConversation; // Update state immediately for UI reactivity
    // Save happens after AI response or stream completion in requestAiResponse/finalize
     print("[Notifier] Added message (will save later): ${message.uuid} to ${state!.uuid}");
  }

   // Helper to update the conversation (e.g., title change)
  Future<void> updateCurrentConversation(Conversation updatedConversation) async {
     if (state == null || state!.uuid != updatedConversation.uuid) return;
     state = updatedConversation.copyWith(updatedAt: DateTime.now());
     await _conversationService.saveConversation(state!);
     await _conversationService.saveLastOpenedConversationUuid(state!.uuid); // Ensure last opened is updated
      _ref.invalidate(conversationListProvider);
      print("[Notifier] Updated conversation: ${state!.uuid}"); // Debug
  }

    // Delete the current conversation
  Future<void> deleteCurrentConversation() async {
    if (state == null) return;
    final uuidToDelete = state!.uuid;
    print("[Notifier] Deleting conversation: $uuidToDelete"); // Debug
    state = null; // Clear the current state first
    await _conversationService.deleteConversation(uuidToDelete);
    await _conversationService.saveLastOpenedConversationUuid(null); // Clear last opened if it was deleted
    _ref.invalidate(conversationListProvider); // Refresh the list
  }

   // Clear the currently selected conversation state
  void clearCurrentConversation() {
    state = null;
  }

  // --- New method for streaming updates ---
  Future<void> appendContentToLastMessage(String delta) async {
    if (state == null || state!.messages.isEmpty) return;
    final lastMessage = state!.messages.last;
    if (lastMessage.sender == MessageSender.ai) {
      final updatedMessage = ChatMessage(
          uuid: lastMessage.uuid, // Keep the same UUID
          text: lastMessage.text + delta,
          sender: lastMessage.sender,
          timestamp: lastMessage.timestamp,
      );
      final updatedMessages = List<ChatMessage>.from(state!.messages);
      updatedMessages[updatedMessages.length - 1] = updatedMessage;
      state = state!.copyWith(messages: updatedMessages);
      // Don't save here, save in finalize
    } else {
       print("[Notifier] Warning: Tried to append delta to a non-AI message.");
    }
  }

    // Add a method to finalize the conversation state after streaming
    Future<void> finalizeConversationUpdate() async {
       if (state == null) return;
        print("[Notifier] Finalizing conversation update: ${state!.uuid}");
        await _conversationService.saveConversation(state!.copyWith(updatedAt: DateTime.now()));
        _ref.invalidate(conversationListProvider);
    }

  // --- NEW: API Request Logic moved here ---
   Future<void> requestAiResponse({List<ChatMessage>? contextOverride}) async {
    if (state == null) return;
    // Use provided context or default to current state messages
    final messagesForContext = contextOverride ?? state!.messages;
    if (messagesForContext.isEmpty) return;

    final apiService = _ref.read(apiServiceProvider);
    final currentSystemPrompt = state!.systemPrompt;

    // Add an empty AI message placeholder
    final placeholderAiMessage = ChatMessage(sender: MessageSender.ai, text: '', timestamp: DateTime.now());
    await addMessage(placeholderAiMessage);

    try {
      final stream = apiService.streamChatCompletion(
          messagesForContext,
          systemPromptOverride: currentSystemPrompt,
      );

       StreamSubscription? subscription;
       subscription = stream.listen(
         (delta) {
            appendContentToLastMessage(delta);
         },
         onError: (error) {
            print("[Notifier] Error processing stream: $error");
            final errorMessage = ChatMessage(
              text: "Error during stream: $error",
              sender: MessageSender.system,
              timestamp: DateTime.now(),
            );
            addMessage(errorMessage);
            finalizeConversationUpdate();
         },
         onDone: () {
            print("[Notifier] Stream finished.");
            finalizeConversationUpdate();
         },
         cancelOnError: true,
       );

    } catch (e) {
       print("[Notifier] Error initiating API stream: $e");
       final errorMessage = ChatMessage(
         text: "Error initiating stream: $e",
         sender: MessageSender.system,
         timestamp: DateTime.now(),
       );
        addMessage(errorMessage);
        finalizeConversationUpdate();
    }
  }

  // 使用临时系统提示词发送消息并请求AI响应
  Future<void> requestAiResponseWithSystemPrompt(String userMessage, String systemPromptOverride) async {
    if (state == null) return;

    // 添加用户消息
    final userChatMessage = ChatMessage(
      text: userMessage,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    await addMessage(userChatMessage);

    // 添加空的AI消息占位符
    final placeholderAiMessage = ChatMessage(sender: MessageSender.ai, text: '', timestamp: DateTime.now());
    await addMessage(placeholderAiMessage);

    final apiService = _ref.read(apiServiceProvider);

    try {
      // 使用临时系统提示词
      final stream = apiService.streamChatCompletion(
        state!.messages.sublist(0, state!.messages.length - 1), // 不包括占位符消息
        systemPromptOverride: systemPromptOverride,
      );

      stream.listen(
        (delta) {
          appendContentToLastMessage(delta);
        },
        onError: (error) {
          print("[Notifier] Error processing stream with custom system prompt: $error");
          final errorMessage = ChatMessage(
            text: "Error during stream: $error",
            sender: MessageSender.system,
            timestamp: DateTime.now(),
          );
          addMessage(errorMessage);
          finalizeConversationUpdate();
        },
        onDone: () {
          print("[Notifier] Stream with custom system prompt finished.");
          finalizeConversationUpdate();
        },
        cancelOnError: true,
      );

    } catch (e) {
      print("[Notifier] Error initiating API stream with custom system prompt: $e");
      final errorMessage = ChatMessage(
        text: "Error initiating stream: $e",
        sender: MessageSender.system,
        timestamp: DateTime.now(),
      );
      addMessage(errorMessage);
      finalizeConversationUpdate();
    }
  }

 // --- NEW: Message Manipulation Methods ---

  Future<void> updateMessageContent(String messageUuid, String newContent) async {
    try {
      if (state == null) return;

      // 创建消息列表的副本
      final messages = List<ChatMessage>.from(state!.messages);
      final index = messages.indexWhere((m) => m.uuid == messageUuid);

      if (index != -1) {
        final originalMessage = messages[index];
        // 创建更新后的消息
        messages[index] = ChatMessage(
          uuid: originalMessage.uuid,
          text: newContent,
          sender: originalMessage.sender,
          timestamp: originalMessage.timestamp
        );

        // 先更新状态，使UI立即响应
        state = state!.copyWith(messages: messages, updatedAt: DateTime.now());

        // 然后异步保存到存储
        print("[Notifier] Saving updated message: $messageUuid");
        await _conversationService.saveConversation(state!);
        print("[Notifier] Successfully updated message: $messageUuid");
      } else {
        print("[Notifier] Error: Could not find message $messageUuid to update.");
      }
    } catch (e) {
      print("[Notifier] Error updating message content: $e");
      // 出错时不要抛出异常，而是记录错误并继续
    }
  }

  Future<void> deleteMessage(String messageUuid) async {
      if (state == null) return;
      final messages = List<ChatMessage>.from(state!.messages);
      final initialLength = messages.length;
      messages.removeWhere((m) => m.uuid == messageUuid);
      if (messages.length < initialLength) {
          state = state!.copyWith(messages: messages, updatedAt: DateTime.now());
          await _conversationService.saveConversation(state!);
           _ref.invalidate(conversationListProvider);
           print("[Notifier] Deleted message: $messageUuid");
      } else {
           print("[Notifier] Error: Could not find message $messageUuid to delete.");
      }
  }

  Future<void> regenerateResponse(String aiMessageUuid) async {
     if (state == null) return;
      final messages = List<ChatMessage>.from(state!.messages);
      final index = messages.indexWhere((m) => m.uuid == aiMessageUuid);

      if (index != -1 && messages[index].sender == MessageSender.ai) {
          // Get context *before* the message to regenerate
         final context = messages.sublist(0, index);
         // Remove the AI message we are regenerating
         messages.removeAt(index);
         // Update state immediately to remove the old message from UI
         state = state!.copyWith(messages: messages);
         // (Don't save intermediate state here)

         print("[Notifier] Regenerating response for message $aiMessageUuid using ${context.length} context messages.");
         // Request a new response using the context before the removed message
         await requestAiResponse(contextOverride: context);

      } else {
          print("[Notifier] Error: Could not find AI message $aiMessageUuid to regenerate or it wasn't an AI message.");
      }

  }
}