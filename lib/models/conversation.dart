import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'chat_message.dart';

part 'conversation.g.dart'; // Will be generated

@JsonSerializable(explicitToJson: true) // Important for nested lists/objects
class Conversation {
  final String uuid;
  String title;
  String? iconIdentifier; // Optional icon identifier (e.g., 'twitter', 'default_chat')
  String? systemPrompt; // Add system prompt field
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    required this.uuid,
    required this.title,
    this.iconIdentifier,
    this.systemPrompt, // Add to constructor
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory for creating a new conversation
  factory Conversation.create(String title, {String? iconIdentifier, String? systemPrompt, List<ChatMessage>? initialMessages}) {
    final now = DateTime.now();
    return Conversation(
      uuid: Uuid().v4(),
      title: title,
      iconIdentifier: iconIdentifier,
      systemPrompt: systemPrompt, // Add to factory
      messages: initialMessages ?? [],
      createdAt: now,
      updatedAt: now,
    );
  }


  // Factory constructor for JSON deserialization
  factory Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

  // Method for JSON serialization
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

   // Helper to get a preview text (e.g., last message)
   String get previewText {
     if (messages.isEmpty) return "No messages yet";
     final lastMessage = messages.last;
     // Consider adding sender prefix for clarity in preview
     String prefix = "";
     switch(lastMessage.sender) {
        case MessageSender.user: prefix = "You: "; break;
        case MessageSender.ai: prefix = "AI: "; break;
        case MessageSender.system: prefix = "System: "; break;
     }
     // Limit preview length
     const maxLength = 50;
     String text = lastMessage.text.replaceAll('\n', ' '); // Replace newlines
     if (text.length > maxLength) {
       text = text.substring(0, maxLength) + "...";
     }
     return "$prefix$text";
   }
}

extension ConversationCopyWith on Conversation {
  Conversation copyWith({
    String? uuid,
    String? title,
    String? iconIdentifier,
    String? systemPrompt, // Add here
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      iconIdentifier: iconIdentifier ?? this.iconIdentifier,
      systemPrompt: systemPrompt ?? this.systemPrompt, // Add here
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}