import 'dart:async'; // Import async for StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/editable_message_bubble.dart'; // 导入新的编辑消息组件
import '../widgets/chat_input_field.dart';
import 'settings_screen.dart'; // 导入设置屏幕
import 'history_screen.dart'; // 导入历史记录屏幕
import 'archive_screen.dart'; // 导入存档屏幕
import '../providers/conversation_providers.dart'; // Import providers
import '../providers/archive_providers.dart'; // 导入存档提供者
import '../models/conversation.dart'; // Import Conversation
import '../services/archive_service.dart'; // 导入存档服务
import 'conversation_settings_screen.dart'; // Import conversation settings screen
import 'package:flutter/services.dart'; // Import clipboard

// Change to ConsumerStatefulWidget if local state like ScrollController is needed
class ChatScreen extends ConsumerStatefulWidget { // Change to ConsumerStatefulWidget
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

// Add ConsumerState
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedMessageUuid; // State to track selected message
  String? _editingMessageUuid; // State to track message being edited

  // 添加一个变量来记录上次滚动位置
  double _lastScrollPosition = 0;
  // 添加一个变量来记录最小滚动距离
  static const double _scrollThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    // Optional: Check if a conversation is active when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // _ensureConversationSelected(); // Removed: Notifier handles initial load
       _scrollToBottom(); // Initial scroll (might need slight delay if list loads async)
    });

    // 修改滚动监听器，只在大幅度滚动时清除选择
    _scrollController.addListener(() {
      // 只有当滚动距离超过阈值时才清除选择
      if (_selectedMessageUuid != null &&
          (_scrollController.position.pixels - _lastScrollPosition).abs() > _scrollThreshold) {
        _clearMessageSelection();
      }
      // 更新上次滚动位置
      _lastScrollPosition = _scrollController.position.pixels;
    });
  }

  // Modify _sendMessage to call the notifier's request method
  void _sendMessage(String text) {
    final userMessage = ChatMessage(
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    // Use the provider to add the user message
    final notifier = ref.read(currentConversationProvider.notifier);
    notifier.addMessage(userMessage);

    // Trigger the AI response request via the notifier
    notifier.requestAiResponse();

    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Remove listener logic from here
    /*
    ref.listen(currentConversationProvider, (previous, next) {
       if (previous?.messages.length != next?.messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
             }
          });
       }
    });
    */
     // Also scroll immediately if needed
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (_scrollController.hasClients) {
           // Check if already at the bottom to prevent unnecessary scrolls
           if (_scrollController.position.pixels != _scrollController.position.maxScrollExtent) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
            }
       }
    });
  }

  // Clear message selection
  void _clearMessageSelection() {
    if (_selectedMessageUuid != null) {
      setState(() {
        // 关闭菜单
        _selectedMessageUuid = null;
        // 重置标记，因为这是点击空白区域关闭的菜单
        _lastTappedMessageUuid = null;
      });
    }
  }

  // 收起输入框的方法
  void _collapseInputField() {
    // 直接使用GlobalKey获取_ChatInputFieldState
    if (_chatInputFieldKey.currentState != null) {
      _chatInputFieldKey.currentState!.collapse();
    }
  }

  // 使用GlobalKey获取ChatInputFieldState
  final GlobalKey<ChatInputFieldState> _chatInputFieldKey = GlobalKey<ChatInputFieldState>();

  // 添加一个变量来记录上次点击时间
  DateTime _lastTapTime = DateTime.now();
  // 添加一个变量来记录点击间隔
  static const int _tapThreshold = 300; // 毫秒

  // 添加一个变量来记录上次点击的消息 UUID
  String? _lastTappedMessageUuid;

  // 添加一个变量来记录上次点击的消息

  void _handleMessageTap(String messageUuid) {
    // 获取当前时间
    final now = DateTime.now();
    // 计算与上次点击的时间间隔
    final timeDiff = now.difference(_lastTapTime).inMilliseconds;

    // 更新上次点击时间
    _lastTapTime = now;

    // 如果点击间隔小于阈值，则忽略这次点击
    // 这可以防止用户意外的多次快速点击
    if (timeDiff < _tapThreshold) {
      return;
    }

    // 收起输入框
    _collapseInputField();

    // 检查当前对话是否存在
    final currentConversation = ref.read(currentConversationProvider);
    if (currentConversation == null) return;

    // 检查消息是否存在
    final messageExists = currentConversation.messages.any((msg) => msg.uuid == messageUuid);
    if (!messageExists) return;

    setState(() {
      // 如果点击的是当前选中的消息，则取消选中
      if (_selectedMessageUuid == messageUuid) {
        _selectedMessageUuid = null;
      }
      // 如果已经有选中的消息，但点击的是其他消息
      else if (_selectedMessageUuid != null) {
        // 先关闭当前菜单
        _selectedMessageUuid = null;
        // 记录这次点击的消息，下次点击时会打开它
        _lastTappedMessageUuid = messageUuid;
      }
      // 如果没有选中的消息，但这个消息是上次点击记录的消息
      else if (messageUuid == _lastTappedMessageUuid) {
        _selectedMessageUuid = messageUuid;
        _lastTappedMessageUuid = null;
      }
      // 其他情况，直接选中这个消息
      else {
        _selectedMessageUuid = messageUuid;
        _lastTappedMessageUuid = null;
      }
    });
  }

  void _handleCopyMessage(String messageUuid, String messageText) {
    Clipboard.setData(ClipboardData(text: messageText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
    _clearMessageSelection(); // Clear selection after action
  }

  void _handleDeleteMessage(String messageUuid, String messageText) {
    _showDeleteConfirmDialog(messageUuid);
    _clearMessageSelection();
  }

  // 新的编辑消息处理方法
  void _handleEditMessage(String messageUuid, String messageText) {
    // 直接更新消息内容
    setState(() {
      _editingMessageUuid = messageUuid; // 设置正在编辑的消息 UUID
      _selectedMessageUuid = null; // 关闭菜单
    });

    // 添加延迟，确保编辑框已经渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 找到正在编辑的消息在列表中的位置
      final currentConversation = ref.read(currentConversationProvider);
      if (currentConversation == null) return;

      final index = currentConversation.messages.indexWhere((msg) => msg.uuid == messageUuid);
      if (index == -1) return;

      // 计算消息在列表中的大致位置，并滚动到该位置
      // 这里使用了一个简单的估算，假设每个消息的高度大约为 100
      final estimatedPosition = index * 100.0;

      // 滚动到编辑框位置，并留出一些空间以显示键盘
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          estimatedPosition - 100, // 向上偏移一些，留出空间给键盘
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleRegenerateResponse(String messageUuid) {
    // 调用重新生成响应的方法
    ref.read(currentConversationProvider.notifier).regenerateResponse(messageUuid);
    _clearMessageSelection();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the current conversation state
    final currentConversation = ref.watch(currentConversationProvider);

    // ---- Setup listener inside build ----
    ref.listen(currentConversationProvider, (previous, next) {
       // Optional: Add more conditions if needed, e.g., only scroll if a new message was added by someone else
       if (previous?.messages.length != next?.messages.length) {
          // Check if the widget is still mounted before scrolling
          if (mounted && _scrollController.hasClients) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 // Scroll after the frame is built
                  _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                  );
              });
          }
       }
    });
    // ---- End listener setup ----

    return Scaffold(
      // AppBar 区域模仿图片样式
      appBar: AppBar(
        backgroundColor: Colors.white, // 直接设为白色
        elevation: 1.0, // 轻微阴影
        title: Row(
            children: [
                // Icon(Icons.chat_bubble_outline, color: Colors.grey.shade600), // Removed
                // SizedBox(width: 8), // Removed
                Expanded( // 将 Text 包裹在 Expanded 中
                  child: Text(
                      currentConversation?.title ?? 'Chat', // Use conversation title
                      style: TextStyle(color: Colors.black87, fontSize: 18),
                      overflow: TextOverflow.ellipsis, // 防止极端情况下的溢出
                   ),
                ),
                // Spacer(), // Removed
                // IconButton for search - Removed
                // IconButton for history - Removed

                // ---- Ensure ONLY the PopupMenuButton remains ----
                /* Commenting out any potential remaining IconButtons before the PopupMenuButton
                 IconButton(
                     icon: Icon(Icons.more_horiz, color: Colors.grey.shade600),
                     onPressed: () { print("Duplicate icon tapped?"); },
                 ),
                */

                PopupMenuButton<String>(
                   icon: Icon(Icons.more_horiz, color: Colors.grey.shade600),
                   offset: Offset(0, 40), // Adjust vertical offset
                   onSelected: (String result) {
                     // Get the current conversation BEFORE potentially navigating
                      final currentConversation = ref.read(currentConversationProvider);

                     switch (result) {
                       case 'history':
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => const HistoryScreen()),
                         );
                         break;
                       case 'archive':
                         if (currentConversation != null) {
                           // 导航到存档列表页面
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (context) => const ArchiveScreen()),
                           );
                         } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('没有活动的对话可存档')),
                           );
                         }
                         break;
                       case 'delete': // Add delete option
                         _confirmDeleteConversation(context, ref);
                         break;
                       case 'rename':
                         _renameConversationDialog(context, ref, currentConversation);
                         break;
                       case 'conv_settings': // New case for conversation settings
                         if (currentConversation != null) {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => ConversationSettingsScreen(
                                 conversationUuid: currentConversation.uuid,
                               ),
                             ),
                           );
                         } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('没有活动的对话可设置')),
                           );
                         }
                         break;
                     }
                   },
                   itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                     const PopupMenuItem<String>(
                       value: 'history',
                       child: Text('历史记录'), // History Option
                     ),
                     const PopupMenuItem<String>(
                       value: 'archive',
                       child: Text('存档'), // Archive Option
                     ),
                     const PopupMenuItem<String>( // Add conversation settings option
                       value: 'conv_settings',
                       child: Text('对话设置'),
                     ),
                     const PopupMenuItem<String>(
                       value: 'rename',
                       child: Text('重命名'),
                     ),
                     const PopupMenuItem<String>(
                       value: 'delete',
                       textStyle: TextStyle(color: Colors.red),
                       child: Text('删除对话'),
                     ),
                   ],
                )
            ]
        ),
        leading: IconButton( // 左侧设置按钮图标
            icon: Icon(Icons.settings_outlined, color: Colors.orange.shade700), // 设置图标
            onPressed: () {
                // 导航到设置页面
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const SettingsScreen()),
               );
            },
        ),
      ),
      body: GestureDetector( // Wrap with GestureDetector to detect taps outside bubbles
        onTap: () {
          // 收起输入框
          _collapseInputField();
          // 清除消息选择
          _clearMessageSelection();
        },
        behavior: HitTestBehavior.translucent, // 确保能捕获所有点击事件
        child: Column(
          children: <Widget>[
            Expanded(
              child: currentConversation == null
                ? Center(child: Text('Select or start a new conversation.')) // Show if no convo active
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: currentConversation.messages.length,
                    itemBuilder: (context, index) {
                      // Use message from provider state
                      final message = currentConversation.messages[index];

                      // 如果消息正在编辑中，显示编辑界面
                      if (message.uuid == _editingMessageUuid) {
                        return EditableMessageBubble(
                          key: ValueKey('editing_${message.uuid}'),
                          messageUuid: message.uuid,
                          initialText: message.text,
                          sender: message.sender,
                          onSave: _handleSaveEdit,
                          onCancel: _handleCancelEdit,
                        );
                      }

                      // 否则显示正常消息气泡
                      return MessageBubble(
                        key: ValueKey(message.uuid),
                        message: message,
                        messageIndex: index,
                        isSelected: message.uuid == _selectedMessageUuid,
                        onTap: () => _handleMessageTap(message.uuid),
                        onCopy: _handleCopyMessage,
                        onDelete: _handleDeleteMessage,
                        onEdit: _handleEditMessage,
                        onRegenerate: _handleRegenerateResponse,
                        onArchive: _handleCreateArchive,
                      );
                    },
                  ),
            ),
            ChatInputField(
              key: _chatInputFieldKey,
              onSendMessage: _sendMessage,
            ),
          ],
        ),
      ),
    );
}

   // --- Dialogs for Rename/Delete ---
   Future<void> _confirmDeleteConversation(BuildContext context, WidgetRef ref) async {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('删除对话?'),
            content: Text('此操作无法撤销。'),
            actions: <Widget>[
              TextButton(
                child: Text('取消'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('删除', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await ref.read(currentConversationProvider.notifier).deleteCurrentConversation();
        // Optionally navigate away or select another conversation
        // After deletion, the notifier should load the next available or create a new one
        // The UI will react automatically via ref.watch(currentConversationProvider)
      }
   }

   Future<void> _renameConversationDialog(BuildContext context, WidgetRef ref, Conversation? conversation) async {
     if (conversation == null) return;
     final TextEditingController renameController = TextEditingController(text: conversation.title);

     final String? newTitle = await showDialog<String>(
       context: context,
       builder: (context) {
         return AlertDialog(
           title: Text('重命名对话'),
           content: TextField(
             controller: renameController,
             autofocus: true,
             decoration: InputDecoration(hintText: '输入新标题'),
           ),
           actions: [
              TextButton(
                child: Text('取消'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: Text('保存'),
                onPressed: () {
                   if (renameController.text.trim().isNotEmpty) {
                     Navigator.of(context).pop(renameController.text.trim());
                   }
                },
              ),
           ],
         );
       },
     );

     if (newTitle != null && newTitle != conversation.title) {
        final updatedConversation = conversation.copyWith(title: newTitle);
        await ref.read(currentConversationProvider.notifier).updateCurrentConversation(updatedConversation);
     }
      renameController.dispose();
   }

   // 处理保存编辑的方法，确保持久化
   Future<void> _handleSaveEdit(String messageUuid, String newText) async {
     try {
       // 显示保存中提示
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('正在保image.png存编辑...'), duration: Duration(seconds: 1))
       );

       final currentConversation = ref.read(currentConversationProvider);
       if (currentConversation == null) return;

       // 检查消息是否存在
       final messageExists = currentConversation.messages.any((msg) => msg.uuid == messageUuid);
       if (!messageExists) {
         throw Exception('找不到要编辑的消息');
       }

       // 直接使用 updateMessageContent 方法更新并持久化消息
       // 不需要手动创建新的消息列表和对话对象

       // 退出编辑模式（先退出编辑模式，再保存，避免界面卡死）
       setState(() {
         _editingMessageUuid = null;
       });

       // 直接使用 updateMessageContent 方法更新并持久化消息
       await ref.read(currentConversationProvider.notifier).updateMessageContent(messageUuid, newText);

       // 再次调用 finalizeConversationUpdate 确保数据被持久化
       await ref.read(currentConversationProvider.notifier).finalizeConversationUpdate();

       // 数据已经成功保存

       // 显示成功提示
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('编辑已保存'), duration: Duration(seconds: 1))
         );
       }
     } catch (e) {
       // 显示错误提示
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('无法保存编辑: $e'))
         );
       }
       // 退出编辑模式
       setState(() {
         _editingMessageUuid = null;
       });
     }
   }

   // 处理取消编辑的方法
   void _handleCancelEdit() {
     setState(() {
       _editingMessageUuid = null;
     });
   }

  Future<void> _showDeleteConfirmDialog(String messageUuid) async {
     final bool? confirm = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           title: Text('删除消息?'),
           content: Text('此消息将被永久删除。'),
           actions: <Widget>[
             TextButton(
               child: Text('取消'),
               onPressed: () => Navigator.of(context).pop(false),
             ),
             TextButton(
               child: Text('删除', style: TextStyle(color: Colors.red)),
               onPressed: () => Navigator.of(context).pop(true),
             ),
           ],
         );
       },
     );

     if (confirm == true) {
       ref.read(currentConversationProvider.notifier).deleteMessage(messageUuid);
     }
  }

  @override
  void dispose() {
    // 移除滚动监听器
    _scrollController.dispose();
    super.dispose();
  }

  // 辅助方法，获取存档点的显示文本
  String _getArchivePointDisplayText(List<Map<String, dynamic>> archivePoints, String? uuid) {
    if (uuid == null || archivePoints.isEmpty) return '选择存档点';

    try {
      // 安全地查找存档点
      for (final point in archivePoints) {
        if (point['uuid'] == uuid && point['displayText'] is String) {
          return point['displayText'];
        }
      }
      // 如果找不到匹配的存档点，返回第一个存档点的显示文本
      if (archivePoints.first['displayText'] is String) {
        return archivePoints.first['displayText'];
      }
    } catch (e) {
      debugPrint('获取存档点显示文本时出错: $e');
    }

    // 默认返回值
    return '选择存档点';
  }

  // 处理创建存档
  void _handleCreateArchive(String messageUuid, int messageIndex) {
    final currentConversation = ref.read(currentConversationProvider);
    if (currentConversation == null) return;

    // 关闭消息选择
    _clearMessageSelection();

    // 显示创建存档对话框
    _showCreateArchiveDialog(messageIndex);
  }

  // 显示创建存档对话框
  void _showCreateArchiveDialog(int endIndex) {
    final currentConversation = ref.read(currentConversationProvider);
    if (currentConversation == null) return;

    // 默认存档名称
    final TextEditingController nameController = TextEditingController(text: '新存档');
    // 自定义索引控制器
    final TextEditingController customIndexController = TextEditingController();
    bool isControllerDisposed = false; // 跟踪控制器是否已释放

    // 安全释放控制器的函数
    void safeDisposeController() {
      if (!isControllerDisposed) {
        nameController.dispose();
        customIndexController.dispose();
        isControllerDisposed = true;
      }
    }

    // 查找上一个存档点
    final archiveService = ref.read(archiveServiceProvider);

    // 创建存档对话框
    void showArchiveDialog(int defaultStartIndex, List<Map<String, dynamic>> archivePoints) {
      if (!mounted) {
        safeDisposeController();
        return;
      }

      // 设置默认开始索引
      customIndexController.text = (defaultStartIndex + 1).toString();

      // 选择模式：自定义索引或从存档点选择
      String selectionMode = 'custom'; // 默认为自定义索引
      String? selectedArchivePointUuid;
      int startIndex = defaultStartIndex;

      // 更新范围描述的函数
      String getRangeDescription() {
        return '消息 ${startIndex + 1} 到 ${endIndex + 1}';
      }

      // 范围描述
      String rangeDescription = getRangeDescription();

      // 使用 StatefulBuilder 来管理对话框内的状态
      showDialog<bool>(
        context: context,
        barrierDismissible: false, // 防止点击外部关闭对话框
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Text('创建存档'),
                content: Container(
                  width: double.maxFinite,  // 限制宽度
                  constraints: BoxConstraints(maxHeight: 350),  // 增加高度以容纳更多内容
                  child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(), // 使用更平滑的滚动物理效果
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('存档范围: $rangeDescription'),
                      SizedBox(height: 16),
                      // 开始索引选择
                      Text('开始位置选择:'),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'custom',
                            groupValue: selectionMode,
                            onChanged: (value) {
                              setState(() {
                                selectionMode = value!;
                                // 如果切换到自定义模式，使用当前的startIndex
                                if (value == 'custom') {
                                  customIndexController.text = (startIndex + 1).toString();
                                }
                              });
                            },
                          ),
                          Text('自定义索引'),
                        ],
                      ),
                      if (selectionMode == 'custom')
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: TextField(
                            controller: customIndexController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '开始消息索引',
                              border: OutlineInputBorder(),
                              helperText: '输入1-$endIndex之间的数字',
                            ),
                            onChanged: (value) {
                              // 验证输入并更新startIndex
                              try {
                                final inputIndex = int.parse(value);
                                if (inputIndex >= 1 && inputIndex <= endIndex) {
                                  setState(() {
                                    startIndex = inputIndex - 1; // 转换为0基索引
                                    rangeDescription = getRangeDescription();
                                  });
                                }
                              } catch (e) {
                                // 输入不是有效数字，忽略
                              }
                            },
                          ),
                        ),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'archive_point',
                            groupValue: selectionMode,
                            onChanged: archivePoints.isEmpty ? null : (value) {
                              // 如果没有存档点，不允许选择这个选项
                              if (archivePoints.isEmpty) return;

                              // 预先选择第一个存档点，避免空值
                              String firstArchiveUuid = archivePoints.first['uuid'];
                              int firstArchiveEndIndex = archivePoints.first['endIndex'];

                              setState(() {
                                selectionMode = value!;
                                // 设置选中的存档点
                                selectedArchivePointUuid = firstArchiveUuid;
                                // 设置开始索引为选中存档点的结束索引+1
                                startIndex = firstArchiveEndIndex + 1;
                                rangeDescription = getRangeDescription();
                              });
                            },
                          ),
                          Flexible(
                            child: Text('从存档点选择${archivePoints.isEmpty ? "(无可用存档点)" : ""}', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (selectionMode == 'archive_point' && archivePoints.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 显示当前选中的存档点
                              Text('当前选中：', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                              SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4.0),
                                  color: Colors.grey.shade50,
                                ),
                                child: Text(
                                  selectedArchivePointUuid != null
                                      ? _getArchivePointDisplayText(archivePoints, selectedArchivePointUuid)
                                      : '选择存档点',
                                  style: TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text('可选存档点：', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                              SizedBox(height: 4),
                              // 显示存档点列表
                              Container(
                                constraints: BoxConstraints(maxHeight: 120),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  // 使用更高效的滚动物理效果
                                  physics: ClampingScrollPhysics(),
                                  // 预先计算高度，避免动态计算
                                  itemExtent: 40.0,
                                  itemCount: archivePoints.length,
                                  itemBuilder: (context, index) {
                                    final point = archivePoints[index];
                                    final String pointUuid = point['uuid'] as String? ?? '';
                                    final int pointEndIndex = point['endIndex'] as int? ?? 0;
                                    final String pointDisplayText = point['displayText'] as String? ?? '存档点 $index';
                                    final isSelected = pointUuid == selectedArchivePointUuid;

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedArchivePointUuid = pointUuid;
                                          startIndex = pointEndIndex + 1;
                                          rangeDescription = getRangeDescription();
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                        color: isSelected ? Colors.blue.withAlpha(25) : null,
                                        child: Text(
                                          pointDisplayText,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? Colors.blue : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: '存档名称',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                    ],
                  ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('取消'),
                    onPressed: () {
                      // 在关闭对话框前先将控制器标记为已释放
                      isControllerDisposed = true;
                      try {
                        Navigator.of(dialogContext).pop(false);
                      } catch (e) {
                        // 错误处理
                        debugPrint('关闭对话框时出错: $e');
                      }
                    },
                  ),
                  TextButton(
                    child: Text('保存'),
                    onPressed: () {
                      // 验证开始索引
                      if (startIndex < 0 || startIndex >= endIndex) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('无效的开始索引，必须在1到$endIndex之间')),
                        );
                        return;
                      }

                      // 验证存档名称
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('存档名称不能为空')),
                        );
                        return;
                      }

                      // 先关闭对话框，避免ANR
                      try {
                        // 不要在这里释放控制器，因为我们还需要它的值
                        Navigator.of(dialogContext).pop(true);
                      } catch (e) {
                        debugPrint('关闭对话框时出错: $e');
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ).then((result) {
        if (!mounted) {
          safeDisposeController();
          return;
        }

        if (result == true) {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('存档名称不能为空')),
              );
            }
            safeDisposeController();
            return;
          }

          // 显示加载提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('正在创建存档...'), duration: Duration(seconds: 1)),
            );
          }

          // 创建存档
          archiveService.createArchive(
            name: name,
            conversation: currentConversation,
            startIndex: startIndex,
            endIndex: endIndex,
          ).then((archive) {
            safeDisposeController(); // 安全释放控制器

            if (!mounted) return;

            if (archive != null) {
              // 创建成功，刷新存档列表
              ref.invalidate(archiveListProvider);

              // 显示成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('存档创建成功')),
              );

              // 导航到存档列表页面
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ArchiveScreen()),
              );
            } else {
              // 创建失败
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('创建存档失败'), backgroundColor: Colors.red),
              );
            }
          }).catchError((e) {
            safeDisposeController(); // 安全释放控制器

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('创建存档时出错: $e'), backgroundColor: Colors.red),
            );
          });
        } else {
          safeDisposeController(); // 安全释放控制器
        }
      }).catchError((e) {
        debugPrint('对话框操作出错: $e');
        safeDisposeController(); // 确保在错误情况下也释放控制器
      });
    }

    // 获取所有存档点并显示对话框
    Future.wait([
      archiveService.findLastArchivePoint(currentConversation.uuid, endIndex),
      archiveService.getAllArchivePoints(currentConversation.uuid, endIndex)
    ]).then((results) {
      if (!mounted) {
        safeDisposeController();
        return;
      }

      final int? lastArchivePoint = results[0] as int?;
      final List<Map<String, dynamic>> archivePoints = results[1] as List<Map<String, dynamic>>;

      // 存档范围（从上一个存档点或开头到当前消息）
      final int defaultStartIndex = lastArchivePoint != null ? lastArchivePoint + 1 : 0;
      showArchiveDialog(defaultStartIndex, archivePoints);
    }).catchError((e) {
      if (!mounted) {
        safeDisposeController();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查找存档点时出错: $e'), backgroundColor: Colors.red),
      );
      safeDisposeController();
    });
  }
}