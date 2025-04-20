import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

// Provider for the ApiService instance
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
}); 