// lib/src/core/cache_manager/hive_cache_manager.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../constants/sanitizer_constants.dart';

import '../models/duration_adaptor.dart';
import '../models/hive_cached_response.dart';
import '../models/typedef.dart';
import 'cache_manager.dart';

class HiveCacheManager implements SanitizerCacheManager {
  late final Box<HiveCachedResponse> _box;
  late final _RequestKeyGenerator _keyManager;
  bool _isInitialized = false;

  HiveCacheManager() {
    _initHive();
    _keyManager = _RequestKeyGenerator();
  }

  Future<void> _initHive() async {
    if (!_isInitialized) {
      await Hive.initFlutter();
      Hive
        ..registerAdapter(HiveCachedResponseAdapter())
        ..registerAdapter(DurationAdapter());

      const currentVersion = 2; // ← increment when schema changes
      const boxName = '${SanitizerConstants.hiveBoxName}_v$currentVersion';

      // Delete all old boxes before opening the new one
      try {
        if (await Hive.boxExists(SanitizerConstants.hiveBoxName)) {
          await Hive.deleteBoxFromDisk(SanitizerConstants.hiveBoxName);
        }
        for (int i = 1; i < currentVersion; i++) {
          final oldBoxName = '${SanitizerConstants.hiveBoxName}_v$i';
          if (await Hive.boxExists(oldBoxName)) {
            await Hive.deleteBoxFromDisk(oldBoxName);
          }
        }
      } catch (_) {}
      _box = await Hive.openBox<HiveCachedResponse>(boxName);
      _isInitialized = true;
    }
  }

  @override
  Future<Response?> getData(String key, RequestOptions options) async {
    await _ensureInitialized();
    final cachedResponse = _box.get(_keyManager.getHashedKey(key));
    if (cachedResponse != null) {
      return cachedResponse.toResponse(options);
    }
    return null;
  }

  @override
  Future<void> setData(String key, Response response) async {
    await _ensureInitialized();
    final duration =
        response.requestOptions.extra[SanitizerConstants
            .cacheValidityDurationKey];
    final shortKey = _keyManager.getHashedKey(key);
    final cachedResponse = HiveCachedResponse.fromResponse(
      key: shortKey,
      response: response,
      validityDuration: duration is Duration ? duration : null,
    );
    await _box.put(shortKey, cachedResponse);
  }

  @override
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _box.clear();
  }

  @override
  Future<void> remove(String key) async {
    await _ensureInitialized();
    await _box.delete(_keyManager.getHashedKey(key));
  }

  @override
  Future<void> removeConditional(RequestMatcher condition) async {
    if (!_isInitialized) {
      await _initHive();
    }
    final selectedKeys = _box.values
        .where(
          (a) => condition(
            RequestDetails(a.method, a.requestUrl, a.queryParameters),
          ),
        )
        .map((e) => e.key);
    _keyManager._removeKeys(selectedKeys.toSet());
    for (final key in selectedKeys) {
      await _box.delete(key);
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initHive();
    }
  }
}

class _RequestKeyGenerator {
  final _cache = <String, String>{};

  String getHashedKey(String rawKey) {
    return _cache.putIfAbsent(
      rawKey,
      () => sha256.convert(utf8.encode(rawKey)).toString(),
    );
  }

  void _removeKeys(Set<String> hashedKeys) {
    for (final hashedKey in hashedKeys) {
      _cache.removeWhere((key, value) => value == hashedKey);
    }
  }
}
