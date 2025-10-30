class Ad {
  final String id;
  final String? imageUrl;
  final String? link;
  final String? title;
  final String? description;

  Ad({
    required this.id,
    this.imageUrl,
    this.link,
    this.title,
    this.description,
  });

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
        id: json['_id'] ?? '',
        imageUrl: json['imageUrl'],
        link: json['link'],
        title: json['title'],
        description: json['description'],
      );
}

class AdsResponse {
  final int status;
  final String message;
  final List<Ad> data;

  AdsResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory AdsResponse.fromJson(Map<String, dynamic> json) => AdsResponse(
        status: json['status'],
        message: json['message'],
        data: (json['data'] as List<dynamic>?)
                ?.map((e) => Ad.fromJson(e))
                .toList() ??
            [],
      );
}
