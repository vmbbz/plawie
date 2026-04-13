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
    final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);

    String? url;
    if (forceRefresh) {
      if (mounted) setState(() => _loading = true);
      url = await gatewayProvider.refreshDashboardUrl();
    } else {
      // Priority: widget arg → in-memory auth URL (has ?token=) → saved prefs → fresh CLI probe.
      // Only force-probe on the manual refresh button — probing on every open can
      // fail silently (PRoot busy, gateway mid-restart) and fall back to a tokenless URL.
      url = widget.url;
      if (url == null || url.isEmpty) {
        url = gatewayProvider.state.dashboardUrl;
      }
      if (url == null || url.isEmpty) {
        final prefs = PreferencesService();
        await prefs.init();
        url = prefs.dashboardUrl;
      }
      if (url == null || url.isEmpty) {
        url = await gatewayProvider.fetchAuthenticatedDashboardUrl();
      }
    }

    if (mounted) {
      // EFFICIENT: Use log-cached token first, only fallback if missing
      // Log parsing captures token instantly without PRoot overhead
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
      final cachedUrl = gatewayProvider.state.dashboardUrl;
      
      // Use cached URL from logs (fast) - no more PRoot calls
      final authenticatedUrl = url ?? cachedUrl;
      _controller.loadRequest(Uri.parse(authenticatedUrl ?? AppConstants.gatewayUrl));
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
