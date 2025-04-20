import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/archive.dart';
import '../models/archive_summary.dart';
import '../models/chat_message.dart';
import '../providers/archive_providers.dart';
import '../services/archive_service.dart';

class ArchiveDetailScreen extends ConsumerWidget {
  final String archiveUuid;

  const ArchiveDetailScreen({Key? key, required this.archiveUuid}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsyncValue = ref.watch(archiveProvider(archiveUuid));

    return Scaffold(
      appBar: AppBar(
        title: archiveAsyncValue.when(
          data: (archive) => Text(archive?.name ?? '存档详情'),
          loading: () => Text('加载中...'),
          error: (_, __) => Text('存档详情'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
      ),
      body: archiveAsyncValue.when(
        data: (archive) {
          if (archive == null) {
            return Center(
              child: Text('存档不存在或已被删除', style: TextStyle(color: Colors.red)),
            );
          }

          return Column(
            children: [
              // 存档信息卡片
              Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('存档名称: ${archive.name}', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('消息范围: ${archive.rangeDescription}'),
                      SizedBox(height: 8),
                      Text('创建时间: ${_formatDateTime(archive.createdAt)}'),
                      SizedBox(height: 8),
                      _buildSummarySection(context, ref, archive),
                    ],
                  ),
                ),
              ),

              // 消息列表
              Expanded(
                child: _buildMessageList(archive),
              ),

              // 添加底部安全区域
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('加载存档失败: $error', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildMessageList(Archive archive) {
    if (archive.messages.isEmpty) {
      return Center(
        child: Text('此存档没有消息', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: archive.messages.length,
      itemBuilder: (context, index) {
        final message = archive.messages[index];
        return _buildReadOnlyMessageBubble(message);
      },
    );
  }

  Widget _buildReadOnlyMessageBubble(ChatMessage message) {
    return Builder(
      builder: (context) {
        final isUser = message.sender == MessageSender.user;
        final isSystem = message.sender == MessageSender.system;
        final isAi = message.sender == MessageSender.ai;

        // 系统消息
        if (isSystem) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          );
        }

        // 用户和AI消息
        return Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isUser
                      ? MediaQuery.of(context).size.width * 0.75
                      : MediaQuery.of(context).size.width * 0.9,
                ),
                margin: EdgeInsets.symmetric(
                  vertical: 4.0,
                  horizontal: isUser ? 8.0 : 8.0,
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
                      color: Colors.black.withAlpha(26),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: isAi
                    ? MarkdownBody(
                        data: message.text,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                fontSize: 16.0,
                                height: 1.3,
                              ),
                          blockSpacing: 8.0,
                          listIndent: 16.0,
                          code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                backgroundColor: Colors.grey.shade200,
                                fontFamily: 'monospace',
                                color: Colors.black87,
                                fontSize: 14.0,
                              ),
                          codeblockDecoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: Colors.grey.shade300)),
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
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 构建摘要部分
  Widget _buildSummarySection(BuildContext context, WidgetRef ref, Archive archive) {
    // 如果没有摘要，显示生成按钮
    if (archive.summary == null) {
      return Row(
        children: [
          Text('摘要: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(
            icon: Icon(Icons.auto_awesome),
            label: Text('生成AI摘要'),
            onPressed: () => _generateSummary(context, ref, archive),
          ),
        ],
      );
    }

    // 如果有摘要，显示摘要内容和展开/折叠按钮
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 摘要标题和概述
        ListTile(
          title: Text('摘要', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(archive.summary!.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: Icon(Icons.arrow_forward_ios),
            onPressed: () {
              // 打开摘要详情对话框
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    insetPadding: EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题栏
                          AppBar(
                            title: Text('摘要详情'),
                            automaticallyImplyLeading: false,
                            actions: [
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          // 内容区域
                          Expanded(
                            child: _buildSummaryDetails(context, archive.summary!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 构建摘要详情
  Widget _buildSummaryDetails(BuildContext context, ArchiveSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间和地点
          Row(
            children: [
              Expanded(
                child: _buildInfoCard('时间', summary.time),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard('地点', summary.place),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 关键词
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关键词', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: summary.keywords.map((keyword) => _buildKeywordChip(keyword)).toList(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // 故事概要
          _buildInfoCard('故事概要', summary.desc),
          SizedBox(height: 16),

          // 人物信息
          Text('人物信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          ...summary.characters.map((character) => _buildCharacterCard(character)),
          // 添加底部填充，防止内容被遮挡
          SizedBox(height: 24),
        ],
      ),
    );
  }

  // 构建关键词芯片
  Widget _buildKeywordChip(String keyword) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Text(
        keyword,
        style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 14),
      ),
    );
  }

  // 构建信息卡片
  Widget _buildInfoCard(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            Text(content, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // 构建人物卡片
  Widget _buildCharacterCard(Character character) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(character.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            ...character.events.map((event) => _buildEventItem(event)),
          ],
        ),
      ),
    );
  }

  // 构建事件项
  Widget _buildEventItem(CharacterEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('● ${event.name}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(event.desc, style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // 生成AI摘要
  Future<void> _generateSummary(BuildContext context, WidgetRef ref, Archive archive) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在生成AI摘要...')),
            ],
          ),
        );
      },
    );

    try {
      final archiveService = ref.read(archiveServiceProvider);
      final success = await archiveService.generateSummary(archive.uuid);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // 刷新存档数据
        ref.invalidate(archiveProvider(archive.uuid));
        // 同时刷新存档列表，确保列表页面也能看到更新
        ref.invalidate(archiveListProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI摘要生成成功'))
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI摘要生成失败'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成摘要时出错: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
}
