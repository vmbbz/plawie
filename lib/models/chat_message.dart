/// A single tool call or tool result event emitted by the AI agent during a turn.
/// Shown as collapsible chips in the chat bubble (amber = call, green = result).
class ChatToolEvent {
  final String type;   // 'tool_use' | 'tool_result'
  final String name;   // e.g. 'camera.snap'
  final Map<String, dynamic>? input;
  final String? result;

  const ChatToolEvent({
    required this.type,
    required this.name,
    this.input,
    this.result,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageBase64;     // base64-encoded JPEG/PNG when message has an image
  final String? imageMimeType;   // e.g. "image/jpeg" (default when null)
  // Qwen/DeepSeek <think>…</think> reasoning blocks, stripped from main text.
  // Non-null and non-empty only on assistant messages where the model emitted
  // reasoning tokens. Shown as a collapsible "Reasoning" section in ChatBubble.
  final String? thinkContent;
  // Tool call / result events captured from the gateway stream for this turn.
  final List<ChatToolEvent>? toolEvents;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBase64,
    this.imageMimeType,
    this.thinkContent,
    this.toolEvents,
  });

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  /// True when the model emitted visible reasoning before its answer.
  bool get hasThinkContent =>
      thinkContent != null && thinkContent!.trim().isNotEmpty;

  bool get hasToolEvents => toolEvents != null && toolEvents!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (imageMimeType != null) 'imageMimeType': imageMimeType,
        if (thinkContent != null) 'thinkContent': thinkContent,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        imageBase64: json['imageBase64'] as String?,
        imageMimeType: json['imageMimeType'] as String?,
        thinkContent: json['thinkContent'] as String?,
      );
}
