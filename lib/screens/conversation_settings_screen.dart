import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';

class ConversationSettingsScreen extends ConsumerStatefulWidget {
  final String conversationUuid;

  const ConversationSettingsScreen({Key? key, required this.conversationUuid})
      : super(key: key);

  @override
  _ConversationSettingsScreenState createState() =>
      _ConversationSettingsScreenState();
}

class _ConversationSettingsScreenState
    extends ConsumerState<ConversationSettingsScreen> {
  late TextEditingController _systemPromptController;
  late TextEditingController _titleController;
  Conversation? _initialConversationData;

  @override
  void initState() {
    super.initState();
    _systemPromptController = TextEditingController();
    _titleController = TextEditingController();
    _loadInitialData();
  }

  void _loadInitialData() {
    final conversation = ref.read(currentConversationProvider);
     if (conversation != null && conversation.uuid == widget.conversationUuid) {
       setState(() {
          _initialConversationData = conversation;
          _systemPromptController.text = conversation.systemPrompt ?? '';
          _titleController.text = conversation.title;
       });
     } else {
         print("[ConvSettings] Warning: Could not get initial data from current provider for ${widget.conversationUuid}. Fetching manually...");
         _fetchConversationData();
     }
  }

   Future<void> _fetchConversationData() async {
     final conversation = await ref.read(conversationServiceProvider).loadConversation(widget.conversationUuid);
     if (conversation != null && mounted) {
       setState(() {
         _initialConversationData = conversation;
         _systemPromptController.text = conversation.systemPrompt ?? '';
         _titleController.text = conversation.title;
       });
     } else if (mounted) {
       // Handle error: Conversation not found
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error: Could not load conversation data.')),
       );
       Navigator.pop(context); // Go back if data can't be loaded
     }
   }


  @override
  void dispose() {
    _systemPromptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_initialConversationData == null) return;

    final newPrompt = _systemPromptController.text.trim();
    final newTitle = _titleController.text.trim();

    bool titleChanged = newTitle.isNotEmpty && newTitle != _initialConversationData!.title;
    bool promptChanged = newPrompt != (_initialConversationData!.systemPrompt ?? '');

    // Only update if title or prompt changed (and title is not empty)
     if (titleChanged || promptChanged) {
        final updatedConversation =
            _initialConversationData!.copyWith(
                title: titleChanged ? newTitle : _initialConversationData!.title,
                systemPrompt: promptChanged ? (newPrompt.isEmpty ? null : newPrompt) : _initialConversationData!.systemPrompt,
             );

        ref
            .read(currentConversationProvider.notifier)
            .updateCurrentConversation(updatedConversation);

         // Get the messenger state BEFORE popping
         final messenger = ScaffoldMessenger.of(context);
         // Show success banner instead of SnackBar
         _showSuccessBanner(messenger, '设置已保存');

     } else {
         final messenger = ScaffoldMessenger.of(context);
         // Show info banner if nothing changed
         _showSuccessBanner(messenger, '设置未更改');
     }
    // Pop needs to happen after banner dismisses or immediately? Decide based on UX.
    // For now, pop immediately after showing banner.
     Navigator.pop(context); 
  }

  // --- Show Success Banner --- 
  // Modify to accept ScaffoldMessengerState
  void _showSuccessBanner(ScaffoldMessengerState messenger, String message) {
     // Use the passed messenger state
     messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: Colors.green[100], // Light green background
        leading: Icon(Icons.check_circle_outline, color: Colors.green),
        actions: <Widget>[
          TextButton(
            child: const Text('好的'),
            onPressed: () {
              // Use the passed messenger state to hide
              messenger.hideCurrentMaterialBanner();
            },
          ),
        ],
      ),
    );
     // Auto-hide banner after a few seconds
     Future.delayed(Duration(seconds: 3), () {
       // No need to check mounted here, as we are using the messenger state directly
       // However, the messenger itself might have been disposed if the root Scaffold changed dramatically, 
       // though less likely in this pop scenario.
       // It's generally safe to just call hide.
        messenger.hideCurrentMaterialBanner();
     });
  }


  @override
  Widget build(BuildContext context) {
     if (_initialConversationData == null) {
       // Show loading indicator while fetching data if needed
       return Scaffold(
         appBar: AppBar(title: Text('对话设置')),
         body: Center(child: CircularProgressIndicator()),
       );
     }

    return Scaffold(
      appBar: AppBar(
        title: Text('对话设置'),
        elevation: 1.0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
             // --- Title Section ---
             Text(
               '对话标题',
               style: Theme.of(context).textTheme.titleLarge,
             ),
             SizedBox(height: 8.0),
             TextField(
               controller: _titleController,
               decoration: InputDecoration(
                 hintText: '输入对话标题',
                 border: OutlineInputBorder(),
               ),
               textInputAction: TextInputAction.next, // Move to next field on Enter/Done
             ),
             SizedBox(height: 24.0),

            // --- 知识库 Section (Placeholder) ---
            Text(
              '知识库',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8.0),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('(知识库功能暂未实现)'),
              ),
            ),
            SizedBox(height: 24.0),

            // --- 系统提示词 Section ---
            Text(
              '系统提示词 (System Prompt)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8.0),
            TextField(
              controller: _systemPromptController,
              decoration: InputDecoration(
                hintText: '例如：你是一个乐于助人的助手。',
                border: OutlineInputBorder(),
                alignLabelWithHint: true, // Better alignment for multiline
              ),
              maxLines: 10, // Allow multiple lines, adjust as needed
              minLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            SizedBox(height: 32.0),

            // --- Save Button ---
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('SAVE'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 