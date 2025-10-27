// lib/src/core/cache_manager/cache_manager.dart

import 'package:dio/dio.dart';

import '../models/typedef.dart';

/// Abstract interface for cache storage implementations.
///
/// This interface defines the contract for cache storage in Network Sanitizer.
/// Implement this interface to provide custom cache storage solutions.
///
/// The default implementation uses [HiveCacheManager] which provides
/// cross-platform storage using the Hive database.
///
/// ## Custom Implementation Example
///
/// ```dart
/// class MyCustomCacheManager implements SanitizerCacheManager {
///   @override
///   Future<void> setData(String key, Response response) async {
///     // Store the response with the given key
///   }
///
///   @override
///   Future<Response?> getData(String key, RequestOptions options) async {
///     // Retrieve and return the cached response, or null if not found
///     return null;
///   }
///
///   @override
///   Future<void> clearAll() async {
///     // Clear all cached data
///   }
///
///   @override
///   Future<void> remove(String key) async {
///     // Remove cached data for the specific key
///   }
/// }
/// ```
abstract class SanitizerCacheManager {
  /// Stores a response in the cache with the given key.
  ///
  /// [key] - Unique identifier for the cached response
  /// [response] - The Dio response to cache
  Future<void> setData(String key, Response response);

  /// Retrieves a cached response for the given key.
  ///
  /// Returns the cached [Response] if found, null otherwise.
  ///
  /// [key] - Unique identifier for the cached response
  /// [options] - The original request options (for context)
  Future<Response?> getData(String key, RequestOptions options);

  /// Clears all cached data.
  ///
  /// This method should remove all stored cache entries.
  Future<void> clearAll();

  /// Removes a specific cached entry.
  ///
  /// [key] - Unique identifier for the cached response to remove
  Future<void> remove(String key);

  /// Removes a cached entries on conditional basis.
  ///
  /// [condition] - Unique identifier for the cached response to remove
  Future<void> removeConditional(RequestMatcher condition);
}
