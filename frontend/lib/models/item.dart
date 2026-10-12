/// `ItemPublic`
class ItemPublic {
  const ItemPublic({
    required this.id,
    required this.title,
    required this.ownerId,
    this.description,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String ownerId;
  final DateTime? createdAt;

  factory ItemPublic.fromJson(Map<String, dynamic> json) => ItemPublic(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        ownerId: json['owner_id'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

/// `ItemsPublic`
class ItemsPublic {
  const ItemsPublic({required this.data, required this.count});

  final List<ItemPublic> data;
  final int count;

  factory ItemsPublic.fromJson(Map<String, dynamic> json) => ItemsPublic(
        data: (json['data'] as List)
            .map((e) => ItemPublic.fromJson(e as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
      );
}

/// `ItemCreate`
class ItemCreate {
  const ItemCreate({required this.title, this.description});

  final String title;
  final String? description;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
      };
}

/// `ItemUpdate`
class ItemUpdate {
  const ItemUpdate({this.title, this.description});

  final String? title;
  final String? description;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        'description': description,
      };
}
