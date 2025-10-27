import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dio with cache interceptor
  final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));

  dio.interceptors.add(
    DioCachePlusInterceptor(
      cacheAll: false, // Require explicit caching
      commonCacheDuration: const Duration(minutes: 5), // Default cache duration
      isErrorResponse: (response) => response.statusCode != 200,

      // Conditional caching rules
      conditionalRules: [
        // Cache user data with static duration
        ConditionalCacheRule.duration(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/users'),
          duration: const Duration(minutes: 10),
        ),

        // Cache posts with dynamic duration based on time of day
        ConditionalCacheRule.durationFn(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/posts'),
          durationFn: () {
            final hour = DateTime.now().hour;
            // Cache longer during off-peak hours
            return hour >= 22 || hour < 6
                ? const Duration(hours: 2)
                : const Duration(minutes: 30);
          },
        ),

        // Cache comments until specific time
        ConditionalCacheRule.expiry(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/comments'),
          expiry: DateTime.now().add(
            const Duration(hours: 1),
          ), // Cache for 1 hour
        ),

        // Cache albums with dynamic expiry
        ConditionalCacheRule.expiryFn(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/albums'),
          expiryFn: () {
            final now = DateTime.now();
            // Cache until end of day
            return DateTime(now.year, now.month, now.day, 23, 59, 59);
          },
        ),
      ],
    ),
  );

  runApp(MyApp(dio: dio));
}

class MyApp extends StatelessWidget {
  final Dio dio;

  const MyApp({super.key, required this.dio});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dio Cache Plus Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: CacheExamplePage(dio: dio),
    );
  }
}

class CacheExamplePage extends StatefulWidget {
  final Dio dio;

  const CacheExamplePage({super.key, required this.dio});

  @override
  State<CacheExamplePage> createState() => _CacheExamplePageState();
}

class _CacheExamplePageState extends State<CacheExamplePage> {
  final List<String> _logs = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.insert(
        0,
        '${DateTime.now().toString().split('.').first}: $message',
      );
    });
  }

  Future<void> _fetchWithStaticDuration() async {
    setState(() => _isLoading = true);
    _addLog('🔵 Fetching users with static duration (10 minutes)...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/users',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
        ),
      );
      stopwatch.stop();

      _addLog('✅ Users fetched in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} users');
    } catch (e) {
      _addLog('❌ Error fetching users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWithDynamicDuration() async {
    setState(() => _isLoading = true);
    _addLog('🟡 Fetching posts with dynamic duration...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/posts',
        options: Options().setCachingWithDurationFn(
          enableCache: true,
          durationFn: () {
            final hour = DateTime.now().hour;
            final duration = hour >= 22 || hour < 6
                ? const Duration(hours: 2)
                : const Duration(minutes: 30);
            _addLog('   Dynamic duration: ${duration.inMinutes} minutes');
            return duration;
          },
        ),
      );
      stopwatch.stop();

      _addLog('✅ Posts fetched in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} posts');
    } catch (e) {
      _addLog('❌ Error fetching posts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWithStaticExpiry() async {
    setState(() => _isLoading = true);
    _addLog('🟣 Fetching comments with static expiry (1 hour)...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/comments?postId=1',
        options: Options().setCachingWithExpiry(
          enableCache: true,
          expiry: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      stopwatch.stop();

      _addLog('✅ Comments fetched in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} comments');
    } catch (e) {
      _addLog('❌ Error fetching comments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWithDynamicExpiry() async {
    setState(() => _isLoading = true);
    _addLog('🟠 Fetching albums with dynamic expiry...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/albums',
        options: Options().setCachingWithExpiryFn(
          enableCache: true,
          expiryFn: () {
            final expiry = DateTime.now().add(const Duration(hours: 2));
            _addLog('   Dynamic expiry: ${expiry.hour}:${expiry.minute}');
            return expiry;
          },
        ),
      );
      stopwatch.stop();

      _addLog('✅ Albums fetched in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} albums');
    } catch (e) {
      _addLog('❌ Error fetching albums: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWithForceRefresh() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Force refreshing users (invalidate cache)...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/users',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
          invalidateCache: true, // Force network request
        ),
      );
      stopwatch.stop();

      _addLog('✅ Users force refreshed in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} users');
    } catch (e) {
      _addLog('❌ Error force refreshing users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRequestDeduplication() async {
    setState(() => _isLoading = true);
    _addLog('🎯 Testing request deduplication...');

    try {
      // Make multiple identical requests simultaneously
      final futures = List.generate(
        5,
        (index) => widget.dio.get(
          '/posts/1',
          options: Options().setCachingWithDuration(
            enableCache: true,
            duration: const Duration(minutes: 5),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final responses = await Future.wait(futures);
      stopwatch.stop();

      _addLog(
        '✅ ${responses.length} requests completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      _addLog(
        '   All responses identical: ${responses.every((r) => r.data['id'] == 1)}',
      );
    } catch (e) {
      _addLog('❌ Error in deduplication test: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addRuntimeRule() async {
    _addLog('⚙️ Adding runtime caching rule for todos...');

    DioCachePlusInterceptor.addConditionalCaching(
      'todos_rule',
      ConditionalCacheRule.durationFn(
        condition: (request) =>
            request.method == 'GET' && request.url.contains('/todos'),
        durationFn: () {
          final isWeekend = DateTime.now().weekday >= 6;
          return isWeekend
              ? const Duration(hours: 4) // Longer cache on weekends
              : const Duration(hours: 1); // Shorter cache on weekdays
        },
      ),
    );

    _addLog('✅ Runtime rule added for todos');
  }

  Future<void> _fetchWithRuntimeRule() async {
    setState(() => _isLoading = true);
    _addLog('📝 Fetching todos using runtime rule...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await widget.dio.get(
        '/todos',
        options: Options().setCaching(
          enableCache: true,
        ), // Uses conditional rule
      );
      stopwatch.stop();

      _addLog('✅ Todos fetched in ${stopwatch.elapsedMilliseconds}ms');
      _addLog('   Data: ${response.data.length} todos');
    } catch (e) {
      _addLog('❌ Error fetching todos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllCache() async {
    _addLog('🧹 Clearing all cache...');
    await DioCachePlusInterceptor.clearAll();
    _addLog('✅ All cache cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dio Cache Plus Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAllCache,
            tooltip: 'Clear All Cache',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls Section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: [
                  _buildActionButton(
                    'Static Duration (10min)',
                    Colors.blue,
                    _fetchWithStaticDuration,
                    Icons.timer,
                  ),
                  _buildActionButton(
                    'Dynamic Duration',
                    Colors.orange,
                    _fetchWithDynamicDuration,
                    Icons.autorenew,
                  ),
                  _buildActionButton(
                    'Static Expiry (1hr)',
                    Colors.purple,
                    _fetchWithStaticExpiry,
                    Icons.schedule,
                  ),
                  _buildActionButton(
                    'Dynamic Expiry',
                    Colors.deepOrange,
                    _fetchWithDynamicExpiry,
                    Icons.update,
                  ),
                  _buildActionButton(
                    'Force Refresh',
                    Colors.red,
                    _fetchWithForceRefresh,
                    Icons.refresh,
                  ),
                  _buildActionButton(
                    'Test Deduplication',
                    Colors.green,
                    _testRequestDeduplication,
                    Icons.copy,
                  ),
                  _buildActionButton(
                    'Add Runtime Rule',
                    Colors.teal,
                    _addRuntimeRule,
                    Icons.add_circle,
                  ),
                  _buildActionButton(
                    'Use Runtime Rule',
                    Colors.indigo,
                    _fetchWithRuntimeRule,
                    Icons.rule,
                  ),
                ],
              ),
            ),
          ),

          // Logs Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: const Border(top: BorderSide(color: Colors.grey)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Text(
                          'Activity Logs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoading)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _logs.clear()),
                          child: const Text('Clear Logs'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No activity yet\nTap buttons above to test caching',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  log,
                                  style: const TextStyle(
                                    fontFamily: 'Monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    Color color,
    VoidCallback onPressed,
    IconData icon,
  ) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
