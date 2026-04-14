import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/gateway_provider.dart';
import '../services/preferences_service.dart';

class WebDashboardScreen extends StatefulWidget {
  final String? url;

  const WebDashboardScreen({super.key, this.url});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'Failed to load dashboard: ${error.description}';
              });
            }
          },
        ),
      );
    _loadUrl();
  }

  Future<void> _loadUrl({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
    String? url;

    if (forceRefresh) {
      // Manual refresh: always do a live CLI probe to get a fresh token.
      url = await gatewayProvider.refreshDashboardUrl();
    } else {
      // 1. Check widget argument first (passed by caller with a known-good URL).
      url = widget.url;

      // 2. Use in-memory state URL — only trust it if it already has a token.
      if ((url == null || url.isEmpty) &&
          gatewayProvider.state.dashboardUrl != null &&
          gatewayProvider.state.dashboardUrl!.contains('token=')) {
        url = gatewayProvider.state.dashboardUrl;
      }

      // 3. Check saved prefs — only if they contain a token, otherwise stale.
      if (url == null || url.isEmpty) {
        final prefs = PreferencesService();
        await prefs.init();
        final saved = prefs.dashboardUrl;
        if (saved != null && saved.contains('token=')) {
          url = saved;
        }
      }

      // 4. Instantly grab the token directly from local OpenClaw config files.
      // This is blazing fast (no PRoot overhead) and avoids the 1008 timeout loops.
      if (url == null || url.isEmpty || !url.contains('token=')) {
        final gatewayService = Provider.of<GatewayService>(context, listen: false);
        final token = await gatewayService.retrieveTokenFromConfig();
        if (token != null && token.isNotEmpty) {
          url = '${AppConstants.gatewayUrl}/?token=$token';
        }
      }
    }

    if (!mounted) return;

    if (url != null && url.contains('token=')) {
      _controller.loadRequest(Uri.parse(url));
    } else {
      // Last resort: load bare gateway URL — will show the token entry UI.
      _controller.loadRequest(Uri.parse(AppConstants.gatewayUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _loadUrl(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _error!.contains('401') || _error!.contains('403') 
                          ? Icons.lock_outline 
                          : Icons.wifi_off,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_error!.contains('401') || _error!.contains('403') || _error!.contains('Unauthorized'))
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loading = true;
                          });
                          _loadUrl(forceRefresh: true);
                        },
                        icon: const Icon(Icons.key),
                        label: const Text('Refresh Token & Retry'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loading = true;
                          });
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
