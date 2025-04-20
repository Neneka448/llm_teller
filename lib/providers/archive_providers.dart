import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/archive.dart';
import '../services/archive_service.dart';

// 提供所有存档列表的 Provider
final archiveListProvider = FutureProvider<List<Archive>>((ref) async {
  final archiveService = ref.watch(archiveServiceProvider);
  return await archiveService.loadAllArchives();
});

// 提供特定对话的存档列表的 Provider
final conversationArchivesProvider = FutureProvider.family<List<Archive>, String>((ref, conversationUuid) async {
  final archiveService = ref.watch(archiveServiceProvider);
  return await archiveService.findArchivesByConversation(conversationUuid);
});

// 提供特定存档的 Provider
final archiveProvider = FutureProvider.family<Archive?, String>((ref, uuid) async {
  final archiveService = ref.watch(archiveServiceProvider);
  return await archiveService.loadArchive(uuid);
});
