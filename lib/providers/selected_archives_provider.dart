import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_archives.dart';
import '../models/archive.dart';

// Provider for the selected archives state
final selectedArchivesProvider = StateNotifierProvider<SelectedArchivesNotifier, SelectedArchives>((ref) {
  return SelectedArchivesNotifier();
});

class SelectedArchivesNotifier extends StateNotifier<SelectedArchives> {
  SelectedArchivesNotifier() : super(SelectedArchives.empty());

  // Add an archive to the selection
  void addArchive(Archive archive) {
    if (archive.summary == null) {
      return; // Skip archives without summary
    }
    
    final archiveInfo = SelectedArchiveInfo.fromArchive(archive);
    state = state.add(archiveInfo);
  }

  // Remove an archive from the selection
  void removeArchive(String uuid) {
    state = state.remove(uuid);
  }

  // Clear all selected archives
  void clearArchives() {
    state = state.clear();
  }

  // Get the system prompt prefix for the selected archives
  String getSystemPromptPrefix() {
    return state.generateSystemPromptPrefix();
  }
}
