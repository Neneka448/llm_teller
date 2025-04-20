import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart'; // Import Uuid

part 'chat_message.g.dart'; // Will be generated

enum MessageSender { user, ai, system }

@JsonSerializable()
class ChatMessage {
  final String uuid; // Add UUID field
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    String? uuid, // Make UUID optional in constructor, generate if null
    required this.text,
    required this.sender,
    required this.timestamp,
  }) : uuid = uuid ?? Uuid().v4(); // Generate UUID if not provided

  // Factory constructor for JSON deserialization
  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

  // Method for JSON serialization
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  // Helper to convert sender enum to OpenAI role string
  String get _openAiRole {
    switch (sender) {
      case MessageSender.user:
        return 'user';
      case MessageSender.ai:
        return 'assistant';
      case MessageSender.system:
        return 'system';
    }
  }

  // Static method to convert a list of messages to OpenAI format
  static List<Map<String, String>> toOpenAiMessages(List<ChatMessage> messages, {String? systemPrompt}) {
    final List<Map<String, String>> formatted = [];

    // Add system prompt first if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      // Wrap the prompt in the requested tags
      final taggedPrompt = "<system_prompt>$systemPrompt</system_prompt>";
      formatted.add({'role': 'system', 'content': taggedPrompt});
      print("[ChatMessage] Added tagged system prompt: $taggedPrompt"); // Debug
    }

    // Filter out system messages if they are not the very first message (common practice)
    bool systemMessageFound = formatted.isNotEmpty; // Consider injected prompt as found
    for (var msg in messages) {
      if (msg.sender == MessageSender.system) {
        // Allow system message only if it's the *very first* and none was injected
        if (!systemMessageFound && formatted.isEmpty) {
           formatted.add({'role': msg._openAiRole, 'content': msg.text});
           systemMessageFound = true;
        }
         // else: Skip subsequent system messages
      } else {
         // Add user/assistant messages
         formatted.add({'role': msg._openAiRole, 'content': msg.text});
      }
    }

    return formatted;

    /* // Old filtering logic, replaced by above
    return filteredMessages
        .map((msg) => {'role': msg._openAiRole, 'content': msg.text})
        .toList();
    */
  }
} 