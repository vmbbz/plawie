import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_key_detection_service.dart';
import 'dashboard_screen.dart';

/// Professional Onboarding Screen with proper formatting and UX
class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeInAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  
  final ApiKeyDetectionService _apiService = ApiKeyDetectionService();
  bool _loading = true;
  String? _error;
  String _helpText = '';
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadOnboardingContent();
    _animationController.forward();
    _slideController.forward();
  }

  Future<void> _loadOnboardingContent() async {
    try {
      setState(() => _loading = true);
      
      // Load comprehensive onboarding content
      final content = await _getOnboardingContent();
      setState(() {
        _helpText = content;
        _loading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load onboarding: $e';
      });
    }
  }

  Future<String> _getOnboardingContent() async {
    return '''
# 🚀 OpenClaw Onboarding Guide

Welcome to **OpenClaw** - Your Advanced AI Agent Platform!

---

## 📋 **Quick Start Checklist**

### ✅ **Step 1: API Keys Configuration**
Configure at least one AI provider to start using OpenClaw:

#### 🤖 **Claude API (Recommended)**
```bash
openclaw onboard --claude-api-key "sk-ant-your-key-here"
```

#### ⚡ **Groq API (Fast & Affordable)**
```bash
openclaw onboard --groq-api-key "gsk_your-key-here"
```

#### 🌐 **OpenRouter API (Multiple Models)**
```bash
openclaw onboard --openrouter-api-key "sk-or-your-key-here"
```

### ✅ **Step 2: Gateway Configuration**
```bash
openclaw onboard --binding 0.0.0.0  # Allow external connections
openclaw onboard --port 8080         # Custom port (default: 8080)
```

### ✅ **Step 3: Solana Wallet Setup**
```bash
openclaw onboard --solana-rpc "https://api.mainnet-beta.solana.com"
openclaw onboard --jupiter-api-key "your-jupiter-key"
```

---

## 🔧 **Advanced Configuration**

### 📱 **Mobile Bridge Setup**
```bash
openclaw onboard --android-bridge  # Enable Android features
openclaw onboard --device-tools    # Enable device integration
```

### 🧠 **Memory & Skills**
```bash
openclaw onboard --memory-size 1GB    # Memory database size
openclaw onboard --skills-path "./skills"  # Custom skills directory
```

### ⏰ **Scheduling System**
```bash
openclaw onboard --scheduler-enabled  # Enable cron scheduling
openclaw onboard --timezone "UTC"     # Set timezone
```

---

## 🔐 **Security Best Practices**

### 🛡️ **API Key Security**
- Store keys in secure environment variables
- Use separate keys for development/production
- Rotate keys regularly for security
- Never commit keys to version control

### 🔒 **Network Security**
```bash
openclaw onboard --tls-enabled      # Enable HTTPS
openclaw onboard --cors-allowed "*" # Configure CORS
openclaw onboard --rate-limit 100   # Rate limiting
```

---

## 📊 **Monitoring & Debugging**

### 📈 **System Monitoring**
```bash
openclaw onboard --metrics-enabled  # Enable metrics
openclaw onboard --log-level info   # Set logging level
openclaw onboard --health-check     # Enable health checks
```

### 🐛 **Debug Mode**
```bash
openclaw onboard --debug-mode       # Enable debug output
openclaw onboard --verbose-logging  # Detailed logs
```

---

## 🚀 **Getting Started Commands**

### 🎯 **Quick Setup**
```bash
# Complete setup in one command
openclaw onboard --claude-api-key "sk-ant-..." --binding 0.0.0.0 --solana-rpc "https://api.mainnet-beta.solana.com"
```

### 🔄 **Reset Configuration**
```bash
openclaw onboard --reset-config    # Reset all settings
openclaw onboard --reset-keys      # Reset API keys only
```

### 📋 **Status Check**
```bash
openclaw onboard --status          # Check current configuration
openclaw onboard --validate        # Validate setup
```

---

## 💡 **Tips & Tricks**

### 🎨 **UI Customization**
```bash
openclaw onboard --theme dark       # Dark theme
openclaw onboard --font-size 14     # Custom font size
```

### ⚡ **Performance Optimization**
```bash
openclaw onboard --cache-enabled    # Enable caching
openclaw onboard --parallel-tasks  # Parallel processing
```

---

## 🆘 **Need Help?**

### 📚 **Documentation**
- Visit: [OpenClaw Docs](https://docs.openclaw.dev)
- GitHub: [OpenClaw Repository](https://github.com/your-org/openclaw)

### 💬 **Community Support**
- Discord: [OpenClaw Community](https://discord.gg/openclaw)
- Telegram: [OpenClaw Support](https://t.me/openclaw)

### 🐛 **Report Issues**
- GitHub Issues: [Bug Reports](https://github.com/your-org/openclaw/issues)
- Email: support@openclaw.dev

---

## 🎉 **You're Ready!**

Once you've configured your API keys and basic settings, you're ready to:

1. **Start Chatting** with your AI agent
2. **Explore Skills** and automation
3. **Set Up Scheduling** for automated tasks
4. **Configure Solana** for blockchain features
5. **Monitor Performance** with built-in analytics

**Welcome to OpenClaw! 🚀**
''';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Onboarding'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading Onboarding...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparing your OpenClaw experience',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.red.shade700.withValues(alpha: 1.0),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOnboardingContent,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildOnboardingContent(),
      ),
    );
  }

  Widget _buildOnboardingContent() {
    return Column(
      children: [
        // Progress Indicator
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0, // Complete since we're showing full guide
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Main Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.rocket_launch,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome to OpenClaw!',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your Advanced AI Agent Platform',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // API Key Status Card
                StreamBuilder<ApiState>(
                  stream: _apiService.apiStateStream as Stream<ApiState>?,
                  initialData: ApiState.checking,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? ApiState.checking;
                    return _buildApiKeyStatusCard(state);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Markdown Content
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Setup Guide',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: SingleChildScrollView(
                          child: Markdown(
                            data: _helpText,
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.6,
                              ),
                              h1: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              h2: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              h3: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              code: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              blockquote: GoogleFonts.inter(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                border: Border(
                                  left: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 4,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              listBullet: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tableHead: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tableBody: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              tableBorder: TableBorder.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Get Started'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyStatusCard(ApiState state) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;
    String title;
    String description;
    List<Widget> actions = [];

    switch (state) {
      case ApiState.configured:
        backgroundColor = Colors.green.shade50;
        iconColor = Colors.green;
        icon = Icons.check_circle;
        title = 'API Keys Configured';
        description = 'Your AI providers are ready to use!';
        break;
      case ApiState.noKeys:
        backgroundColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        icon = Icons.warning;
        title = 'API Keys Needed';
        description = 'Configure at least one API provider to get started';
        actions = [
          TextButton(
            onPressed: () {
              // Navigate to API key setup
            },
            child: const Text('Configure Now'),
          ),
        ];
        break;
      case ApiState.checking:
        backgroundColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        icon = Icons.sync;
        title = 'Checking Configuration';
        description = 'Verifying your API key setup...';
        break;
      case ApiState.error:
        backgroundColor = Colors.red.shade50;
        iconColor = Colors.red;
        icon = Icons.error;
        title = 'Configuration Error';
        description = 'There was an issue checking your API keys';
        actions = [
          TextButton(
            onPressed: () => _apiService.initialize(),
            child: const Text('Retry'),
          ),
        ];
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

enum ApiState {
  checking,
  configured,
  noKeys,
  error,
}
