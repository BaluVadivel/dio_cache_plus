import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DioCachePlusDemoApp());
}

class DioCachePlusDemoApp extends StatelessWidget {
  const DioCachePlusDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dio Cache Plus Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CacheDemoScreen(),
    );
  }
}

class CacheDemoScreen extends StatefulWidget {
  const CacheDemoScreen({super.key});

  @override
  State<CacheDemoScreen> createState() => _CacheDemoScreenState();
}

class _CacheDemoScreenState extends State<CacheDemoScreen> {
  final Dio _dio = Dio(
    BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'),
  );
  final List<String> _logMessages = [];
  bool _isLoading = false;
  String _lastResponse = '';
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeDio();
    _addLog('App initialized');
  }

  void _initializeDio() {
    _dio.interceptors.add(
      DioCachePlusInterceptor(
        cacheAll: false,
        commonCacheDuration: const Duration(seconds: 30),
        isErrorResponse: (response) => response.statusCode != 200,
      ),
    );

    // Add conditional caching rule for /posts
    DioCachePlusInterceptor.addConditionalCaching(
      'posts_cache',
      (url, query) => url.contains('/posts'),
      const Duration(minutes: 1),
    );
    _addLog('Added conditional caching for /posts');
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toIso8601String()}: $message');
    });
  }

  Future<void> _makeRequest({
    required String endpoint,
    bool enableCache = false,
    Duration? duration,
    bool invalidateCache = false,
    bool overrideConditional = false,
  }) async {
    setState(() {
      _isLoading = true;
      _requestCount++;
    });

    try {
      final response = await _dio.get(
        endpoint,
        options: Options().setCaching(
          enableCache: enableCache,
          duration: duration,
          invalidateCache: invalidateCache,
          overrideConditionalCache: overrideConditional,
        ),
      );

      setState(() {
        _lastResponse = response.data.toString();
      });
      _addLog(
        'Request #$_requestCount to $endpoint completed (${enableCache ? 'CACHED' : 'FRESH'})',
      );
    } catch (e) {
      _addLog('Error in request: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDeduplication() async {
    setState(() {
      _isLoading = true;
    });

    final futures = List.generate(
      5,
      (i) => _dio.get(
        '/todos/1',
        options: Options().setCaching(enableCache: true),
      ),
    );

    try {
      final results = await Future.wait(futures);
      _addLog('Deduplication test completed (${results.length} responses)');
    } catch (e) {
      _addLog('Deduplication error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    await DioCachePlusInterceptor.clearAll();
    _addLog('Cache cleared!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dio Cache Plus Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCache,
            tooltip: 'Clear Cache',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Response Display
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _lastResponse.isEmpty ? 'No response yet' : _lastResponse,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ),

            // Log Display
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logMessages.reversed.toList()[index],
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Buttons
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Basic Caching
                ElevatedButton(
                  onPressed: () =>
                      _makeRequest(endpoint: '/todos/1', enableCache: true),
                  child: const Text('Basic Cached'),
                ),

                // Force Refresh
                ElevatedButton(
                  onPressed: () => _makeRequest(
                    endpoint: '/todos/2',
                    enableCache: true,
                    invalidateCache: true,
                  ),
                  child: const Text('Force Refresh'),
                ),

                // Conditional Cache
                ElevatedButton(
                  onPressed: () => _makeRequest(endpoint: '/posts/1'),
                  child: const Text('Conditional Cache'),
                ),

                // Disable Cache
                ElevatedButton(
                  onPressed: () =>
                      _makeRequest(endpoint: '/todos/3', enableCache: false),
                  child: const Text('Disable Cache'),
                ),

                // Override Conditional
                ElevatedButton(
                  onPressed: () => _makeRequest(
                    endpoint: '/posts/2',
                    enableCache: false,
                    overrideConditional: true,
                  ),
                  child: const Text('Override Conditional'),
                ),

                // Deduplication Test
                ElevatedButton(
                  onPressed: _testDeduplication,
                  child: const Text('Test Deduplication'),
                ),

                // Error Request
                ElevatedButton(
                  onPressed: () => _makeRequest(endpoint: '/nonexistent'),
                  child: const Text('Error Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
