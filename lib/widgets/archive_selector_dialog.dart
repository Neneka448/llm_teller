import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/archive.dart';
import '../providers/archive_providers.dart';
import '../providers/selected_archives_provider.dart';
import '../services/archive_service.dart';

class ArchiveSelectorDialog extends ConsumerStatefulWidget {
  final String conversationUuid;

  const ArchiveSelectorDialog({
    Key? key,
    required this.conversationUuid,
  }) : super(key: key);

  @override
  _ArchiveSelectorDialogState createState() => _ArchiveSelectorDialogState();
}

class _ArchiveSelectorDialogState extends ConsumerState<ArchiveSelectorDialog> {
  List<Archive> _availableArchives = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final archiveService = ref.read(archiveServiceProvider);
      final archives = await archiveService.findArchivesByConversation(widget.conversationUuid);
      
      // Filter archives with summaries
      final archivesWithSummary = archives.where((archive) => archive.summary != null).toList();
      
      setState(() {
        _availableArchives = archivesWithSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载存档失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedArchives = ref.watch(selectedArchivesProvider);
    
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
              title: Text('选择存档点'),
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
              child: _buildContent(),
            ),
            
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('关闭'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
      );
    }

    if (_availableArchives.isEmpty) {
      return Center(
        child: Text('没有可用的存档点，请先创建带有AI摘要的存档'),
      );
    }

    return ListView.builder(
      itemCount: _availableArchives.length,
      itemBuilder: (context, index) {
        final archive = _availableArchives[index];
        return _buildArchiveItem(archive);
      },
    );
  }

  Widget _buildArchiveItem(Archive archive) {
    final selectedArchivesNotifier = ref.read(selectedArchivesProvider.notifier);
    final selectedArchives = ref.watch(selectedArchivesProvider);
    final isSelected = selectedArchives.archives.any((a) => a.uuid == archive.uuid);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(archive.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (archive.summary != null) ...[
              Text('时间: ${archive.summary!.time}', style: TextStyle(fontSize: 12)),
              Text('地点: ${archive.summary!.place}', style: TextStyle(fontSize: 12)),
              Text(
                '描述: ${archive.summary!.desc}',
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (value) {
            if (value == true) {
              selectedArchivesNotifier.addArchive(archive);
            } else {
              selectedArchivesNotifier.removeArchive(archive.uuid);
            }
          },
        ),
        onTap: () {
          if (isSelected) {
            selectedArchivesNotifier.removeArchive(archive.uuid);
          } else {
            selectedArchivesNotifier.addArchive(archive);
          }
        },
      ),
    );
  }
}
