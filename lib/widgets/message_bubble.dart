import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../models/chat_message.dart';

// Define callback types
typedef OnMessageActionCallback = void Function(String messageUuid, String messageText);
typedef OnMessageRegenerateCallback = void Function(String messageUuid);
typedef OnMessageArchiveCallback = void Function(String messageUuid, int messageIndex);

// Change to ConsumerStatefulWidget
class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final OnMessageActionCallback onEdit;
  final OnMessageActionCallback onDelete;
  final OnMessageActionCallback onCopy;
  final OnMessageRegenerateCallback onRegenerate; // Callback for AI regenerate
  final OnMessageArchiveCallback? onArchive; // Callback for creating archive
  final bool isSelected; // To know if this bubble is selected
  final VoidCallback onTap; // Callback to manage selection state in parent
  final int messageIndex; // Index of the message in the conversation

  const MessageBubble({
    Key? key,
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onRegenerate,
    this.onArchive,
    required this.isSelected,
    required this.onTap,
    required this.messageIndex,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
 // bool _showActions = false; // State moved to parent (ChatScreen)

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.sender == MessageSender.user;
    final isSystem = message.sender == MessageSender.system;
    final isAi = message.sender == MessageSender.ai;

    // System messages are not interactive for now
    if (isSystem) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200, // 系统消息背景色
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      );
    }

    // User and AI messages
    return Stack(
      children: [
        Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 包裹整个气泡的 GestureDetector
            GestureDetector(
              onTap: widget.onTap, // 使用父组件的点击处理器
              behavior: HitTestBehavior.opaque, // 确保捕获所有点击事件，即使子组件也是可点击的
              child: Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Stack(
                  children: [
                    // 气泡容器
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: isUser
                            ? MediaQuery.of(context).size.width * 0.75 // 用户消息宽度保持不变
                            : MediaQuery.of(context).size.width * 0.9, // AI消息宽度进一步增加
                      ),
                      margin: EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: isUser ? 8.0 : 8.0, // 增加AI消息的左侧边距
                      ),
                      padding: EdgeInsets.only(top: 10.0, bottom: 10.0, left: 14.0, right: 8.0),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.deepPurple.shade400 : Colors.grey.shade300,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                          bottomLeft: isUser ? Radius.circular(16.0) : Radius.circular(0),
                          bottomRight: isUser ? Radius.circular(0) : Radius.circular(16.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26), // 相当于 0.1 的不透明度
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: isAi
                            ? MarkdownBody(
                                data: message.text,
                                selectable: true, // 保留可选择性，但点击事件将被上层 GestureDetector 捕获
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                   p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                      fontSize: 16.0,
                                      height: 1.3, // 减少行高
                                   ),
                                   blockSpacing: 8.0, // 减少块之间的间距
                                   listIndent: 16.0, // 减少列表缩进
                                    code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      backgroundColor: Colors.grey.shade200,
                                      fontFamily: 'monospace',
                                      color: Colors.black87,
                                      fontSize: 14.0,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                       color: Colors.grey.shade200,
                                       borderRadius: BorderRadius.circular(4.0),
                                       border: Border.all(color: Colors.grey.shade300)
                                    )
                                ),
                               )
                            : Text(
                                message.text,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 16.0,
                                ),
                              ),
                    ),
                    // 添加一个透明层来确保整个区域都可点击
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 不再添加空白区域，避免导致对话框跳动
          ],
        ),
        // 浮动操作菜单
        if (widget.isSelected)
          Positioned(
            // 将菜单定位在气泡底部，但不会影响气泡布局
            bottom: 0,
            left: isUser ? null : 20.0,
            right: isUser ? 16.0 : null,
            child: Transform.translate(
              // 使用 Transform 向上偏移，让菜单与气泡重叠
              offset: Offset(0, -10),
              child: _buildActionButtons(context, message),
            ),
          ),
      ],
    );
  }

  // Helper to build action buttons based on sender
  Widget _buildActionButtons(BuildContext context, ChatMessage message) {
    final bool isUser = message.sender == MessageSender.user;
    List<Widget> buttons = [];

    // 创建存档按钮（如果提供了回调）
    Widget? archiveButton = widget.onArchive != null
        ? _actionButton(Icons.archive_outlined, '存档',
            () => widget.onArchive!(message.uuid, widget.messageIndex))
        : null;

    if (isUser) {
      buttons = [
        _actionButton(Icons.edit, 'Edit', () => widget.onEdit(message.uuid, message.text)),
        _actionButton(Icons.copy, 'Copy', () => widget.onCopy(message.uuid, message.text)),
        if (archiveButton != null) archiveButton,
        _actionButton(Icons.delete_outline, 'Delete', () => widget.onDelete(message.uuid, message.text), color: Colors.red),
      ];
    } else { // AI
      buttons = [
         _actionButton(Icons.edit, 'Edit', () => widget.onEdit(message.uuid, message.text)),
         _actionButton(Icons.refresh, 'Regenerate', () => widget.onRegenerate(message.uuid)),
         _actionButton(Icons.copy, 'Copy', () => widget.onCopy(message.uuid, message.text)),
         if (archiveButton != null) archiveButton,
         _actionButton(Icons.delete_outline, 'Delete', () => widget.onDelete(message.uuid, message.text), color: Colors.red),
      ];
    }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // 或者稍微不同的颜色
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: buttons,
        ),
    );

  }

   // Helper for creating icon buttons
   Widget _actionButton(IconData icon, String tooltip, VoidCallback onPressed, {Color? color}) {
     return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: IconButton(
          icon: Icon(icon, size: 18, color: color ?? Theme.of(context).iconTheme.color?.withAlpha(179)), // 相当于 0.7 的不透明度
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: BoxConstraints(), // 移除默认填充
          padding: EdgeInsets.all(4),
          iconSize: 18, // 设置图标大小更小
          visualDensity: VisualDensity.compact, // 使用紧凑的视觉密度
        ),
     );
   }
}