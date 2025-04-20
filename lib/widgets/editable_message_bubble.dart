import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class EditableMessageBubble extends ConsumerStatefulWidget {
  final String messageUuid;
  final String initialText;
  final MessageSender sender;
  final Function(String messageUuid, String newText) onSave;
  final VoidCallback onCancel;

  const EditableMessageBubble({
    Key? key,
    required this.messageUuid,
    required this.initialText,
    required this.sender,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  _EditableMessageBubbleState createState() => _EditableMessageBubbleState();
}

class _EditableMessageBubbleState extends ConsumerState<EditableMessageBubble> {
  late TextEditingController _textController;
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);

    // 添加一个延迟，确保编辑框显示后自动滚动到可见区域
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 滚动到编辑框位置
      Scrollable.ensureVisible(
        context,
        alignment: 0.5, // 将编辑框尽量居中显示
        duration: Duration(milliseconds: 300),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final newText = _textController.text.trim();
    if (newText.isNotEmpty) {
      widget.onSave(widget.messageUuid, newText);
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.sender == MessageSender.user;

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isUser
                  ? MediaQuery.of(context).size.width * 0.75 // 用户消息宽度保持不变
                  : MediaQuery.of(context).size.width * 0.9, // AI消息宽度进一步增加
            ),
            margin: EdgeInsets.symmetric(
              vertical: 8.0, // 增加垂直间距
              horizontal: isUser ? 8.0 : 8.0, // 增加AI消息的左侧边距
            ),
            padding: EdgeInsets.only(top: 16.0, bottom: 16.0, left: 16.0, right: 8.0), // 减少右侧内边距
            decoration: BoxDecoration(
              color: isUser ? Colors.deepPurple.shade50 : Colors.grey.shade50, // 使用更浅的背景色
              borderRadius: BorderRadius.circular(16.0), // 统一圆角
              border: Border.all(color: isUser ? Colors.deepPurple.shade300 : Colors.blue.shade300, width: 1.5), // 美化边框
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // 相当于 0.05 的不透明度
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文本输入框
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLines: null,
                    minLines: 3, // 最少显示3行
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16.0,
                      height: 1.4, // 增加行高
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: isUser ? Colors.deepPurple.shade300 : Colors.blue.shade300, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: '输入消息内容',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                ),
                SizedBox(height: 16), // 增加间距
                // 按钮行
                Padding(
                  padding: EdgeInsets.only(bottom: 8.0), // 增加底部间距
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 取消按钮
                      TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          backgroundColor: Colors.grey.shade100,
                        ),
                        child: Text('取消'),
                      ),
                      SizedBox(width: 12),
                      // 保存按钮
                      TextButton(
                        onPressed: _handleSave,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          backgroundColor: isUser ? Colors.deepPurple.shade400 : Colors.blue.shade400,
                        ),
                        child: Text('保存'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
