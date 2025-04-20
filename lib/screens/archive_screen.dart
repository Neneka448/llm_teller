import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/archive.dart';
import '../providers/archive_providers.dart';
import '../services/archive_service.dart';
import 'archive_detail_screen.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivesAsyncValue = ref.watch(archiveListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('存档列表'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
        actions: [
          // 刷新按钮
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: () {
              // 显示刷新提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('正在刷新列表...'), duration: Duration(seconds: 1))
              );
              // 强制刷新列表
              ref.invalidate(archiveListProvider);
            },
          ),
        ],
      ),
      body: archivesAsyncValue.when(
        data: (archives) {
          if (archives.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无存档', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: archives.length,
            itemBuilder: (context, index) {
              final archive = archives[index];
              return _buildArchiveItem(context, ref, archive);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('加载存档失败: $error', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildArchiveItem(BuildContext context, WidgetRef ref, Archive archive) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(archive.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(archive.rangeDescription, style: TextStyle(fontSize: 12)),
            SizedBox(height: 4),
            Text(
              archive.summaryDescription,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI摘要按钮
            IconButton(
              icon: Icon(Icons.auto_awesome, size: 20),
              tooltip: '生成AI摘要',
              onPressed: () => _generateSummary(context, ref, archive),
            ),
            // 重命名按钮
            IconButton(
              icon: Icon(Icons.edit, size: 20),
              tooltip: '重命名',
              onPressed: () => _showRenameDialog(context, ref, archive),
            ),
            // 删除按钮
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20),
              tooltip: '删除',
              onPressed: () => _showDeleteConfirmDialog(context, ref, archive),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArchiveDetailScreen(archiveUuid: archive.uuid),
            ),
          );
        },
      ),
    );
  }

  // 显示重命名对话框
  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref, Archive archive) async {
    final TextEditingController controller = TextEditingController(text: archive.name);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('重命名存档'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '输入新名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('保存'),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final archiveService = ref.read(archiveServiceProvider);
                  final success = await archiveService.renameArchive(archive.uuid, newName);

                  if (success) {
                    // 刷新列表
                    ref.invalidate(archiveListProvider);

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('存档已重命名'))
                      );
                    }
                  } else if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('重命名失败'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, Archive archive) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('删除存档?'),
          content: Text('此存档将被永久删除。'),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('删除', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final archiveService = ref.read(archiveServiceProvider);
                final success = await archiveService.deleteArchive(archive.uuid);

                if (success) {
                  // 刷新列表
                  ref.invalidate(archiveListProvider);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('存档已删除'))
                    );
                  }
                } else if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败'), backgroundColor: Colors.red)
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 生成AI摘要
  Future<void> _generateSummary(BuildContext context, WidgetRef ref, Archive archive) async {
    // 显示加载对话框
    _showLoadingDialog(context, '正在生成AI摘要...');

    try {
      final archiveService = ref.read(archiveServiceProvider);
      final success = await archiveService.generateSummary(archive.uuid);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // 刷新列表
        ref.invalidate(archiveListProvider);
        // 同时刷新存档详情数据，确保详情页面也能看到更新
        ref.invalidate(archiveProvider(archive.uuid));

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

  // 显示加载对话框
  AlertDialog _showLoadingDialog(BuildContext context, String message) {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return alert;
      },
    );

    return alert;
  }
}
