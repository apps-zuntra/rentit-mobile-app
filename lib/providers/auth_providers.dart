import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:rentit/core/api_service.dart';

/// Terms checkbox
final termsProvider = StateProvider<bool>((ref) => false);

/// Promo checkbox
final promoProvider = StateProvider<bool>((ref) => false);

/// Loading state
final loadingProvider = StateProvider<bool>((ref) => false);

/// Api Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
