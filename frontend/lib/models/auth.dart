/// `Token`
class Token {
  const Token({
    required this.accessToken,
    this.tokenType = 'bearer',
    this.refreshToken,
    this.expiresIn = 900,
  });

  final String accessToken;
  final String tokenType;
  final String? refreshToken;
  final int expiresIn;

  factory Token.fromJson(Map<String, dynamic> json) => Token(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    expiresIn: json['expires_in'] as int? ?? 900,
    tokenType: json['token_type'] as String? ?? 'bearer',
  );
}

/// `Message`
class Message {
  const Message({required this.message});

  final String message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      Message(message: json['message'] as String);
}

/// `NewPassword`
class NewPassword {
  const NewPassword({required this.token, required this.newPassword});

  final String token;
  final String newPassword;

  Map<String, dynamic> toJson() => {
    'token': token,
    'new_password': newPassword,
  };
}
