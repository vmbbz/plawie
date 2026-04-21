import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clawa/app.dart';
import 'package:clawa/services/local_llm_service.dart';
import 'package:clawa/services/gateway_service.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/openclaw_service.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/models/gateway_state.dart';

/// Curated on-device Ollama library models, sorted smallest → largest.
/// Pulled from ollama.com/library; include proper chat templates.
const _kToolModels = [
  {'tag': 'smollm2:1.7b',          'label': 'SmolLM2 1.7B',          'size': '1.0 GB'},
  {'tag': 'deepseek-r1:1.5b',      'label': 'DeepSeek R1 1.5B',      'size': '1.1 GB'},
  {'tag': 'qwen2.5:0.5b',          'label': 'Qwen 2.5 0.5B',         'size': '394 MB'},
  {'tag': 'qwen2.5:1.5b',          'label': 'Qwen 2.5 1.5B',         'size': '986 MB'},
  {'tag': 'llama3.2:1b',           'label': 'Llama 3.2 1B',          'size': '1.3 GB'},
  {'tag': 'llama3.2:3b',           'label': 'Llama 3.2 3B',          'size': '2.0 GB'},
  {'tag': 'qwen2.5:3b',            'label': 'Qwen 2.5 3B',           'size': '1.9 GB'},
  {'tag': 'qwen2.5-coder:3b',      'label': 'Qwen 2.5 Coder 3B',     'size': '1.9 GB'},
  {'tag': 'phi4-mini:3.8b',        'label': 'Phi-4 Mini 3.8B',       'size': '2.5 GB'},
  {'tag': 'qwen2.5:7b',            'label': 'Qwen 2.5 7B',           'size': '4.7 GB'},
  {'tag': 'qwen2.5-coder:7b',      'label': 'Qwen 2.5 Coder 7B',     'size': '4.7 GB'},
  {'tag': 'llama3.1:8b',           'label': 'Llama 3.1 8B',          'size': '4.7 GB'},
  {'tag': 'deepseek-r1:7b',        'label': 'DeepSeek R1 7B',        'size': '4.7 GB'},
  {'tag': 'mistral:7b',            'label': 'Mistral 7B',            'size': '4.1 GB'},
  {'tag': 'qwen2.5:14b',           'label': 'Qwen 2.5 14B',          'size': '9.0 GB'},
  {'tag': 'phi4:14b',              'label': 'Phi-4 14B',             'size': '9.1 GB'},
  {'tag': 'llama3.2-vision:11b',   'label': 'Llama 3.2 Vision 11B',  'size': '8.1 GB'},
];

/// Ollama cloud models — run on ollama.com servers via the local Ollama daemon.
/// No download needed. Require `ollama signin` authentication.
/// Sources: ollama.com/blog/cloud-models + docs.ollama.com/integrations/openclaw
const _kCloudOllamaModels = [
  {'tag': 'qwen3-coder:480b-cloud',   'label': 'Qwen3 Coder 480B',   'category': 'Code',      'hasTools': 'true'},
  {'tag': 'gpt-oss:120b-cloud',       'label': 'GPT-OSS 120B',        'category': 'General',   'hasTools': 'true'},
  {'tag': 'gpt-oss:20b-cloud',        'label': 'GPT-OSS 20B',         'category': 'General',   'hasTools': 'false'},
  {'tag': 'deepseek-v3.1:671b-cloud', 'label': 'DeepSeek V3.1 671B', 'category': 'Reasoning', 'hasTools': 'false'},
  {'tag': 'kimi-k2.5:cloud',          'label': 'Kimi K2.5',          'category': 'General',   'hasTools': 'true'},
  {'tag': 'minimax-m2.7:cloud',       'label': 'MiniMax M2.7',       'category': 'General',   'hasTools': 'false'},
  {'tag': 'glm-5:cloud',              'label': 'GLM-5',              'category': 'General',   'hasTools': 'false'},
];

class LocalLlmScreen extends StatefulWidget {
  const LocalLlmScreen({super.key});

  @override
  State<LocalLlmScreen> createState() => _LocalLlmScreenState();
}

class _LocalLlmScreenState extends State<LocalLlmScreen> with WidgetsBindingObserver {
  final _service = LocalLlmService();
  LocalLlmState _state = const LocalLlmState();
  LocalLlmModel? _selectedModel;
  final Map<String, bool> _downloadedModels = {};
  GatewayState _gatewayState = const GatewayState();

  // Diagnostics state
  final _testPromptController = TextEditingController(text: 'Hello, what model are you? Tell me a brief joke.');
  final _testResponseNotifier = ValueNotifier<String>('');
  bool _isTesting = false;
  double _tokensPerSec = 0;
  DateTime? _testStartTime;
  int _tokenCount = 0;
  String _healthStatus = '';
  bool _isCheckingHealth = false;

  bool _isRegisteringOllama = false;

  // Ollama Integration State
  bool _isOllamaHealthy = false;
  bool _isCheckingOllama = false;
  List<Map<String, String>> _ollamaModels = [];
  String? _selectedOllamaModel;

  // Ollama cloud auth state
  bool _ollamaSignedIn = false;
  bool _isCheckingSignin = false;
  bool _isSigningIn = false; // true while _launchOllamaSignin() is running
  String? _pendingCloudModel; // tracks the model user tapped before sign-in
  String? _activeCloudModel; // tracks the currently-activated cloud model

  // Thread slider state
  int _cpuCoreCount = 8; // default; refined at initState from /proc/cpuinfo
  bool _threadsPendingApply = false; // true when slider moved but Ollama not recreated

  // Integrated Ollama State
  bool _isInternalOllamaInstalled = false;
  bool _isInstallingInternal = false;
  double _installProgress = 0;
  bool _isInternalOllamaRunning = false;
  bool _isTogglingOllama = false;
  
  // Model Sync/Pull State
  bool _isSyncingOllama = false;
  bool _isPullingOllama = false;
  double _ollamaPullProgress = 0;
  final _pullModelController = TextEditingController();

  StreamSubscription? _serviceSub;
  StreamSubscription? _gatewaySub;
  StreamSubscription<String>? _activitySub;
  StreamSubscription<String>? _ndkTestSub;
  StreamSubscription<String>? _ollamaTestSub;

  // Ollama Diagnostics
  final _ollamaTestPromptController = TextEditingController(text: 'Hello, what model are you? Tell me a brief joke.');
  String _ollamaTestResponse = '';
  bool _isOllamaTesting = false;

  // Live activity panel state
  final List<String> _activityLogs = [];
  final ScrollController _activityScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = _service.state;
    _serviceSub = _service.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    // React to gateway hub state so the Ollama model picker updates
    // automatically when sync completes (without needing a manual refresh).
    _gatewaySub = GatewayService().stateStream.listen((gwState) {
      if (mounted) {
        setState(() {
          _gatewayState = gwState;
        });
        if (gwState.ollamaHubModels.isNotEmpty) {
          _fetchOllamaModels();
        }
      }
    });
    // Live activity panel: seed from buffer so past events survive navigation,
    // then subscribe for future events.
    _activityLogs.addAll(GatewayService().recentActivity);
    _activitySub = GatewayService().chatActivityStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _activityLogs.add(event);
        if (_activityLogs.length > 40) _activityLogs.removeAt(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activityScrollController.hasClients) {
          _activityScrollController.animateTo(
            _activityScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
    _checkInternalStatus();
    _checkDownloadedModels();
    _checkOllamaStatus();
    _checkOllamaSignin();
    _readCpuCoreCount();
    // Default selection to the recommended model
    final toolCatalog = _service.catalog.where((m) => m.supportsToolCalls).toList();
    _selectedModel = toolCatalog.firstWhere(
      (m) => m.quality == 'Recommended',
      orElse: () => toolCatalog.first,
    );

    // Restore the user's Ollama model choice from prefs so it survives navigation.
    // Without this, _selectedOllamaModel starts as null and _fetchOllamaModels()
    // would always pick the first model in the list (the model-reset bug).
    final configured = PreferencesService().configuredModel;
    if (configured != null && configured.startsWith('ollama/')) {
      final modelTag = configured.replaceFirst('ollama/', '');
      if (modelTag.contains(':cloud')) {
        _activeCloudModel = modelTag;
      } else {
        _selectedOllamaModel = modelTag;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSub?.cancel();
    _gatewaySub?.cancel();
    _activitySub?.cancel();
    _ndkTestSub?.cancel();
    _ollamaTestSub?.cancel();
    _activityScrollController.dispose();
    _testPromptController.dispose();
    _pullModelController.dispose();
    _ollamaTestPromptController.dispose();
    _testResponseNotifier.dispose();
    // _ollamaTestResponse is a plain String — no dispose needed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check signin status when user returns from the browser OAuth flow.
    // We add a 1s delay because the ollama background process may take a 
    // moment to finish writing the ~/.ollama/credentials file.
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(seconds: 1), () => _checkOllamaSignin());
    }
  }

  Future<void> _checkInternalStatus() async {
    final installed = await GatewayService().isInternalOllamaInstalled();
    final running = await GatewayService().isInternalOllamaRunning();
    if (mounted) {
      setState(() {
        _isInternalOllamaInstalled = installed;
        _isInternalOllamaRunning = running;
      });
    }
  }

  Future<void> _installInternalOllama() async {
    setState(() {
      _isInstallingInternal = true;
      _installProgress = 0;
    });
    try {
      await GatewayService().installInternalOllama(
        onProgress: (p) => setState(() => _installProgress = p),
      );
      await _checkInternalStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Integrated Agent Hub ready!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installation failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isInstallingInternal = false);
    }
  }

  Future<void> _toggleInternalOllama() async {
    if (_isTogglingOllama) return;
    setState(() => _isTogglingOllama = true);
    
    try {
      if (_isInternalOllamaRunning) {
        await GatewayService().stopInternalOllama();
      } else {
        await GatewayService().startInternalOllama();
      }
      
      // Wait for process state to settle
      await Future.delayed(const Duration(milliseconds: 1500));
      await _checkInternalStatus();
      
      // Trigger a health check if it should be running
      if (_isInternalOllamaRunning) {
        await _checkOllamaStatus();
      } else {
        if (mounted) setState(() => _isOllamaHealthy = false);
      }
    } finally {
      if (mounted) setState(() => _isTogglingOllama = false);
    }
  }

  Future<void> _showOllamaLogsDialog() async {
    final logs = await GatewayService().getOllamaLogs();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text('Integrated Hub Logs', 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Text(
              logs,
              style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white30)),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logs));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
            child: const Text('COPY', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showOllamaLogsDialog();
            },
            child: const Text('REFRESH'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkOllamaStatus() async {
    if (_isCheckingOllama) return;
    setState(() => _isCheckingOllama = true);
    try {
      final healthy = await GatewayService().checkOllamaHealth();
      if (mounted) {
        setState(() {
          _isOllamaHealthy = healthy;
          _isCheckingOllama = false;
        });
        if (healthy) {
          _fetchOllamaModels();
          // If we had a cloud model waiting for the hub to start, activate it now.
          if (_pendingCloudModel != null) {
            final tag = _pendingCloudModel!;
            _pendingCloudModel = null;
            _selectCloudOllamaModel(tag);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingOllama = false);
    }
  }

  Future<void> _checkOllamaSignin() async {
    if (_isCheckingSignin) return;
    if (mounted) setState(() => _isCheckingSignin = true);
    try {
      // Use the consolidated auth check from GatewayService (credential file only).
      // This avoids running `ollama list` which fails when the hub is still starting.
      final signedIn = await GatewayService().checkOllamaCredentials();
      
      if (mounted) {
        setState(() => _ollamaSignedIn = signedIn);
        // If we just successfully signed in and had a model pending, activate it now.
        if (signedIn && _pendingCloudModel != null) {
          final modelToActivate = _pendingCloudModel!;
          _pendingCloudModel = null; // Clear first to avoid loops
          _selectCloudOllamaModel(modelToActivate);
        }
        // Also load the active cloud model from prefs if we're signed in.
        if (signedIn && _activeCloudModel == null) {
          final configured = PreferencesService().configuredModel;
          if (configured != null && configured.contains(':cloud')) {
            setState(() => _activeCloudModel = configured.replaceFirst('ollama/', ''));
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _ollamaSignedIn = false);
    } finally {
      if (mounted) setState(() => _isCheckingSignin = false);
    }
  }

  Future<void> _readCpuCoreCount() async {
    try {
      final result = await NativeBridge.runInProot(
        'grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "8"',
        timeout: 5,
      );
      final count = int.tryParse(result.trim()) ?? 8;
      if (mounted) setState(() => _cpuCoreCount = count.clamp(2, 12));
    } catch (_) {
      // Default 8 already set — no crash
    }
  }

  Future<void> _launchOllamaSignin() async {
    if (_isSigningIn) return;
    if (mounted) setState(() => _isSigningIn = true);
    try {
      // Step 1: Start ollama signin in background and capture the URL quickly.
      // Do NOT kill the process — it must stay alive to receive the OAuth callback
      // from the browser. We use a short read of the first output lines.
      final result = await NativeBridge.runInProot(
        // Redirect output to a temp file, then read first 10 lines
        // The process continues running in the background for OAuth callback
        'ollama signin > /tmp/oc_signin_out.txt 2>&1 & '
        'disown \$!; '
        'sleep 3; '
        'head -10 /tmp/oc_signin_out.txt',
        timeout: 15,
      );
      
      final urlMatch = RegExp(r'https://[^\s]+').firstMatch(result);
      if (urlMatch != null) {
        final uri = Uri.tryParse(urlMatch.group(0)!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(ClipboardData(text: urlMatch.group(0)!));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sign-in URL copied — paste it in your browser'),
              backgroundColor: Colors.amber,
            ));
          }
        }
      } else {
        // Didn't get URL — check if it's because we're already logged in
        if (result.contains('already logged in') || result.contains('Logged in as')) {
          _checkOllamaSignin(); // Re-probe to update UI state immediately
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Already logged in to Ollama Cloud!'),
              backgroundColor: Color(0xFF00C853),
            ));
          }
        } else {
          // Show raw output for debug
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                title: const Text('Ollama Sign-in', style: TextStyle(color: Colors.white, fontSize: 14)),
                content: SelectableText(
                  result.isNotEmpty ? result : 'No output received. Is Ollama Hub running?',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign-in failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _selectCloudOllamaModel(String tag) async {
    if (!_isInternalOllamaInstalled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please install the Agent Hub first.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      return;
    }

    if (!_ollamaSignedIn) {
      _pendingCloudModel = tag; // Store so we can auto-activate after sign-in
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.amber, size: 32),
              const SizedBox(height: 12),
              const Text(
                'Sign in to Ollama',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cloud models run on ollama.com servers — no download needed, but a free account is required.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _launchOllamaSignin();
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Sign in to Ollama'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // AUTO-START: If the hub is not running, start it for the user before activating.
    if (!_isOllamaHealthy) {
      _pendingCloudModel = tag;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting Agent Hub to activate $tag...'),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (!_isInternalOllamaRunning) {
        _toggleInternalOllama(); // This sets _isTogglingOllama and calls startInternalOllama()
      } else {
        // Hub is "running" (process exists) but not "healthy" (API down).
        // Trigger a fresh status probe which will then chain-activate the model.
        _checkOllamaStatus();
      }
      return;
    }

    setState(() => _isRegisteringOllama = true);
    try {
      // 1. Persist the full model path (ollama/tag) to gateway config AND prefs.
      final fullModel = tag.startsWith('ollama/') ? tag : 'ollama/$tag';
      await GatewayService().persistModel(fullModel);

      // 2. Also update the Ollama provider config block for gateway routing.
      final currentSynced = _ollamaModels.map((m) => m['id']!).toList();
      await GatewayService().configureOllama(
        primaryModel: tag,
        setAsPrimary: true,
        syncedModels: [...currentSynced, tag],
        isCloudModel: true,
      );

      // 3. Force the gateway WebSocket to reconnect with the new model.
      GatewayService().disconnectWebSocket();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('☁ Cloud model activated: $tag'),
            backgroundColor: const Color(0xFFAB47BC),
          ),
        );
        setState(() => _activeCloudModel = tag);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegisteringOllama = false);
    }
  }


  Future<void> _fetchOllamaModels() async {
    // Prefer the managed list from GatewayService (canonical names from our
    // GGUFs only) to avoid showing old-format stale registrations as duplicates.
    // Fall back to raw Ollama registry when sync hasn't run yet.
    // Cloud models (`:cloud` suffix) are handled separately — never shown here.
    final managed = GatewayService().state.ollamaHubModels;
    final List<Map<String, String>> models;
    if (managed.isNotEmpty) {
      models = managed
          .where((n) => !n.endsWith(':cloud'))
          .map((n) => <String, String>{'id': n, 'name': n.toUpperCase()})
          .toList();
    } else {
      models = (await OpenClawCommandService.getOllamaModels())
          .where((m) => !(m['id'] ?? '').endsWith(':cloud'))
          .toList();
    }
    if (mounted) {
      setState(() {
        _ollamaModels = models;
        if (_ollamaModels.isNotEmpty && _selectedOllamaModel == null) {
          // Try to restore the user's last-used model from prefs.
          final configured = PreferencesService().configuredModel;
          if (configured != null && configured.startsWith('ollama/')) {
            final modelTag = configured.replaceFirst('ollama/', '');
            final match = _ollamaModels.any((m) => m['id'] == modelTag);
            if (match && !modelTag.contains(':cloud')) {
              _selectedOllamaModel = modelTag;
              return;
            }
          }
          // Fallback: pick the first available model.
          _selectedOllamaModel = _ollamaModels.first['id'];
        }
      });
    }
  }

  Future<void> _registerOllamaAsDriver() async {
    if (_selectedOllamaModel == null) return;
    setState(() => _isRegisteringOllama = true);
    try {
      // Pass the current synced models so we don't wipe the models array in
      // openclaw.json — calling configureOllama without syncedModels writes [].
      final currentSynced = _ollamaModels.map((m) => m['id']!).toList();
      final fullModel = 'ollama/$_selectedOllamaModel';

      await GatewayService().configureOllama(
        primaryModel: _selectedOllamaModel,
        setAsPrimary: true,
        syncedModels: currentSynced,
      );
      // Persist and force WebSocket reconnect so the gateway picks up the change.
      await GatewayService().persistModel(fullModel);
      GatewayService().disconnectWebSocket();

      if (mounted) {
        setState(() => _activeCloudModel = null); // Clear cloud model — now using local
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ollama registered as Gateway Driver: $_selectedOllamaModel'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register Ollama: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegisteringOllama = false);
    }
  }
  Future<void> _handleOllamaSync() async {
    setState(() => _isSyncingOllama = true);
    try {
      await GatewayService().syncLocalModelsWithOllama();
      await _fetchOllamaModels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GGUF models synced to Ollama!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingOllama = false);
    }
  }

  Future<void> _handleOllamaPull() async {
    final modelName = _pullModelController.text.trim();
    if (modelName.isEmpty) return;

    setState(() {
      _isPullingOllama = true;
      _ollamaPullProgress = 0;
    });

    try {
      final stream = GatewayService().pullOllamaModel(modelName);
      await for (final progress in stream) {
        if (mounted) setState(() => _ollamaPullProgress = progress);
      }
      _pullModelController.clear();
      GatewayService().registerPulledModel(modelName);
      await _fetchOllamaModels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully pulled $modelName!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pull failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isPullingOllama = false);
    }
  }

  Future<void> _checkDownloadedModels() async {
    for (final m in _service.catalog) {
      final downloaded = await _service.isModelDownloaded(m);
      if (mounted) {
        setState(() => _downloadedModels[m.id] = downloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Ambient glow patches
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0097A7).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.15),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      _buildThreadSlider(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Model Library'),
                      const SizedBox(height: 12),
                      ..._service.catalog
                          .where((m) => m.supportsToolCalls)
                          .map(_buildModelCard),
                      const SizedBox(height: 16),
                      _buildModelInstructions(),
                      const SizedBox(height: 28),
                      _buildDeviceSpecCard(),
                      const SizedBox(height: 28),
                      _buildAgentPromptGuide(),
                      const SizedBox(height: 28),
                      _buildOllamaSection(),
                      const SizedBox(height: 28),
                      if (_isOllamaHealthy) ...[
                        _buildSectionLabel('Ollama Direct Diagnostics'),
                        const SizedBox(height: 12),
                        _buildOllamaDiagnosticsPanel(),
                        const SizedBox(height: 28),
                      ],
                      if (_state.status == LocalLlmStatus.ready) ...[
                        _buildSectionLabel('Diagnostics Playground'),
                        const SizedBox(height: 12),
                        _buildDiagnosticsPanel(),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Local LLM',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'BETA',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final (Color color, IconData icon, String label) = switch (_state.status) {
      LocalLlmStatus.ready => (AppColors.statusGreen, Icons.check_circle_rounded, 'Running'),
      LocalLlmStatus.starting => (Colors.amber, Icons.hourglass_top_rounded, 'Starting...'),
      LocalLlmStatus.downloading => (Colors.blueAccent, Icons.cloud_download_rounded, 'Downloading'),
      LocalLlmStatus.installing => (Colors.purpleAccent, Icons.memory_rounded, 'Activating...'),
      LocalLlmStatus.error => (Colors.redAccent, Icons.error_rounded, 'Error'),
      LocalLlmStatus.idle => (Colors.white30, Icons.circle_outlined, 'Offline'),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                'NDK Direct Mode  ·  fllama',
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_state.status == LocalLlmStatus.ready &&
              _state.activeModelId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Model: ${_state.activeModelId}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (_state.status == LocalLlmStatus.downloading ||
              _state.status == LocalLlmStatus.installing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _state.downloadProgress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            if (_state.errorMessage != null)
              Text(
                _state.errorMessage!,
                style: TextStyle(color: color, fontSize: 11),
                textAlign: TextAlign.center,
              )
            else
              Text(
                '${(_state.downloadProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 11),
              ),
          ],
          if (_state.status == LocalLlmStatus.error &&
              _state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _state.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _service.stop();
              }),
              icon: const Icon(Icons.refresh, size: 14, color: Colors.white54),
              label: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThreadSlider() {
    final int threads = _state.threads;
    final bool isInferring = _service.isInferring;
    final bool hasOllamaModels = _ollamaModels.isNotEmpty;
    final bool aboveCoreCount = threads > _cpuCoreCount;
    final int sliderMax = _cpuCoreCount;
    // Clamp display value to slider max to avoid assertion error
    final double sliderValue = threads.toDouble().clamp(1.0, sliderMax.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CPU Threads',
              style: GoogleFonts.outfit(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                if (isInferring)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock_outline, color: Colors.white38, size: 13),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: aboveCoreCount
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: aboveCoreCount
                        ? Border.all(color: Colors.amber.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Text(
                    '$threads / $_cpuCoreCount cores',
                    style: TextStyle(
                      color: aboveCoreCount ? Colors.amber : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Slider — disabled during inference
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isInferring
                ? Colors.white24
                : (aboveCoreCount ? Colors.amber : AppColors.statusGreen),
            inactiveTrackColor: Colors.white12,
            thumbColor: isInferring
                ? Colors.white24
                : (aboveCoreCount ? Colors.amber : AppColors.statusGreen),
            overlayColor: isInferring
                ? Colors.transparent
                : AppColors.statusGreen.withValues(alpha: 0.15),
            disabledActiveTrackColor: Colors.white24,
            disabledThumbColor: Colors.white24,
          ),
          child: Slider(
            min: 1,
            max: sliderMax.toDouble(),
            divisions: sliderMax - 1,
            value: sliderValue,
            onChanged: isInferring
                ? null
                : (v) {
                    final newThreads = v.toInt();
                    _service.setThreads(newThreads, currentModel: _selectedModel);
                    if (hasOllamaModels) {
                      setState(() => _threadsPendingApply = true);
                    }
                  },
          ),
        ),
        // Inference lock notice
        if (isInferring)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Slider locked — model is generating. Changes take effect after the current response.',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        // Above-core-count warning
        if (aboveCoreCount && !isInferring)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Thread count exceeds detected core count ($_cpuCoreCount). '
                    'This can slow inference — the OS must context-switch across fewer real cores.',
                    style: const TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        // Ollama recreate banner
        if (_threadsPendingApply && hasOllamaModels && !isInferring)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thread count is baked into the Ollama Modelfile. '
                    'Tap Recreate to apply to Ollama models.',
                    style: TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSyncingOllama
                      ? null
                      : () async {
                          await _handleOllamaSync();
                          if (mounted) setState(() => _threadsPendingApply = false);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    ),
                    child: _isSyncingOllama
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.amber,
                            ),
                          )
                        : const Text(
                            'Recreate',
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        // Guidance text — split by inference path
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.white30, size: 11),
                const SizedBox(width: 3),
                const Expanded(
                  child: Text(
                    'fllama: Takes effect immediately on the next message.',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.memory, color: Colors.white30, size: 11),
                const SizedBox(width: 3),
                const Expanded(
                  child: Text(
                    'Ollama: Baked into the Modelfile at create time — use Recreate to apply.',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
              ],
            ),
            if (threads == 1)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Tip: 1 thread focuses on the highest-frequency performance core — fastest on many phones.',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: AppColors.statusGreen.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildModelCard(LocalLlmModel model) {
    final isDownloaded = _downloadedModels[model.id] ?? false;
    final isSelected = _selectedModel?.id == model.id;
    final isActive = _state.activeModelId == model.id;
    final isDownloading = _state.status == LocalLlmStatus.downloading &&
        isSelected &&
        !isDownloaded;

    final qualityColor = switch (model.quality) {
      'Minimum' => Colors.amber,
      'Recommended' => AppColors.statusGreen,
      'Optimal' => Colors.purpleAccent,
      _ => Colors.white54,
    };

    return GestureDetector(
      onTap: () => setState(() => _selectedModel = model),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? AppColors.statusGreen.withValues(alpha: 0.5)
                : isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.statusGreen)),
                        const SizedBox(width: 4),
                        Text('RUNNING', style: TextStyle(color: AppColors.statusGreen, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      model.quality,
                      style: TextStyle(color: qualityColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              model.description,
              style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _specChip('${model.fileSizeMb} MB download'),
                const SizedBox(width: 6),
                _specChip('${(model.requiredRamMb / 1024).toStringAsFixed(1)} GB RAM'),
                const SizedBox(width: 6),
                _specChip('${model.contextWindow ~/ 1024}K ctx'),
                const Spacer(),
                if (isDownloading)
                  SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      value: _state.downloadProgress,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.blueAccent),
                      minHeight: 4,
                    ),
                  )
                else
                  _buildActionButton(model, isDownloaded, isActive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
    );
  }

  Widget _buildActionButton(LocalLlmModel model, bool isDownloaded, bool isActive) {
    final anotherModelRunning = _state.activeModelId != null && !isActive;
    final isStartingThis = _state.status == LocalLlmStatus.starting && _selectedModel?.id == model.id;

    // Active model → Stop
    if (isActive) {
      return TextButton.icon(
        onPressed: _service.stop,
        icon: const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent),
        label: const Text('Stop', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Starting spinner
    if (isStartingThis) {
      return TextButton.icon(
        onPressed: null,
        icon: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
        label: const Text('Starting...', style: TextStyle(color: Colors.amber, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: Colors.amber.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Downloaded → Start or Switch
    if (isDownloaded) {
      final isSwitch = anotherModelRunning;
      return TextButton.icon(
        onPressed: _state.status == LocalLlmStatus.starting
            ? null
            : () {
                setState(() => _selectedModel = model);
                _service.startWithModel(model);
              },
        icon: Icon(isSwitch ? Icons.swap_horiz_rounded : Icons.play_arrow_rounded,
            size: 14, color: isSwitch ? Colors.amber : AppColors.statusGreen),
        label: Text(
          isSwitch ? 'Switch' : 'Start',
          style: TextStyle(color: isSwitch ? Colors.amber : AppColors.statusGreen, fontSize: 11),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: (isSwitch ? Colors.amber : AppColors.statusGreen).withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Not downloaded → Download
    return TextButton.icon(
      onPressed: _state.status == LocalLlmStatus.idle || _state.status == LocalLlmStatus.error
          ? () {
              setState(() => _selectedModel = model);
              _service.downloadAndStart(model);
            }
          : null,
      icon: const Icon(Icons.cloud_download_rounded, size: 14, color: Colors.blueAccent),
      label: const Text('Download', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDeviceSpecCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                'Device Requirements',
                style: GoogleFonts.outfit(
                    color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _specRow('Minimum', '8 GB RAM · Snapdragon 8 Gen 1 · ~4–8 tok/s'),
          _specRow('Recommended', '12 GB RAM · 8 Gen 2 · ~10–18 tok/s'),
          _specRow('Optimal', '16 GB RAM · 8 Gen 3 / Elite · ~20–30 tok/s'),
          const SizedBox(height: 8),
          const Text(
            'Inference uses CPU only — GPU acceleration inside PRoot is not stable. '
            'Expect 30–50% battery drain during active inference. '
            'Models are stored inside the PRoot filesystem and survive app updates.',
            style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'About VRAM vs RAM on phones',
              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            iconColor: Colors.amber,
            collapsedIconColor: Colors.white38,
            children: const [
              Text(
                'Android phones have NO discrete VRAM. '
                'The Adreno (Qualcomm), Mali, and Immortalis GPUs all share the same LPDDR5X '
                'system RAM pool with the CPU — there is no separate GPU memory.\n\n'
                'Desktop model cards that list "8 GB VRAM" refer to high-bandwidth GDDR6 VRAM '
                'on a discrete GPU. On mobile, the same model uses system RAM instead, '
                'which is slower — that\'s why 7B models run at 4–8 tok/s here vs 50+ tok/s '
                'on a desktop GPU.\n\n'
                'The "Required RAM" figures in each model card below already account for this: '
                'they are the total system RAM (model weights + KV cache + Android OS overhead) '
                'needed for stable inference on CPU. No VRAM is needed or used.',
                style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specRow(String tier, String spec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(tier,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(spec,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 15),
            const SizedBox(width: 8),
            Text('How to use local models',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          _instructionStep('1  Download', 'Tap Download on the model card above to save it to your device (~1–2 GB).'),
          const SizedBox(height: 6),
          _instructionStep('2  Start (NDK)', 'Tap Start to load the model via the on-device NDK engine (fllama). Select it in the chat model picker for private, offline chat — no internet needed.'),
          const SizedBox(height: 6),
          _instructionStep('3  Agent Hub', 'For full tool-use, skills, and multi-step tasks: start the Integrated Agent Hub below and pick an ollama/ model in chat. This routes through the gateway agent loop.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NDK mode = direct private chat only. No tools, skills, or agent features. For the full OpenClaw experience use the Integrated Agent Hub.',
                  style: const TextStyle(color: Colors.amber, fontSize: 10, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildAgentPromptGuide() {
    const prompt =
        'fllama (NDK) system prompt hint — paste into your custom agent system prompt '
        'when using the NDK direct-chat mode:\n\n'
        'You are running via fllama (llama.cpp NDK, on-device). Context window is '
        'limited — keep responses focused. No tool calls are available in this mode. '
        'For multi-step tasks or tool use, ask the user to switch to the Integrated '
        'Agent Hub (ollama/ model) in chat settings.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                'NDK Direct Mode — Prompt Hint',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            prompt,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white54,
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('AGENT HUB'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _activeCloudModel != null
                  ? const Color(0xFFAB47BC).withValues(alpha: 0.3)
                  : _isOllamaHealthy
                      ? AppColors.statusGreen.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _activeCloudModel != null
                        ? Icons.cloud_queue_rounded
                        : _isInternalOllamaInstalled ? Icons.settings_input_component : Icons.auto_awesome,
                    color: _activeCloudModel != null
                        ? const Color(0xFFAB47BC)
                        : _isInternalOllamaInstalled ? AppColors.statusGreen : Colors.amber,
                    size: 20
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeCloudModel != null
                              ? '☁ ${_activeCloudModel!.replaceAll(':cloud', '').toUpperCase()}'
                              : 'Agent Hub',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _activeCloudModel != null
                            ? 'Cloud Model Active — via Ollama Hub'
                            : _isInternalOllamaInstalled 
                              ? (_isInternalOllamaRunning
                                  ? (_selectedOllamaModel != null
                                      ? 'Active · $_selectedOllamaModel'
                                      : 'Service Active')
                                  : 'Service Standby')
                              : 'Enable offline AI — no internet required',
                          style: TextStyle(
                            color: _activeCloudModel != null
                                ? const Color(0xFFAB47BC)
                                : _isInternalOllamaRunning ? AppColors.statusGreen : Colors.white38,
                            fontSize: 11
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isInternalOllamaInstalled) 
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.wysiwyg_rounded, color: Colors.white24, size: 18),
                        onPressed: _showOllamaLogsDialog,
                        tooltip: 'View Hub Logs',
                      ),
                    ),
                  _buildOllamaStatusBadge(),
                ],
              ),
              const SizedBox(height: 18),
              if (!_isInternalOllamaInstalled) ...[
                if (_isInstallingInternal) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _installProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Downloading Runtime: ${(_installProgress * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.jetBrainsMono(color: Colors.amber, fontSize: 10),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Enables Plawie to use a powerful local inference engine (Ollama) for reasoning and tools. No external apps required.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _installInternalOllama,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.1),
                      foregroundColor: Colors.amber,
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: Text('Initialize Local LLM Hub', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildOllamaModelDropdown(),
                    ),
                    const SizedBox(width: 12),
                    _buildOllamaActionButton(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGatewayHealthCard(),
                const SizedBox(height: 16),
                _buildActivityPanel(),
                const SizedBox(height: 16),

                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                
                // Sync Action
                _buildModelActionRow(
                  icon: Icons.sync_rounded,
                  title: 'Sync Installed GGUFs',
                  subtitle: 'Register local files with Ollama',
                  trailing: _isSyncingOllama
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: _handleOllamaSync,
                        child: const Text('SYNC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ),
                ),
                
                const SizedBox(height: 8),
                
                // Pull Action
                _buildModelActionRow(
                  icon: Icons.download_for_offline_rounded,
                  title: 'Pull from Library',
                  subtitle: 'Download tags (e.g. phi3)',
                  trailing: _isPullingOllama
                    ? SizedBox(
                        width: 40,
                        child: Center(
                          child: Text('${(_ollamaPullProgress * 100).toInt()}%', 
                            style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                        )
                      )
                    : IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                        onPressed: _showPullDialog,
                      ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isOllamaHealthy && !_isRegisteringOllama) 
                      ? _registerOllamaAsDriver 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOllamaHealthy ? AppColors.statusGreen.withValues(alpha: 0.1) : Colors.white12,
                      foregroundColor: _isOllamaHealthy ? AppColors.statusGreen : Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: _isRegisteringOllama
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Set as Primary Gateway Driver', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityPanel() {
    return Container(
      height: 130,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_rounded, color: Colors.white30, size: 12),
              const SizedBox(width: 6),
              Text(
                'LIVE ACTIVITY',
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _activityLogs.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for activity...',
                      style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10),
                    ),
                  )
                : ListView.builder(
                    controller: _activityScrollController,
                    itemCount: _activityLogs.length,
                    itemBuilder: (ctx, i) {
                      final entry = _activityLogs[i];
                      final Color entryColor = entry.contains('✗') || entry.contains('⚠')
                          ? Colors.redAccent
                          : entry.contains('✓')
                              ? Colors.greenAccent
                              : Colors.white54;
                      return Text(
                        entry,
                        style: GoogleFonts.jetBrainsMono(color: entryColor, fontSize: 10),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGatewayHealthCard() {
    final isConnected = _gatewayState.isWebsocketConnected;
    final uptime = _gatewayState.startedAt != null 
        ? DateTime.now().difference(_gatewayState.startedAt!)
        : null;
    
    final healthData = _gatewayState.detailedHealth;
    final ok = healthData?['ok'] ?? isConnected;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isConnected ? AppColors.statusGreen : Colors.amber).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.lan_rounded : Icons.lan_outlined,
              color: isConnected ? AppColors.statusGreen : Colors.amber,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Connected' : 'Connecting...',
                  style: GoogleFonts.outfit(
                    color: isConnected ? AppColors.statusGreen : Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  uptime != null
                    ? '${uptime.inMinutes}m ${uptime.inSeconds % 60}s uptime'
                    : 'Standby',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
          ),
          if (ok == true)
            const Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 14),
        ],
      ),
    );
  }

  Widget _buildOllamaStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (_isOllamaHealthy ? AppColors.statusGreen : Colors.redAccent).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (_isOllamaHealthy ? AppColors.statusGreen : Colors.redAccent).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOllamaHealthy ? AppColors.statusGreen : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOllamaHealthy ? 'ONLINE' : 'OFFLINE',
            style: GoogleFonts.outfit(
              color: _isOllamaHealthy ? AppColors.statusGreen : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the catalog entry for an Ollama model name, or null.
  LocalLlmModel? _catalogEntryFor(String ollamaId) {
    final catalog = LocalLlmService().catalog;
    try {
      // ollamaId format: "qwen2.5-1.5b-instruct:q4_k_m"
      // catalog id:      "qwen2.5-1.5b-instruct-q4_k_m"
      // Match by stripping all punctuation and comparing lowercase.
      final stripped = ollamaId.replaceAll(RegExp(r'[.\-_:]'), '').toLowerCase();
      return catalog.firstWhere(
        (m) => m.id.replaceAll(RegExp(r'[.\-_:]'), '').toLowerCase() == stripped,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildOllamaModelDropdown() {
    // Only show tool-capable models as gateway driver candidates.
    // Chat-only models are not suitable as the primary model because the
    // gateway always sends tool schemas which would cause HTTP 400.
    final toolModels = _ollamaModels.where((m) {
      final entry = _catalogEntryFor(m['id']!);
      return entry?.supportsToolCalls ?? false;
    }).toList();

    // If no tool-capable models are synced yet, show all with a warning.
    final displayModels = toolModels.isNotEmpty ? toolModels : _ollamaModels;
    final showNoToolsWarning = toolModels.isEmpty && _ollamaModels.isNotEmpty;

    // Ensure selected model stays valid after filtering.
    final validValue = displayModels.any((m) => m['id'] == _selectedOllamaModel)
        ? _selectedOllamaModel
        : (displayModels.isNotEmpty ? displayModels.first['id'] : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNoToolsWarning) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.statusAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.statusAmber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No tool-capable models synced. Download Qwen 2.5 1.5B or 3B for full gateway features.',
                    style: TextStyle(fontSize: 11, color: AppColors.statusAmber),
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              dropdownColor: const Color(0xFF1E1E2E),
              isExpanded: true,
              hint: const Text('No models found', style: TextStyle(color: Colors.white24, fontSize: 12)),
              items: displayModels.map((m) {
                final entry = _catalogEntryFor(m['id']!);
                final hasTools = entry?.supportsToolCalls ?? false;
                return DropdownMenuItem<String>(
                  value: m['id'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m['name'] ?? m['id']!,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasTools
                              ? AppColors.statusGreen.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: hasTools
                                ? AppColors.statusGreen.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          hasTools ? 'TOOLS' : 'CHAT',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: hasTools ? AppColors.statusGreen : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedOllamaModel = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOllamaActionButton() {
    return ElevatedButton(
      onPressed: _isInternalOllamaInstalled ? _toggleInternalOllama : _checkOllamaStatus,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(80, 45),
        padding: EdgeInsets.zero,
      ),
      child: _isTogglingOllama
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
          : Icon(
              _isInternalOllamaInstalled 
                ? (_isInternalOllamaRunning ? Icons.stop_rounded : Icons.play_arrow_rounded)
                : Icons.refresh_rounded,
              size: 20,
            ),
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.query_stats_rounded, color: AppColors.statusGreen, size: 18),
              const SizedBox(width: 10),
              Text(
                'Test Inference',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isTesting)
                Text(
                  '${_tokensPerSec.toStringAsFixed(1)} tok/s',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.statusGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Endpoint: http://127.0.0.1:8081',
                style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 9),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isCheckingHealth ? null : _checkHealth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isCheckingHealth
                      ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38))
                      : Text('Engine Status', style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                ),
              ),
            ],
          ),
          if (_healthStatus.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _healthStatus,
              style: GoogleFonts.jetBrainsMono(
                color: _healthStatus.contains('healthy') ? AppColors.statusGreen : Colors.redAccent,
                fontSize: 9,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _testPromptController,
            maxLines: 3,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter test prompt...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isTesting ? null : _runTestInference,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen.withValues(alpha: 0.1),
              foregroundColor: AppColors.statusGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: _isTesting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.statusGreen))
              : const Text('Execute Test', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _testResponseNotifier,
            builder: (context, response, _) {
              if (response.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      response,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkHealth() async {
    setState(() { _isCheckingHealth = true; _healthStatus = ''; });
    final bool healthy = _service.state.status == LocalLlmStatus.ready;
    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _healthStatus = healthy ? 'Engine is healthy' : 'Engine is offline';
      });
    }
  }

  Future<void> _runTestInference() async {
    _ndkTestSub?.cancel();
    _testResponseNotifier.value = '';
    setState(() {
      _isTesting = true;
      _tokensPerSec = 0;
      _tokenCount = 0;
      _testStartTime = DateTime.now();
    });

    _ndkTestSub = _service.testInference(_testPromptController.text).listen(
      (token) {
        _testResponseNotifier.value += token;
        _tokenCount++;
        final duration = DateTime.now().difference(_testStartTime!).inMilliseconds / 1000;
        if (duration > 0 && mounted) {
          setState(() => _tokensPerSec = _tokenCount / duration);
        }
      },
      onDone: () {
        if (mounted) setState(() => _isTesting = false);
      },
      onError: (e) {
        _testResponseNotifier.value = 'Error: $e';
        if (mounted) setState(() => _isTesting = false);
      },
      cancelOnError: true,
    );
  }

  Future<void> _runOllamaTestInference() async {
    _ollamaTestSub?.cancel();
    if (_selectedOllamaModel == null) return;
    setState(() {
      _isOllamaTesting = true;
      _ollamaTestResponse = '';
    });
    try {
      final stream = GatewayService().sendMessageHttp(
        _ollamaTestPromptController.text,
        model: _selectedOllamaModel!,
        directUrl: 'http://127.0.0.1:11434/v1/chat/completions',
        ollamaOptions: {'num_ctx': 2048},
      );
      await for (final token in stream) {
        if (!mounted) break;
        setState(() => _ollamaTestResponse += token);
      }
    } catch (e) {
      if (mounted) setState(() => _ollamaTestResponse = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isOllamaTesting = false);
    }
  }

  Widget _buildOllamaDiagnosticsPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 10),
              Text(
                'Direct HTTP Test (No Gateway)',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Endpoint: http://127.0.0.1:11434/v1/chat/completions\nThis tests the background Ollama process directly.',
            style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 9),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ollamaTestPromptController,
            maxLines: 2,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isOllamaTesting ? null : _runOllamaTestInference,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
              foregroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: _isOllamaTesting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
              : const Text('Execute Test', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (_ollamaTestResponse.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _ollamaTestResponse,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModelActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.white30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  void _showPullDialog() {
    String? selected;
    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add Model',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 12),
                  TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    indicatorColor: AppColors.statusGreen,
                    labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(icon: Icon(Icons.cloud_queue_rounded, size: 16), text: 'Cloud'),
                      Tab(icon: Icon(Icons.phone_android, size: 16), text: 'On-Device'),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: TabBarView(
                  children: [
                    // ── Tab 0: Cloud models ──────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // What is Ollama Cloud? (Premium Card)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFAB47BC).withValues(alpha: 0.15),
                                  const Color(0xFFAB47BC).withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFAB47BC).withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cloud_queue_rounded, color: Color(0xFFAB47BC), size: 18),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Ollama Cloud',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFAB47BC),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFAB47BC).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('FREE', style: TextStyle(color: Color(0xFFAB47BC), fontSize: 8, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Run massive models like Qwen 480B or Llama 405B without downloading anything. All you need is a free ollama.com account.',
                                  style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Auth status card — tappable when not signed in
                          GestureDetector(
                            onTap: _ollamaSignedIn ? null : _launchOllamaSignin,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: (_ollamaSignedIn
                                        ? AppColors.statusGreen
                                        : Colors.amber)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (_ollamaSignedIn
                                          ? AppColors.statusGreen
                                          : Colors.amber)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _isCheckingSignin
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: _ollamaSignedIn
                                                ? AppColors.statusGreen
                                                : Colors.amber,
                                          ),
                                        )
                                      : Icon(
                                          _ollamaSignedIn
                                              ? Icons.verified_rounded
                                              : Icons.lock_outline,
                                          color: _ollamaSignedIn
                                              ? AppColors.statusGreen
                                              : Colors.amber,
                                          size: 15,
                                        ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _ollamaSignedIn
                                          ? 'Signed in to ollama.com — cloud models available'
                                          : 'Not signed in — tap to connect',
                                      style: TextStyle(
                                        color: _ollamaSignedIn
                                            ? AppColors.statusGreen
                                            : Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // Signin button (not signed in)
                                  if (!_ollamaSignedIn)
                                    _isSigningIn
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Colors.amber,
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: Colors.amber.withValues(alpha: 0.5)),
                                            ),
                                            child: const Text('SIGN IN',
                                                style: TextStyle(
                                                    color: Colors.amber,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800)),
                                          ),
                                  // Refresh button (always shown)
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: _isCheckingSignin ? null : _checkOllamaSignin,
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: _ollamaSignedIn
                                          ? AppColors.statusGreen.withValues(alpha: 0.7)
                                          : Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('AVAILABLE CLOUD MODELS',
                              style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ..._kCloudOllamaModels.map((m) {
                            final hasTools = m['hasTools'] == 'true';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cloud_queue_rounded, color: Color(0xFFAB47BC), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m['label']!,
                                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                          Row(children: [
                                            Text(m['category']!,
                                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: hasTools
                                                    ? AppColors.statusGreen.withValues(alpha: 0.12)
                                                    : Colors.white.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                hasTools ? 'TOOLS' : 'CHAT',
                                                style: TextStyle(
                                                  color: hasTools ? AppColors.statusGreen : Colors.white30,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _ollamaSignedIn
                                          ? () => _selectCloudOllamaModel(m['tag']!)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFAB47BC).withValues(alpha: 0.15),
                                        foregroundColor: const Color(0xFFAB47BC),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('USE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ── Tab 1: On-Device models ──────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Curated models ───────────────────────────
                          const Text('CURATED MODELS',
                              style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _kToolModels.map((m) {
                              final isSel = selected == m['tag'];
                              return GestureDetector(
                                onTap: () {
                                  setS(() => selected = m['tag']);
                                  _pullModelController.text = m['tag']!;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.statusGreen.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSel ? AppColors.statusGreen : Colors.white12,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(m['label']!,
                                          style: TextStyle(
                                              color: isSel ? AppColors.statusGreen : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      Text(m['size']!,
                                          style: const TextStyle(color: Colors.white38, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),
                          Row(children: [
                            const Expanded(child: Divider(color: Colors.white12)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('OR SEARCH',
                                  style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
                            ),
                            const Expanded(child: Divider(color: Colors.white12)),
                          ]),
                          const SizedBox(height: 10),

                          // ── Search row ───────────────────────────────
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: searchCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Search ollama.com...',
                                  hintStyle: TextStyle(color: Colors.white24),
                                  isDense: true,
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                                ),
                                onSubmitted: (_) async {
                                  final q = searchCtrl.text.trim();
                                  if (q.isEmpty) return;
                                  setS(() => searching = true);
                                  final r = await GatewayService().fetchOllamaRegistryModels(q);
                                  setS(() { searchResults = r; searching = false; });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            searching
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.statusGreen))
                                : IconButton(
                                    icon: const Icon(Icons.search, color: Colors.white38, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final q = searchCtrl.text.trim();
                                      if (q.isEmpty) return;
                                      setS(() => searching = true);
                                      final r = await GatewayService().fetchOllamaRegistryModels(q);
                                      setS(() { searchResults = r; searching = false; });
                                    },
                                  ),
                          ]),

                          if (searchResults.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 130,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: searchResults.length,
                                itemBuilder: (_, i) {
                                  final r = searchResults[i];
                                  final tag = r['name'] as String? ?? '';
                                  final isSel = selected == tag;
                                  return InkWell(
                                    onTap: () {
                                      setS(() => selected = tag);
                                      _pullModelController.text = tag;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      color: isSel ? AppColors.statusGreen.withValues(alpha: 0.08) : Colors.transparent,
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(tag,
                                              style: TextStyle(
                                                  color: isSel ? AppColors.statusGreen : Colors.white70,
                                                  fontSize: 12)),
                                        ),
                                        if (r['pulls'] != null)
                                          Text('${(r['pulls'] as num) ~/ 1000}K↓',
                                              style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          // ── Model tag input ──────────────────────────
                          TextField(
                            controller: _pullModelController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Model tag to pull',
                              labelStyle: TextStyle(color: Colors.white38),
                              hintText: 'e.g. qwen2.5:1.5b',
                              hintStyle: TextStyle(color: Colors.white24),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white30)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleOllamaPull();
                  },
                  child: const Text('PULL', style: TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
