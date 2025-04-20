import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/conversation_providers.dart';
import '../models/conversation.dart'; // Import Conversation model
import '../screens/chat_screen.dart'; // Import ChatScreen for navigation

// Change to ConsumerStatefulWidget if you need local state AND Riverpod access
// For now, ConsumerWidget is sufficient as TabController is handled by the framework
class HistoryScreen extends ConsumerStatefulWidget { // 改为 ConsumerStatefulWidget
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // 在 initState 中延迟执行一次刷新，避免无限循环
    Future.microtask(() => ref.invalidate(conversationListProvider));
  }

  @override
  Widget build(BuildContext context) {
    // Use the same theme logic for AppBar colors as SettingsScreen for consistency
    final appBarBackgroundColor = Colors.white;
    final appBarForegroundColor = Colors.black87;

    // 监听对话列表提供者，但不在 build 中刷新
    final conversationListAsync = ref.watch(conversationListProvider);

    // Use DefaultTabController for simplicity unless complex controller logic is needed
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('对话'),
          elevation: 1.0,
          backgroundColor: appBarBackgroundColor,
          foregroundColor: appBarForegroundColor,
          iconTheme: IconThemeData(color: appBarForegroundColor), // Back button color
          bottom: TabBar(
            // controller: _tabController, // Managed by DefaultTabController
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: [
              Tab(text: '对话记录'),
              Tab(text: '知识库'),
            ],
          ),
          actions: [
            // 添加刷新按钮
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: '刷新列表',
              onPressed: () {
                // 显示刷新提示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在刷新列表...'), duration: Duration(seconds: 1))
                );

                // 强制刷新列表
                ref.invalidate(conversationListProvider);
              },
            ),
            // 添加新建对话按钮
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              tooltip: 'New Chat',
              onPressed: () async {
                // 显示加载指示器
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在创建新对话...'), duration: Duration(seconds: 1))
                );

                // 创建新对话
                await ref.read(currentConversationProvider.notifier).createNewConversation('New Chat');

                // 导航回聊天屏幕
                if (context.mounted) Navigator.pop(context);
              },
            )
          ],
        ),
        body: TabBarView(
          // controller: _tabController, // Managed by DefaultTabController
          children: [
            // --- Content for "对话记录" ---
            conversationListAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return Center(child: Text('还没有对话记录。'));
                }
                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      leading: _buildConversationIcon(conversation.iconIdentifier), // Helper for icon
                      title: Text(conversation.title),
                      subtitle: Text(
                          conversation.previewText, // Use preview text
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                       ),
                      trailing: Icon(Icons.more_horiz), // Placeholder for options
                      onTap: () async {
                        // Select the conversation and navigate back
                        await ref.read(currentConversationProvider.notifier).selectConversation(conversation.uuid);
                        if (context.mounted) Navigator.pop(context); // Go back to ChatScreen
                      },
                       onLongPress: () {
                         // TODO: Implement long press for delete/rename options
                         // 将来实现长按删除/重命名功能
                       },
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
            ),
            // --- Content for "知识库" ---
            Center(
              child: Text('知识库内容区域 (待实现)'),
            ),
          ],
        ),
        /* // FAB might be better placed inside specific tabs if needed
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
             // Create a new conversation and navigate
             await ref.read(currentConversationProvider.notifier).createNewConversation('New Chat');
             // Navigate back to ChatScreen (assuming it listens to currentConversationProvider)
             if (context.mounted) Navigator.pop(context);
          },
          child: Icon(Icons.add),
          tooltip: 'New Chat',
        ), */
      ),
    );
  }

  // Helper function to build icon (replace with actual logic)
  Widget _buildConversationIcon(String? iconIdentifier) {
      IconData iconData = Icons.chat_bubble_outline; // Default
      Color iconColor = Colors.grey;
      // Add logic to map iconIdentifier to actual Icons/Images
      if (iconIdentifier == 'twitter') {
        iconData = Icons.flutter_dash; // Placeholder
        iconColor = Colors.blue;
      } else if (iconIdentifier == 'example_code') {
          iconData = Icons.code;
          iconColor = Colors.orange;
      }
      // Add more mappings based on your image example
      return Icon(iconData, color: iconColor);
  }

}