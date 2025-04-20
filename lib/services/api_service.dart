import 'dart:async'; // Import async
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart'; // To use the formatter

class ApiService {
  // Method to get chat completion from OpenAI compatible API (like OpenRouter)
  Future<String?> getChatCompletion(List<ChatMessage> messages, {String? systemPromptOverride}) async {
    print("[ApiService] getChatCompletion called (non-streaming). Received systemPromptOverride: ${systemPromptOverride ?? 'None'}"); // DEBUG
    final prefs = await SharedPreferences.getInstance();

    // Load settings (with defaults similar to SettingsScreen)
    final host = prefs.getString('apiHost') ?? 'https://openrouter.ai/api/v1';
    final path = prefs.getString('apiPath') ?? '/chat/completions';
    final apiKey = prefs.getString('apiKey') ?? '';
    final model = prefs.getString('model') ?? 'gpt-4o';
    final temperature = prefs.getDouble('temperature') ?? 0.7;
    final topP = prefs.getDouble('topP') ?? 1.0;
    // Load maxMessages setting
    final maxMessages = prefs.getInt('maxMessages'); // Returns null if unlimited or not set
    print("[ApiService] Max messages context limit from settings: $maxMessages"); // Debug

    if (apiKey.isEmpty) {
      print("[ApiService] Error: API Key is missing in settings.");
      return "Error: API Key is missing. Please configure it in Settings.";
    }

    final url = Uri.parse('$host$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
       // OpenRouter specific headers (Optional but recommended)
       'HTTP-Referer': 'YOUR_APP_URL', // Replace with your app URL or name
       'X-Title': 'YOUR_APP_NAME', // Replace with your app name
    };

    // --- Apply context limit --- 
    List<ChatMessage> messagesToSend = List.from(messages); // Create a mutable copy
     // Pass the system prompt from the conversation (if available) to the formatter
     String? systemPromptForApi = systemPromptOverride; // Allow override if needed

    // Find system prompt in messages list itself (legacy way?)
    // Let's prioritize the dedicated field if override isn't present
    // final systemPromptInMessages = messages.firstWhereOrNull((m) => m.sender == MessageSender.system)?.text;
    // if (systemPromptForApi == null && systemPromptInMessages != null) {
    //    systemPromptForApi = systemPromptInMessages;
    // }
    print("[ApiService] Using system prompt for API call: ${systemPromptForApi ?? 'None'}");

    if (maxMessages != null && maxMessages > 0 && messages.length > maxMessages) {
        print("[ApiService] Truncating message history from ${messages.length} to $maxMessages messages."); // Debug
        int startIndex = messages.length - maxMessages;

        // Ensure the first message is kept if it's a system message, even if truncation would remove it
        bool firstIsSystem = messages.isNotEmpty && messages.first.sender == MessageSender.system;
        
        // Always keep system message if present and truncation is happening
        if (firstIsSystem && startIndex > 0) { 
             print("[ApiService] Keeping system prompt and last ${maxMessages -1} messages."); // Debug
             // Keep system message + last (maxMessages - 1) user/assistant messages
             messagesToSend = [messages.first, ...messages.sublist(messages.length - (maxMessages - 1))];
        } else {
             // No system message, or system message is already included in the last maxMessages count
             messagesToSend = messages.sublist(startIndex);
        }

        print("[ApiService] Actual messages being sent: ${messagesToSend.length}"); // Debug
    } else {
         print("[ApiService] Sending full message history (${messages.length} messages)."); // Debug
    }
    // --- End context limit ---

    // Convert messages to the required format (use the potentially truncated list)
    // Pass the determined system prompt to the formatter
    final formattedMessages = ChatMessage.toOpenAiMessages(messagesToSend, systemPrompt: systemPromptForApi);

    print("[ApiService] Final formatted messages being sent to API: $formattedMessages"); // DEBUG

    // Construct the request body
    final body = jsonEncode({
      'model': model,
      'messages': formattedMessages,
      'temperature': temperature,
      'top_p': topP,
      // 'max_tokens': maxTokens, // Add if needed
    });

     print("[ApiService] Sending request to $url with model $model");
     // print("[ApiService] Request body: $body"); // Uncomment carefully for debugging (contains messages)

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

       print("[ApiService] Response status code: ${response.statusCode}");
       // print("[ApiService] Response body: ${response.body}"); // Uncomment carefully for debugging

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes)); // Use utf8 decoding
        if (responseBody['choices'] != null && responseBody['choices'].isNotEmpty) {
          final message = responseBody['choices'][0]['message'];
          if (message != null && message['content'] != null) {
             print("[ApiService] Received response successfully.");
            return message['content'] as String?;
          }
        }
        print("[ApiService] Error: Invalid response format - 'choices' or 'content' missing.");
        return "Error: Received invalid response format from API.";
      } else {
         print("[ApiService] Error: API request failed with status ${response.statusCode}. Body: ${response.body}");
        // Try to parse error message from API response
         String errorMessage = "API Error: ${response.statusCode}";
         try {
           final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
           if (errorBody['error'] != null && errorBody['error']['message'] != null) {
             errorMessage = "API Error: ${errorBody['error']['message']}";
           }
         } catch (_) {
            // Ignore parsing error, use status code
         }
        return errorMessage;
      }
    } catch (e) {
      print("[ApiService] Error making API request: $e");
      return "Error: Failed to connect to the API. $e";
    }
  }

  // --- New Streaming Method ---
  Stream<String> streamChatCompletion(List<ChatMessage> messages, {String? systemPromptOverride}) async* {
    print("[ApiService] streamChatCompletion called. Received systemPromptOverride: ${systemPromptOverride ?? 'None'}");
    final prefs = await SharedPreferences.getInstance();
    final bool streamEnabled = prefs.getBool('streamOutput') ?? true;

    // If streaming is disabled in settings, fallback to non-streaming
    if (!streamEnabled) {
      print("[ApiService] Streaming disabled in settings, falling back to non-streaming.");
      final result = await getChatCompletion(messages, systemPromptOverride: systemPromptOverride);
      if (result != null) {
        yield result;
      }
      return; // End the stream
    }

    // --- Proceed with Streaming --- 
    print("[ApiService] Streaming enabled, proceeding with stream request.");
    final host = prefs.getString('apiHost') ?? 'https://openrouter.ai/api/v1';
    final path = prefs.getString('apiPath') ?? '/chat/completions';
    final apiKey = prefs.getString('apiKey') ?? '';
    final model = prefs.getString('model') ?? 'gpt-4o';
    final temperature = prefs.getDouble('temperature') ?? 0.7;
    final topP = prefs.getDouble('topP') ?? 1.0;
    final maxMessages = prefs.getInt('maxMessages'); 
    print("[ApiService] Max messages context limit from settings: $maxMessages");

    if (apiKey.isEmpty) {
      print("[ApiService] Error: API Key is missing.");
      yield "Error: API Key is missing. Please configure it in Settings.";
      return;
    }

    final url = Uri.parse('$host$path');
     final headers = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream', // Important for SSE
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'YOUR_APP_URL', 
      'X-Title': 'YOUR_APP_NAME', 
    };

    List<ChatMessage> messagesToSend = List.from(messages);
    String? systemPromptForApi = systemPromptOverride;
    print("[ApiService] Using system prompt for API call: ${systemPromptForApi ?? 'None'}");

     // Apply context limit (same logic as before)
     if (maxMessages != null && maxMessages > 0 && messages.length > maxMessages) {
        print("[ApiService] Truncating message history from ${messages.length} to $maxMessages messages.");
        int startIndex = messages.length - maxMessages;
        bool firstIsSystem = messages.isNotEmpty && messages.first.sender == MessageSender.system;
        if (firstIsSystem && startIndex > 0) { 
             print("[ApiService] Keeping system prompt and last ${maxMessages -1} messages.");
             messagesToSend = [messages.first, ...messages.sublist(messages.length - (maxMessages - 1))];
        } else {
             messagesToSend = messages.sublist(startIndex);
        }
        print("[ApiService] Actual messages being sent: ${messagesToSend.length}");
    } else {
         print("[ApiService] Sending full message history (${messages.length} messages).");
    }

    final formattedMessages = ChatMessage.toOpenAiMessages(messagesToSend, systemPrompt: systemPromptForApi);
     print("[ApiService] Final formatted messages being sent to API: $formattedMessages");

    final body = jsonEncode({
      'model': model,
      'messages': formattedMessages,
      'temperature': temperature,
      'top_p': topP,
      'stream': true, // Enable streaming
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', url)..headers.addAll(headers)..body = body;
      final response = await client.send(request);

      print("[ApiService] Stream response status code: ${response.statusCode}");

      if (response.statusCode == 200) {
          final stream = response.stream
              .transform(utf8.decoder)
              .transform(LineSplitter());

          await for (final line in stream) {
            if (line.startsWith('data: ')) {
              final dataString = line.substring(6);
              if (dataString == '[DONE]') {
                print("[ApiService] Received [DONE] signal.");
                break; // Stream finished
              }
              try {
                 final data = jsonDecode(dataString);
                 if (data['choices'] != null && data['choices'].isNotEmpty) {
                   final delta = data['choices'][0]['delta'];
                   if (delta != null && delta['content'] != null) {
                      final contentChunk = delta['content'] as String;
                      // print("[ApiService] Yielding chunk: $contentChunk"); // Very verbose debug
                      yield contentChunk;
                   }
                 }
              } catch (e) {
                 print("[ApiService] Error parsing stream data chunk: $dataString - Error: $e");
                 // Decide if you want to yield an error message or just ignore
              }
            } else if (line.isNotEmpty) {
               print("[ApiService] Received non-data line: $line"); // Log other lines if needed
            }
          }
           print("[ApiService] Stream processing finished.");
      } else {
          // Handle non-200 status code for the stream request itself
          final errorBody = await response.stream.bytesToString();
          print("[ApiService] Error: Stream request failed with status ${response.statusCode}. Body: $errorBody");
          String errorMessage = "API Stream Error: ${response.statusCode}";
           try {
             final errorJson = jsonDecode(errorBody);
             if (errorJson['error'] != null && errorJson['error']['message'] != null) {
               errorMessage = "API Stream Error: ${errorJson['error']['message']}";
             }
           } catch (_) {}
          yield errorMessage;
      }
    } catch (e, stackTrace) {
        print("[ApiService] Error during stream request/processing: $e\n$stackTrace");
        yield "Error: Failed to connect or process stream. $e";
    } finally {
        client.close();
        print("[ApiService] Stream client closed.");
    }
  }
} 