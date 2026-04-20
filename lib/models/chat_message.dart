class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageBase64;     // base64-encoded JPEG/PNG when message has an image
  final String? imageMimeType;   // e.g. "image/jpeg" (default when null)
  // Qwen/DeepSeek <think>…</think> reasoning blocks, stripped from main text.
  // Non-null and non-empty only on assistant messages where the model emitted
  // reasoning tokens. Shown as a collapsible "Reasoning" section in ChatBubble.
  final String? thinkContent;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBase64,
    this.imageMimeType,
    this.thinkContent,
  });

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  /// True when the model emitted visible reasoning before its answer.
  bool get hasThinkContent =>
      thinkContent != null && thinkContent!.trim().isNotEmpty;

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
