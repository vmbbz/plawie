class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageBase64;     // base64-encoded JPEG/PNG when message has an image
  final String? imageMimeType;   // e.g. "image/jpeg" (default when null)

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBase64,
    this.imageMimeType,
  });

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (imageMimeType != null) 'imageMimeType': imageMimeType,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        imageBase64: json['imageBase64'] as String?,
        imageMimeType: json['imageMimeType'] as String?,
      );
}
