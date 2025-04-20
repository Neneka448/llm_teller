import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/selected_archives_provider.dart';
import '../providers/conversation_providers.dart';
import 'archive_selector_dialog.dart';

class ChatInputField extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;

  const ChatInputField({Key? key, required this.onSendMessage}) : super(key: key);

  @override
  ConsumerState<ChatInputField> createState() => ChatInputFieldState();
}

// 将类改为公开类以便于外部访问
class ChatInputFieldState extends ConsumerState<ChatInputField> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // 添加焦点节点
  bool _isComposing = false;
  bool _isExpanded = false; // 默认收起状态

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _isComposing = _textController.text.isNotEmpty;
      });
    });
  }

  // 显示存档点选择对话框
  void _showArchiveSelectorDialog() {
    final currentConversation = ref.read(currentConversationProvider);
    if (currentConversation == null) return;

    showDialog(
      context: context,
      builder: (context) => ArchiveSelectorDialog(
        conversationUuid: currentConversation.uuid,
      ),
    );
  }

  // 构建已选择的存档点列表
  Widget _buildSelectedArchivesList() {
    final selectedArchives = ref.watch(selectedArchivesProvider);

    if (selectedArchives.isEmpty) {
      return SizedBox.shrink(); // 如果没有选择的存档点，不显示任何内容
    }

    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedArchives.archives.length,
              itemBuilder: (context, index) {
                final archive = selectedArchives.archives[index];
                return Container(
                  margin: EdgeInsets.only(left: 8.0),
                  child: Chip(
                    label: Text(
                      archive.name,
                      style: TextStyle(fontSize: 12),
                    ),
                    deleteIcon: Icon(Icons.close, size: 16),
                    onDeleted: () {
                      ref.read(selectedArchivesProvider.notifier).removeArchive(archive.uuid);
                    },
                  ),
                );
              },
            ),
          ),
          // 清空按钮
          if (selectedArchives.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, size: 20),
              tooltip: '清空所有选择',
              onPressed: () {
                ref.read(selectedArchivesProvider.notifier).clearArchives();
              },
            ),
        ],
      ),
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isNotEmpty) {
      // 获取选中的存档点前缀
      final selectedArchivesNotifier = ref.read(selectedArchivesProvider.notifier);
      final systemPromptPrefix = selectedArchivesNotifier.getSystemPromptPrefix();

      // 获取当前会话
      final currentConversation = ref.read(currentConversationProvider);

      // 如果有选中的存档点，修改系统提示词
      if (systemPromptPrefix.isNotEmpty && currentConversation != null) {
        // 获取原始系统提示词
        String originalSystemPrompt = currentConversation.systemPrompt ?? '';

        // 合并系统提示词
        String newSystemPrompt = systemPromptPrefix + originalSystemPrompt;

        // 使用合并后的系统提示词发送消息
        final notifier = ref.read(currentConversationProvider.notifier);
        notifier.requestAiResponseWithSystemPrompt(text.trim(), newSystemPrompt);
        _textController.clear();
        return;
      }

      // 如果没有选中存档点，使用正常的发送方式
      widget.onSendMessage(text.trim());
      _textController.clear();
    }
  }

  // 切换输入框展开/收起状态
  void toggleExpanded() {
    // 如果当前是收起状态，则展开
    // 如果已经是展开状态，则保持展开
    if (!_isExpanded) {
      setState(() {
        _isExpanded = true;
      });
    }
    // 注意：我们不再在这里切换状态，只允许从收起到展开
  }

  // 收起输入框
  void collapse() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withAlpha(13), // 相当于 0.05 的不透明度
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行输入框和发送按钮 (始终显示)
            Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // 点击输入框时直接展开并获取焦点
                      setState(() {
                        _isExpanded = true; // 直接设置为展开状态
                      });

                      // 在下一帧获取焦点
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _focusNode.requestFocus();
                        }
                      });
                    }, // 点击输入框时展开状态
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: _isExpanded
                        ? TextField(
                            controller: _textController,
                            focusNode: _focusNode, // 使用我们的焦点节点
                            onSubmitted: _isComposing ? _handleSubmitted : null,
                            decoration: InputDecoration.collapsed(
                              hintText: 'Type your question here...', // 图片中的提示文字
                            ),
                            keyboardType: TextInputType.multiline,
                            maxLines: null, // 允许多行输入
                            textInputAction: TextInputAction.send, // 将回车键设为发送
                            onChanged: (text) {
                              // 触发 listener 更新 _isComposing
                            },
                            // 移除自动获取焦点，防止键盘自动弹出
                          )
                        : Text(
                            'Type your question here...',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isExpanded && _isComposing
                      ? () => _handleSubmitted(_textController.text)
                      : null,
                  color: _isExpanded && _isComposing ? Theme.of(context).primaryColor : Colors.grey,
                ),
              ],
            ),
            // 展开时显示的额外控件
            if (_isExpanded) ...[
              // 工具栏
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: Icon(Icons.add, size: 22), onPressed: () {/* TODO: 文件 */}),
                        IconButton(icon: Icon(Icons.image_outlined, size: 22), onPressed: () {/* TODO: 图片 */}),
                        IconButton(
                          icon: Icon(Icons.bookmark_outline, size: 22),
                          tooltip: '选择存档点',
                          onPressed: _showArchiveSelectorDialog,
                        ),
                      ]
                    ),
                  ],
                ),
              ),
              // 已选择的存档点水平列表
              _buildSelectedArchivesList(),
            ],
          ],
        )
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose(); // 释放焦点节点
    super.dispose();
  }
}