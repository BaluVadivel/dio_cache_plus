// lib/src/core/models/conditional_cache_rule.dart

import 'typedef.dart';

class ConditionalCacheRule {
  final RequestMatcher condition;
  final Duration? duration;
  final Duration Function()? durationFn;
  final DateTime? expiry;
  final DateTime Function()? expiryFn;

  // Private constructor
  ConditionalCacheRule._({
    required this.condition,
    this.duration,
    this.durationFn,
    this.expiry,
    this.expiryFn,
  });

  // Factory constructors for each type
  factory ConditionalCacheRule.duration({
    required RequestMatcher condition,
    required Duration duration,
  }) {
    return ConditionalCacheRule._(condition: condition, duration: duration);
  }

  factory ConditionalCacheRule.durationFn({
    required RequestMatcher condition,
    required Duration Function() durationFn,
  }) {
    return ConditionalCacheRule._(condition: condition, durationFn: durationFn);
  }

  factory ConditionalCacheRule.expiry({
    required RequestMatcher condition,
    required DateTime expiry,
  }) {
    return ConditionalCacheRule._(condition: condition, expiry: expiry);
  }

  factory ConditionalCacheRule.expiryFn({
    required RequestMatcher condition,
    required DateTime Function() expiryFn,
  }) {
    return ConditionalCacheRule._(condition: condition, expiryFn: expiryFn);
  }

  // For cases where no duration/expiry is provided (uses global default)
  factory ConditionalCacheRule.conditionalOnly({
    required RequestMatcher condition,
  }) {
    return ConditionalCacheRule._(condition: condition);
  }
}
