/// `UserPublic` from the OpenAPI schema.
class UserPublic {
  const UserPublic({
    required this.id,
    this.email,
    this.username = '',
    this.fullName,
    this.isActive = true,
    this.isSuperuser = false,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String username;
  final String? fullName;
  final bool isActive;
  final bool isSuperuser;
  final DateTime? createdAt;

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!
      : (username.isNotEmpty ? username : (email ?? 'User'));

  factory UserPublic.fromJson(Map<String, dynamic> json) => UserPublic(
    id: json['id'] as String,
    email: json['email'] as String?,
    username: json['username'] as String? ?? '',
    fullName: json['full_name'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    isSuperuser: json['is_superuser'] as bool? ?? false,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  UserPublic copyWith({
    String? email,
    String? fullName,
    bool? isActive,
    bool? isSuperuser,
  }) => UserPublic(
    id: id,
    username: username,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    isActive: isActive ?? this.isActive,
    isSuperuser: isSuperuser ?? this.isSuperuser,
    createdAt: createdAt,
  );
}

/// `UsersPublic`
class UsersPublic {
  const UsersPublic({required this.data, required this.count});

  final List<UserPublic> data;
  final int count;

  factory UsersPublic.fromJson(Map<String, dynamic> json) => UsersPublic(
    data: (json['data'] as List)
        .map((e) => UserPublic.fromJson(e as Map<String, dynamic>))
        .toList(),
    count: json['count'] as int,
  );
}

/// `UserRegister`
class UserRegister {
  const UserRegister({
    required this.username,
    this.email,
    required this.password,
    this.fullName,
  });

  final String username;
  final String? email;
  final String password;
  final String? fullName;

  Map<String, dynamic> toJson() => {
    'username': username,
    if (email != null && email!.isNotEmpty) 'email': email,
    'password': password,
    'full_name': fullName,
  };
}

/// `UserCreate` (admin)
class UserCreate {
  const UserCreate({
    required this.email,
    required this.password,
    this.fullName,
    this.isActive = true,
    this.isSuperuser = false,
  });

  final String email;
  final String password;
  final String? fullName;
  final bool isActive;
  final bool isSuperuser;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'full_name': fullName,
    'is_active': isActive,
    'is_superuser': isSuperuser,
  };
}

/// `UserUpdate` (admin). Null fields are omitted from the payload.
class UserUpdate {
  const UserUpdate({
    this.email,
    this.password,
    this.fullName,
    this.isActive,
    this.isSuperuser,
  });

  final String? email;
  final String? password;
  final String? fullName;
  final bool? isActive;
  final bool? isSuperuser;

  Map<String, dynamic> toJson() => {
    if (email != null) 'email': email,
    if (password != null && password!.isNotEmpty) 'password': password,
    if (fullName != null) 'full_name': fullName,
    if (isActive != null) 'is_active': isActive,
    if (isSuperuser != null) 'is_superuser': isSuperuser,
  };
}

/// `UserUpdateMe`
class UserUpdateMe {
  const UserUpdateMe({this.fullName, this.email});

  final String? fullName;
  final String? email;

  Map<String, dynamic> toJson() => {
    if (fullName != null) 'full_name': fullName,
    if (email != null) 'email': email,
  };
}

/// `UpdatePassword`
class UpdatePassword {
  const UpdatePassword({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() => {
    'current_password': currentPassword,
    'new_password': newPassword,
  };
}
