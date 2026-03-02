import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

/// Skills System with YAML frontmatter and dynamic loading
/// Inspired by SeekerClaw's skills architecture
class SkillsService {
  static final SkillsService _instance = SkillsService._internal();
  factory SkillsService() => _instance;
  SkillsService._internal();

  final Logger _logger = Logger();
  final Map<String, Skill> _skills = {};
  final StreamController<SkillsEvent> _eventController = StreamController.broadcast();
  String? _skillsDirectory;

  Stream<SkillsEvent> get events => _eventController.stream;
  Map<String, Skill> get skills => Map.unmodifiable(_skills);

  /// Initialize skills system
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Skills System...');
      
      // Get skills directory
      final appDir = await getApplicationDocumentsDirectory();
      _skillsDirectory = path.join(appDir.path, 'skills');
      
      // Create skills directory if it doesn't exist
      await Directory(_skillsDirectory!).create(recursive: true);
      
      // Load bundled skills
      await _loadBundledSkills();
      
      // Load custom skills
      await _loadCustomSkills();
      
      _logger.i('Skills System initialized with ${_skills.length} skills');
    } catch (e) {
      _logger.e('Failed to initialize Skills System: $e');
      rethrow;
    }
  }

  /// Load bundled skills
  Future<void> _loadBundledSkills() async {
    try {
      // Define bundled skills (can be expanded)
      final bundledSkills = [
        _createWeatherSkill(),
        _createCryptoPriceSkill(),
        _createWebSearchSkill(),
        _createFileAnalysisSkill(),
        _createSystemInfoSkill(),
        _createReminderSkill(),
        _createCalculatorSkill(),
        _createTextAnalysisSkill(),
      ];

      for (final skill in bundledSkills) {
        _skills[skill.id] = skill;
        _eventController.add(SkillsEvent.skillLoaded(skill.id));
      }

      _logger.i('Loaded ${bundledSkills.length} bundled skills');
    } catch (e) {
      _logger.e('Failed to load bundled skills: $e');
    }
  }

  /// Load custom skills from directory
  Future<void> _loadCustomSkills() async {
    if (_skillsDirectory == null) return;

    try {
      final skillsDir = Directory(_skillsDirectory!);
      if (!await skillsDir.exists()) return;

      await for (final entity in skillsDir.list()) {
        if (entity is File && entity.path.endsWith('.yaml')) {
          await _loadSkillFromFile(entity);
        } else if (entity is File && entity.path.endsWith('.zip')) {
          await _loadSkillFromZip(entity);
        }
      }

      _logger.i('Loaded custom skills from directory');
    } catch (e) {
      _logger.e('Failed to load custom skills: $e');
    }
  }

  /// Load skill from YAML file
  Future<void> _loadSkillFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final skill = _parseSkillFromYaml(content, file.path);
      
      if (skill != null) {
        _skills[skill.id] = skill;
        _eventController.add(SkillsEvent.skillLoaded(skill.id));
        _logger.d('Loaded skill: ${skill.id}');
      }
    } catch (e) {
      _logger.e('Failed to load skill from ${file.path}: $e');
    }
  }

  /// Load skill from ZIP archive
  Future<void> _loadSkillFromZip(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.name.endsWith('.yaml') && !file.isFile) continue;
        
        final content = utf8.decode(file.content as List<int>);
        final skill = _parseSkillFromYaml(content, file.name);
        
        if (skill != null) {
          _skills[skill.id] = skill;
          _eventController.add(SkillsEvent.skillLoaded(skill.id));
          _logger.d('Loaded skill from ZIP: ${skill.id}');
        }
      }
    } catch (e) {
      _logger.e('Failed to load skill from ZIP ${zipFile.path}: $e');
    }
  }

  /// Parse skill from YAML content
  Skill? _parseSkillFromYaml(String content, String source) {
    try {
      final yaml = loadYaml(content);
      
      if (yaml is! Map) return null;
      
      final frontmatter = yaml['frontmatter'] as Map?;
      if (frontmatter == null) return null;

      // Validate required fields
      if (!frontmatter.containsKey('id') || !frontmatter.containsKey('name')) {
        return null;
      }

      // Check version and integrity
      final version = frontmatter['version'] as String? ?? '1.0.0';
      final expectedHash = frontmatter['sha256'] as String?;
      
      if (expectedHash != null) {
        final actualHash = sha256.convert(utf8.encode(content)).toString();
        if (actualHash != expectedHash) {
          _logger.w('Skill integrity check failed for ${frontmatter['id']}');
          return null;
        }
      }

      final skill = Skill(
        id: frontmatter['id'] as String,
        name: frontmatter['name'] as String,
        description: frontmatter['description'] as String? ?? '',
        version: version,
        author: frontmatter['author'] as String? ?? 'Unknown',
        category: frontmatter['category'] as String? ?? 'general',
        tags: _parseStringList(frontmatter['tags']),
        requirements: _parseRequirements(frontmatter['requirements']),
        body: yaml['body'] as String? ?? content,
        source: source,
        createdAt: DateTime.now(),
        enabled: frontmatter['enabled'] as bool? ?? true,
      );

      return skill;
    } catch (e) {
      _logger.e('Failed to parse skill from YAML: $e');
      return null;
    }
  }

  /// Parse string list from YAML
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Parse skill requirements
  List<SkillRequirement> _parseRequirements(dynamic value) {
    if (value == null) return [];
    
    final requirements = <SkillRequirement>[];
    
    if (value is Map) {
      for (final entry in value.entries) {
        requirements.add(SkillRequirement(
          type: entry.key,
          value: entry.value.toString(),
        ));
      }
    } else if (value is List) {
      for (final item in value) {
        if (item is String) {
          requirements.add(SkillRequirement(
            type: 'general',
            value: item,
          ));
        }
      }
    }
    
    return requirements;
  }

  /// Execute a skill
  Future<SkillResult> executeSkill(
    String skillId, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? context,
  }) async {
    final skill = _skills[skillId];
    if (skill == null) {
      return SkillResult.error('Skill not found: $skillId');
    }

    if (!skill.enabled) {
      return SkillResult.error('Skill is disabled: $skillId');
    }

    // Check requirements
    final requirementsCheck = await _checkRequirements(skill.requirements);
    if (!requirementsCheck.success) {
      return SkillResult.error('Requirements not met: ${requirementsCheck.error}');
    }

    try {
      _eventController.add(SkillsEvent.skillExecuting(skillId));
      
      // Execute skill based on type
      final result = await _executeSkillLogic(skill, parameters ?? {}, context ?? {});
      
      _eventController.add(SkillsEvent.skillExecuted(skillId, result));
      return result;
    } catch (e) {
      _logger.e('Failed to execute skill $skillId: $e');
      _eventController.add(SkillsEvent.skillError(skillId, e.toString()));
      return SkillResult.error(e.toString());
    }
  }

  /// Execute skill logic based on category
  Future<SkillResult> _executeSkillLogic(
    Skill skill,
    Map<String, dynamic> parameters,
    Map<String, dynamic> context,
  ) async {
    switch (skill.category) {
      case 'weather':
        return await _executeWeatherSkill(skill, parameters, context);
      case 'crypto':
        return await _executeCryptoSkill(skill, parameters, context);
      case 'search':
        return await _executeSearchSkill(skill, parameters, context);
      case 'file':
        return await _executeFileSkill(skill, parameters, context);
      case 'system':
        return await _executeSystemSkill(skill, parameters, context);
      case 'reminder':
        return await _executeReminderSkill(skill, parameters, context);
      case 'calculator':
        return await _executeCalculatorSkill(skill, parameters, context);
      case 'text':
        return await _executeTextSkill(skill, parameters, context);
      default:
        return await _executeGenericSkill(skill, parameters, context);
    }
  }

  /// Check skill requirements
  Future<RequirementsCheck> _checkRequirements(List<SkillRequirement> requirements) async {
    for (final requirement in requirements) {
      switch (requirement.type) {
        case 'network':
          // Check network connectivity
          try {
            final response = await http.get(Uri.parse('https://www.google.com'));
            if (response.statusCode != 200) {
              return RequirementsCheck.failed('Network connectivity required');
            }
          } catch (e) {
            return RequirementsCheck.failed('Network connectivity required');
          }
          break;
        
        case 'api_key':
          // Check for required API keys
          // This would integrate with the API key detection service
          break;
        
        case 'permission':
          // Check for required permissions
          // This would integrate with permission handling
          break;
        
        default:
          // General requirements check
          break;
      }
    }
    
    return RequirementsCheck.success();
  }

  /// Install skill from URL
  Future<bool> installSkillFromUrl(String url) async {
    try {
      _logger.i('Installing skill from URL: $url');
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download skill: ${response.statusCode}');
      }

      final skill = _parseSkillFromYaml(response.body, url);
      if (skill == null) {
        throw Exception('Invalid skill format');
      }

      // Save skill to local directory
      if (_skillsDirectory != null) {
        final skillFile = File(path.join(_skillsDirectory!, '${skill.id}.yaml'));
        await skillFile.writeAsString(response.body);
      }

      _skills[skill.id] = skill;
      _eventController.add(SkillsEvent.skillInstalled(skill.id));
      
      _logger.i('Successfully installed skill: ${skill.id}');
      return true;
    } catch (e) {
      _logger.e('Failed to install skill from URL: $e');
      _eventController.add(SkillsEvent.skillError('install', e.toString()));
      return false;
    }
  }

  /// Uninstall skill
  Future<bool> uninstallSkill(String skillId) async {
    try {
      final skill = _skills[skillId];
      if (skill == null) return false;

      // Remove from memory
      _skills.remove(skillId);

      // Remove file if it's a custom skill
      if (_skillsDirectory != null && skill.source.startsWith(_skillsDirectory!)) {
        final skillFile = File(skill.source);
        if (await skillFile.exists()) {
          await skillFile.delete();
        }
      }

      _eventController.add(SkillsEvent.skillUninstalled(skillId));
      _logger.i('Uninstalled skill: $skillId');
      return true;
    } catch (e) {
      _logger.e('Failed to uninstall skill $skillId: $e');
      return false;
    }
  }

  /// Enable/disable skill
  Future<void> toggleSkill(String skillId, bool enabled) async {
    final skill = _skills[skillId];
    if (skill == null) return;

    final updatedSkill = skill.copyWith(enabled: enabled);
    _skills[skillId] = updatedSkill;
    
    _eventController.add(SkillsEvent.skillToggled(skillId, enabled));
  }

  /// Get skills by category
  List<Skill> getSkillsByCategory(String category) {
    return _skills.values
        .where((skill) => skill.category == category)
        .toList();
  }

  /// Search skills
  List<Skill> searchSkills(String query) {
    final lowerQuery = query.toLowerCase();
    
    return _skills.values.where((skill) {
      return skill.name.toLowerCase().contains(lowerQuery) ||
             skill.description.toLowerCase().contains(lowerQuery) ||
             skill.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Skill execution methods (simplified implementations)
  Future<SkillResult> _executeWeatherSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Weather skill implementation
    return SkillResult.success({'weather': 'Sunny, 75°F', 'location': parameters['location'] ?? 'Current'});
  }

  Future<SkillResult> _executeCryptoSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Crypto skill implementation
    final symbol = parameters['symbol'] ?? 'BTC';
    return SkillResult.success({'symbol': symbol, 'price': '\$45,000', 'change': '+2.5%'});
  }

  Future<SkillResult> _executeSearchSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Search skill implementation
    final query = parameters['query'] ?? '';
    return SkillResult.success({'query': query, 'results': ['Result 1', 'Result 2']});
  }

  Future<SkillResult> _executeFileSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // File skill implementation
    return SkillResult.success({'files': ['file1.txt', 'file2.jpg']});
  }

  Future<SkillResult> _executeSystemSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // System skill implementation
    return SkillResult.success({'battery': '85%', 'memory': '4GB used', 'storage': '32GB free'});
  }

  Future<SkillResult> _executeReminderSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Reminder skill implementation
    final message = parameters['message'] ?? 'Reminder set';
    return SkillResult.success({'reminder': message, 'time': DateTime.now().add(Duration(hours: 1))});
  }

  Future<SkillResult> _executeCalculatorSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Calculator skill implementation
    final expression = parameters['expression'] ?? '2+2';
    return SkillResult.success({'expression': expression, 'result': '4'});
  }

  Future<SkillResult> _executeTextSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Text analysis skill implementation
    final text = parameters['text'] ?? '';
    return SkillResult.success({'text': text, 'length': text.length, 'words': text.split(' ').length});
  }

  Future<SkillResult> _executeGenericSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    // Generic skill execution
    return SkillResult.success({'message': 'Executed ${skill.name}', 'parameters': parameters});
  }

  // Bundled skill creators
  Skill _createWeatherSkill() {
    return Skill(
      id: 'weather',
      name: 'Weather Information',
      description: 'Get current weather information for any location',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'weather',
      tags: ['weather', 'forecast', 'temperature'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: '''# Weather Skill

## Description
Provides current weather information for any location worldwide.

## Usage
- Ask "What's the weather in New York?"
- Request "Weather forecast for London"
- Get "Temperature in Tokyo"

## Requirements
- Internet connection
- Location access (optional)

## Returns
- Current temperature
- Weather conditions
- Location information
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createCryptoPriceSkill() {
    return Skill(
      id: 'crypto_price',
      name: 'Cryptocurrency Prices',
      description: 'Get real-time cryptocurrency price information',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'crypto',
      tags: ['crypto', 'bitcoin', 'ethereum', 'prices'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: '''# Crypto Price Skill

## Description
Provides real-time price information for cryptocurrencies.

## Usage
- Ask "What's the price of Bitcoin?"
- Request "ETH price"
- Get "Dogecoin value"

## Requirements
- Internet connection

## Returns
- Current price
- 24h change
- Market data
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createWebSearchSkill() {
    return Skill(
      id: 'web_search',
      name: 'Web Search',
      description: 'Search the web for information',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'search',
      tags: ['search', 'web', 'google', 'information'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: '''# Web Search Skill

## Description
Search the web for information using various search engines.

## Usage
- "Search for Flutter tutorials"
- "Find information about AI"
- "Look up weather patterns"

## Requirements
- Internet connection

## Returns
- Search results
- Relevant links
- Summarized information
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createFileAnalysisSkill() {
    return Skill(
      id: 'file_analysis',
      name: 'File Analysis',
      description: 'Analyze and manage files',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'file',
      tags: ['file', 'analysis', 'storage'],
      requirements: [SkillRequirement(type: 'permission', value: 'storage')],
      body: '''# File Analysis Skill

## Description
Analyze files and storage information.

## Usage
- "Show my files"
- "Analyze this document"
- "Storage information"

## Requirements
- Storage permission

## Returns
- File list
- Storage usage
- File analysis
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createSystemInfoSkill() {
    return Skill(
      id: 'system_info',
      name: 'System Information',
      description: 'Get device and system information',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'system',
      tags: ['system', 'device', 'information'],
      requirements: [],
      body: '''# System Info Skill

## Description
Provides device and system information.

## Usage
- "System information"
- "Battery status"
- "Device details"

## Requirements
- None

## Returns
- Device info
- Battery status
- Memory usage
- Storage information
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createReminderSkill() {
    return Skill(
      id: 'reminder',
      name: 'Reminder System',
      description: 'Set and manage reminders',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'reminder',
      tags: ['reminder', 'alarm', 'notification'],
      requirements: [SkillRequirement(type: 'permission', value: 'notifications')],
      body: '''# Reminder Skill

## Description
Set and manage reminders for tasks and events.

## Usage
- "Remind me to call mom in 1 hour"
- "Set reminder for meeting tomorrow"
- "Alert me when battery is low"

## Requirements
- Notification permission

## Returns
- Confirmation
- Reminder details
- Management options
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createCalculatorSkill() {
    return Skill(
      id: 'calculator',
      name: 'Calculator',
      description: 'Perform mathematical calculations',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'calculator',
      tags: ['math', 'calculator', 'calculation'],
      requirements: [],
      body: '''# Calculator Skill

## Description
Perform mathematical calculations and expressions.

## Usage
- "Calculate 2+2"
- "What is 15% of 200?"
- "Square root of 144"

## Requirements
- None

## Returns
- Calculation result
- Steps shown
- Mathematical format
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  Skill _createTextAnalysisSkill() {
    return Skill(
      id: 'text_analysis',
      name: 'Text Analysis',
      description: 'Analyze text for various metrics',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'text',
      tags: ['text', 'analysis', 'writing'],
      requirements: [],
      body: '''# Text Analysis Skill

## Description
Analyze text for word count, readability, and other metrics.

## Usage
- "Analyze this text"
- "Word count of document"
- "Readability score"

## Requirements
- None

## Returns
- Word count
- Character count
- Readability metrics
- Language detection
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,
    );
  }

  /// Dispose skills service
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Skill model
class Skill {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String category;
  final List<String> tags;
  final List<SkillRequirement> requirements;
  final String body;
  final String source;
  final DateTime createdAt;
  final bool enabled;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.category,
    required this.tags,
    required this.requirements,
    required this.body,
    required this.source,
    required this.createdAt,
    required this.enabled,
  });

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    String? category,
    List<String>? tags,
    List<SkillRequirement>? requirements,
    String? body,
    String? source,
    DateTime? createdAt,
    bool? enabled,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      requirements: requirements ?? this.requirements,
      body: body ?? this.body,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Skill Requirement model
class SkillRequirement {
  final String type;
  final String value;

  SkillRequirement({
    required this.type,
    required this.value,
  });
}

/// Skill Result model
class SkillResult {
  final bool success;
  final dynamic data;
  final String? error;

  SkillResult({required this.success, this.data, this.error});

  factory SkillResult.success(dynamic data) {
    return SkillResult(success: true, data: data);
  }

  factory SkillResult.error(String error) {
    return SkillResult(success: false, error: error);
  }
}

/// Requirements Check model
class RequirementsCheck {
  final bool success;
  final String? error;

  RequirementsCheck({required this.success, this.error});

  factory RequirementsCheck.success() {
    return RequirementsCheck(success: true);
  }

  factory RequirementsCheck.failed(String error) {
    return RequirementsCheck(success: false, error: error);
  }
}

/// Skills Event model
class SkillsEvent {
  final SkillsEventType type;
  final String? skillId;
  final SkillResult? result;
  final String? error;

  SkillsEvent({
    required this.type,
    this.skillId,
    this.result,
    this.error,
  });

  factory SkillsEvent.skillLoaded(String skillId) =>
      SkillsEvent(type: SkillsEventType.loaded, skillId: skillId);

  factory SkillsEvent.skillExecuting(String skillId) =>
      SkillsEvent(type: SkillsEventType.executing, skillId: skillId);

  factory SkillsEvent.skillExecuted(String skillId, SkillResult result) =>
      SkillsEvent(type: SkillsEventType.executed, skillId: skillId, result: result);

  factory SkillsEvent.skillError(String skillId, String error) =>
      SkillsEvent(type: SkillsEventType.error, skillId: skillId, error: error);

  factory SkillsEvent.skillInstalled(String skillId) =>
      SkillsEvent(type: SkillsEventType.installed, skillId: skillId);

  factory SkillsEvent.skillUninstalled(String skillId) =>
      SkillsEvent(type: SkillsEventType.uninstalled, skillId: skillId);

  factory SkillsEvent.skillToggled(String skillId, bool enabled) =>
      SkillsEvent(type: SkillsEventType.toggled, skillId: skillId);
}

/// Skills Event Type enum
enum SkillsEventType {
  loaded,
  executing,
  executed,
  error,
  installed,
  uninstalled,
  toggled,
}
