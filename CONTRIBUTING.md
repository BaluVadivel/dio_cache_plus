# Contributing to Dio Cache Plus

We love your input! We want to make contributing to Dio Cache Plus as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code lints
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License

When you submit code changes, your submissions are understood to be under the same [MIT License](LICENSE) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using GitHub's [issue tracker](https://github.com/BaluVadivel/dio_cache_plus/issues)

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/BaluVadivel/dio_cache_plus/issues/new); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Development Setup

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- IDE of your choice (VS Code, Android Studio, etc.)

### Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/dio_cache_plus.git
   cd dio_cache_plus
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run tests**
   ```bash
   flutter test
   ```

4. **Run example app**
   ```bash
   cd example
   flutter run
   ```

## Code Style Guidelines

### Dart Code Style

We follow the [Effective Dart](https://dart.dev/effective-dart) style guide.

- Use `dart format` to format your code
- Follow the existing code style in the project
- Write clear, descriptive variable and method names

### Example of Good Code Style

```dart
// Good
class CacheManager {
  final Box<HiveCachedResponse> _cacheBox;
  
  Future<Response?> getCachedResponse(String key) async {
    // Implementation
  }
}

// Avoid
class cm {
  final Box<HiveCachedResponse> b;
  
  Future<Response?> get(String k) async {
    // Implementation
  }
}
```

## Testing

### Writing Tests

We value comprehensive testing. Please include tests with your contributions.

**Test Structure:**
```dart
void main() {
  group('DioCachePlusInterceptor', () {
    late Dio dio;
    late DioCachePlusInterceptor interceptor;

    setUp(() {
      dio = Dio();
      interceptor = DioCachePlusInterceptor(
        cacheAll: false,
        commonCacheDuration: const Duration(minutes: 5),
        isErrorResponse: (response) => response.statusCode != 200,
      );
      dio.interceptors.add(interceptor);
    });

    test('should cache GET requests when enabled', () async {
      // Test implementation
    });

    test('should not cache POST requests', () async {
      // Test implementation
    });
  });
}
```

**What to test:**
- Cache hit/miss scenarios
- Expiry logic
- Conditional caching rules
- Request deduplication
- Error scenarios
- Edge cases

## Pull Request Process

1. **Update the README.md** with details of changes if applicable
2. **Update the documentation** for any new methods or parameters
3. **Add tests** for new functionality
4. **Ensure all tests pass** and code is properly formatted
5. **Create a clear PR description** explaining:
   - What changes were made
   - Why they were made
   - Any breaking changes
   - How to test the changes

### PR Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] All new and existing tests passed

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
```

## Feature Requests

We love feature requests! When suggesting new features:

1. **Use the feature request template**
2. **Explain the problem** you're trying to solve
3. **Provide use cases** and examples
4. **Consider the API design** - how would developers use this feature?
5. **Think about performance implications**

### Example Feature Request

```markdown
## Problem
Currently, cache duration is fixed per request. There's no way to dynamically adjust cache time based on external factors.

## Proposed Solution
Add support for function-based duration calculation that executes at cache time.

## Use Cases
1. Cache data longer during off-peak hours
2. Adjust cache duration based on user subscription level
3. Dynamic cache invalidation based on business rules

## API Design
```dart
options.setCachingWithDurationFn(
  enableCache: true,
  durationFn: () {
    final hour = DateTime.now().hour;
    return hour >= 22 ? Duration(hours: 4) : Duration(minutes: 30);
  },
);
```
```

## Documentation

### Updating Documentation

When making code changes that affect the API:

1. **Update the README.md** with new examples and usage
2. **Add doc comments** to all public methods and classes
3. **Update the example app** if applicable
4. **Consider writing a blog post** for significant features

### Doc Comment Standards

```dart
/// Retrieves cached response for the given key.
///
/// [key] - The unique cache key generated from request parameters
/// [options] - Original request options for context
///
/// Returns the cached [Response] if found and valid, null otherwise.
///
/// Example:
/// ```dart
/// final cached = await cacheManager.getData(key, options);
/// if (cached != null) {
///   return cached;
/// }
/// ```
Future<Response?> getData(String key, RequestOptions options) async {
  // Implementation
}
```

## Project Structure

```
dio_cache_plus/
├── lib/
│   ├── src/
│   │   ├── core/
│   │   │   ├── cache_manager/
│   │   │   ├── constants/
│   │   │   └── models/
│   │   └── dio_cache_plus_interceptor.dart
│   └── dio_cache_plus.dart
├── test/
├── example/
└── README.md
```

## Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality in a backward compatible manner
- **PATCH** version for backward compatible bug fixes

## Community

### Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and community discussions
- **Stack Overflow**: Use the `dio-cache-plus` tag

### Becoming a Maintainer

We're always looking for dedicated contributors to become maintainers. If you're interested:

1. Start by contributing regularly
2. Help triage issues and review PRs
3. Show good judgment and understanding of the codebase
4. Express interest to the current maintainers

## Recognition

Contributors who make significant contributions will be added to our contributors list. We believe in giving credit where it's due!

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

## Questions?

Feel free to contact the maintainers or open an issue for discussion.

---

Thank you for contributing to Dio Cache Plus! 🎉