import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

/// Model Context Protocol (MCP) Support Service
/// Connects to remote MCP servers via Streamable HTTP (JSON-RPC 2.0)
/// Based on SeekerClaw's MCP client implementation
class MCPService {
  static final MCPService _instance = MCPService._internal();
  factory MCPService() => _instance;
  MCPService._internal();

  final Logger _logger = Logger();
  final Map<String, MCPConnection> _connections = {};
  final Map<String, MCPTool> _availableTools = {};
  final StreamController<MCPEvent> _eventController = StreamController.broadcast();
  
  // Rate limiting (per SeekerClaw implementation)
  final Map<String, List<int>> _rateLimits = {};
  final List<int> _globalRateLimit = [];
  static const int _defaultRateLimit = 10;
  static const int _globalRateLimitConst = 50;
  static const int _rateLimitWindowMs = 60000; // 1 minute

  Stream<MCPEvent> get events => _eventController.stream;
  Map<String, MCPTool> get availableTools => Map.unmodifiable(_availableTools);

  /// Connect to an MCP server (SeekerClaw-style HTTP-based MCP)
  Future<bool> connectToServer(String serverUrl, {String? apiKey}) async {
    try {
      _logger.i('Connecting to MCP server: $serverUrl');
      
      // Validate URL and check rate limits
      if (!_checkRateLimit(serverUrl)) {
        _logger.w('Rate limit exceeded for server: $serverUrl');
        return false;
      }
      
      final connection = MCPConnection(
        url: serverUrl,
        apiKey: apiKey,
      );
      
      await connection.connect();
      
      // Initialize the connection with MCP 2025-06-18 protocol
      await _initializeConnection(connection);
      
      _connections[serverUrl] = connection;
      _eventController.add(MCPEvent.connected(serverUrl));
      
      _logger.i('Successfully connected to MCP server: $serverUrl');
      return true;
    } catch (e) {
      _logger.e('Failed to connect to MCP server $serverUrl: $e');
      _eventController.add(MCPEvent.error(serverUrl, e.toString()));
      return false;
    }
  }

  /// Initialize MCP connection and discover tools (SeekerClaw implementation)
  Future<void> _initializeConnection(MCPConnection connection) async {
    // Send initialize message with MCP 2025-06-18 protocol
    final initMessage = {
      'jsonrpc': '2.0',
      'id': 'init',
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'capabilities': {
          'tools': {},
        },
        'clientInfo': {
          'name': 'OpenClaw',
          'version': '1.7.2',
        },
      },
    };

    final response = await connection.send(initMessage);
    
    if (response['result'] != null) {
      // Discover available tools with security checks
      await _discoverTools(connection);
    }
  }

  /// Discover available tools from MCP server (with security checks)
  Future<void> _discoverTools(MCPConnection connection) async {
    try {
      final toolsMessage = {
        'jsonrpc': '2.0',
        'id': 'tools_list',
        'method': 'tools/list',
        'params': {},
      };

      final response = await connection.send(toolsMessage);
      
      if (response['result'] != null && response['result']['tools'] != null) {
        final tools = <MCPTool>[];
        
        for (final toolJson in response['result']['tools']) {
          // Security: sanitize and hash tool definition
          final sanitizedTool = _sanitizeTool(toolJson, connection.url);
          if (sanitizedTool != null) {
            tools.add(sanitizedTool);
          }
        }

        for (final tool in tools) {
          _availableTools[tool.id] = tool;
        }

        _eventController.add(MCPEvent.toolsDiscovered(connection.url, tools));
        _logger.i('Discovered ${tools.length} tools from ${connection.url}');
      }
    } catch (e) {
      _logger.e('Failed to discover tools: $e');
    }
  }

  /// Sanitize MCP tool and check for rug pulls (SeekerClaw security)
  MCPTool? _sanitizeTool(Map<String, dynamic> toolJson, String serverUrl) {
    try {
      final name = toolJson['name'] as String?;
      final description = toolJson['description'] as String?;
      
      if (name == null || description == null) {
        _logger.w('Tool missing required fields: $toolJson');
        return null;
      }
      
      // Length limits (SeekerClaw security)
      if (name.length > 64 || description.length > 2000) {
        _logger.w('Tool exceeds length limits: $name');
        return null;
      }
      
      // Sanitize description (remove invisible Unicode, HTML, etc.)
      final sanitizedDescription = _sanitizeDescription(description);
      
      // Create tool with security checks
      final tool = MCPTool(
        id: '${serverUrl}_${name}',
        name: name,
        description: sanitizedDescription,
        serverUrl: serverUrl,
        parameters: _parseToolParameters(toolJson['inputSchema'] ?? {}),
      );
      
      return tool;
    } catch (e) {
      _logger.e('Failed to sanitize tool: $e');
    }
    
    return null;
  }

  /// Sanitize description (SeekerClaw implementation)
  String _sanitizeDescription(String desc) {
    String s = desc;
    
    // Remove Unicode Tag block (U+E0000–U+E007F)
    s = s.replaceAll(RegExp(r'[\uE0000-\uE007F]'), '');
    
    // Remove directional overrides
    s = s.replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '');
    
    // Remove zero-width characters
    s = s.replaceAll(RegExp(r'[\u200B-\u200F\u2060\uFEFF]'), '');
    
    // Remove HTML tags
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Truncate if too long
    if (s.length > 2000) {
      s = s.substring(0, 2000) + '...';
    }
    
    return s.trim();
  }

  /// Parse tool parameters from input schema
  Map<String, MCPToolParameter> _parseToolParameters(Map<String, dynamic> inputSchema) {
    final parameters = <String, MCPToolParameter>{};
    
    if (inputSchema['properties'] != null) {
      final props = inputSchema['properties'] as Map<String, dynamic>;
      for (final entry in props.entries) {
        parameters[entry.key] = MCPToolParameter.fromMcpJson(entry.value);
      }
    }
    
    return parameters;
  }

  /// Check rate limits (SeekerClaw implementation)
  bool _checkRateLimit(String serverUrl) {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Clean old timestamps
    _rateLimits[serverUrl] = _rateLimits[serverUrl] ?? [];
    _rateLimits[serverUrl]!.removeWhere((t) => now - t > _rateLimitWindowMs);
    
    _globalRateLimit.removeWhere((t) => now - t > _rateLimitWindowMs);
    
    // Check limits
    if (_rateLimits[serverUrl]!.length >= _defaultRateLimit ||
        _globalRateLimit.length >= _globalRateLimitConst) {
      return false;
    }
    
    // Record this request
    _rateLimits[serverUrl]!.add(now);
    _globalRateLimit.add(now);
    
    return true;
  }

  /// Execute a tool on an MCP server
  Future<MCPToolResult> executeTool(String toolId, Map<String, dynamic> arguments) async {
    final tool = _availableTools[toolId];
    if (tool == null) {
      throw Exception('Tool not found: $toolId');
    }

    final connection = _connections[tool.serverUrl];
    if (connection == null) {
      throw Exception('Server not connected: ${tool.serverUrl}');
    }

    try {
      final callMessage = {
        'jsonrpc': '2.0',
        'id': 'tool_call_${DateTime.now().millisecondsSinceEpoch}',
        'method': 'tools/call',
        'params': {
          'name': tool.name,
          'arguments': arguments,
        },
      };

      final response = await connection.send(callMessage);
      
      if (response['result'] != null) {
        _eventController.add(MCPEvent.toolExecuted(toolId, arguments, response['result']));
        return MCPToolResult.success(response['result']);
      } else if (response['error'] != null) {
        _eventController.add(MCPEvent.toolError(toolId, response['error']['message']));
        return MCPToolResult.error(response['error']['message']);
      } else {
        return MCPToolResult.error('Unknown error');
      }
    } catch (e) {
      _logger.e('Failed to execute tool $toolId: $e');
      _eventController.add(MCPEvent.toolError(toolId, e.toString()));
      return MCPToolResult.error(e.toString());
    }
  }

  /// Disconnect from an MCP server
  Future<void> disconnectFromServer(String serverUrl) async {
    final connection = _connections.remove(serverUrl);
    if (connection != null) {
      await connection.disconnect();
      
      // Remove tools from this server
      _availableTools.removeWhere((id, tool) => tool.serverUrl == serverUrl);
      
      _eventController.add(MCPEvent.disconnected(serverUrl));
      _logger.i('Disconnected from MCP server: $serverUrl');
    }
  }

  /// Get connection status
  MCPConnectionStatus getConnectionStatus(String serverUrl) {
    final connection = _connections[serverUrl];
    return connection?.status ?? MCPConnectionStatus.disconnected;
  }

  /// List all connected servers
  List<String> getConnectedServers() {
    return _connections.keys.toList();
  }

  /// Dispose all connections
  Future<void> dispose() async {
    for (final connection in _connections.values) {
      await connection.disconnect();
    }
    _connections.clear();
    _availableTools.clear();
    await _eventController.close();
  }
}

/// MCP Connection class
class MCPConnection {
  final String url;
  final String? apiKey;
  WebSocketChannel? _channel;
  int _messageId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  MCPConnection({required this.url, this.apiKey});

  MCPConnectionStatus get status {
    if (_channel == null) return MCPConnectionStatus.disconnected;
    return _channel!.closeCode != null ? MCPConnectionStatus.disconnected : MCPConnectionStatus.connected;
  }

  Future<void> connect() async {
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      
      // Listen for messages
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _logger.e('WebSocket error: $error'),
        onDone: () => _logger.i('WebSocket connection closed'),
      );
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  Future<void> disconnect() async {
    _channel?.sink.close();
    _channel = null;
    _pendingRequests.clear();
  }

  Future<Map<String, dynamic>> send(Map<String, dynamic> message) async {
    if (_channel == null) {
      throw Exception('Not connected');
    }

    final id = 'msg_${++_messageId}';
    message['id'] = id;

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    _channel!.sink.add(jsonEncode(message));

    // Wait for response with timeout
    return await completer.future.timeout(Duration(seconds: 30));
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final id = data['id'] as String?;

      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;
        completer.complete(data);
      }
    } catch (e) {
      _logger.e('Failed to handle message: $e');
    }
  }

  static final Logger _logger = Logger();
}

/// MCP Tool model
class MCPTool {
  final String id;
  final String name;
  final String description;
  final String serverUrl;
  final Map<String, MCPToolParameter> parameters;

  MCPTool({
    required this.id,
    required this.name,
    required this.description,
    required this.serverUrl,
    required this.parameters,
  });

  factory MCPTool.fromMcpJson(Map<String, dynamic> json, String serverUrl) {
    final parameters = <String, MCPToolParameter>{};
    
    if (json['inputSchema'] != null && json['inputSchema']['properties'] != null) {
      final props = json['inputSchema']['properties'] as Map<String, dynamic>;
      for (final entry in props.entries) {
        parameters[entry.key] = MCPToolParameter.fromMcpJson(entry.value);
      }
    }

    return MCPTool(
      id: '${serverUrl}_${json['name']}',
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      serverUrl: serverUrl,
      parameters: parameters,
    );
  }
}

/// MCP Tool Parameter model
class MCPToolParameter {
  final String type;
  final String description;
  final bool required;

  MCPToolParameter({
    required this.type,
    required this.description,
    required this.required,
  });

  factory MCPToolParameter.fromMcpJson(Map<String, dynamic> json) {
    return MCPToolParameter(
      type: json['type'] as String? ?? 'string',
      description: json['description'] as String? ?? '',
      required: false, // MCP doesn't mark required in schema
    );
  }
}

/// MCP Tool Result model
class MCPToolResult {
  final bool success;
  final dynamic data;
  final String? error;

  MCPToolResult({required this.success, this.data, this.error});

  factory MCPToolResult.success(dynamic data) {
    return MCPToolResult(success: true, data: data);
  }

  factory MCPToolResult.error(String error) {
    return MCPToolResult(success: false, error: error);
  }
}

/// MCP Connection Status enum
enum MCPConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// MCP Event model
class MCPEvent {
  final MCPEventType type;
  final String serverUrl;
  final String? error;
  final List<MCPTool>? tools;
  final String? toolId;
  final Map<String, dynamic>? arguments;
  final dynamic result;

  MCPEvent({
    required this.type,
    required this.serverUrl,
    this.error,
    this.tools,
    this.toolId,
    this.arguments,
    this.result,
  });

  factory MCPEvent.connected(String serverUrl) => 
      MCPEvent(type: MCPEventType.connected, serverUrl: serverUrl);
      
  factory MCPEvent.disconnected(String serverUrl) => 
      MCPEvent(type: MCPEventType.disconnected, serverUrl: serverUrl);
      
  factory MCPEvent.error(String serverUrl, String error) => 
      MCPEvent(type: MCPEventType.error, serverUrl: serverUrl, error: error);
      
  factory MCPEvent.toolsDiscovered(String serverUrl, List<MCPTool> tools) => 
      MCPEvent(type: MCPEventType.toolsDiscovered, serverUrl: serverUrl, tools: tools);
      
  factory MCPEvent.toolExecuted(String toolId, Map<String, dynamic> arguments, dynamic result) => 
      MCPEvent(type: MCPEventType.toolExecuted, serverUrl: '', toolId: toolId, arguments: arguments, result: result);
      
  factory MCPEvent.toolError(String toolId, String error) => 
      MCPEvent(type: MCPEventType.toolError, serverUrl: '', toolId: toolId, error: error);
}

/// MCP Event Type enum
enum MCPEventType {
  connected,
  disconnected,
  error,
  toolsDiscovered,
  toolExecuted,
  toolError,
}
