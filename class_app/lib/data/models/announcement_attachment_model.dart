class AnnouncementAttachmentModel {
  const AnnouncementAttachmentModel({
    required this.name,
    this.url,
    this.size,
    this.key,
  });

  final String name;
  final String? url;
  final int? size;
  final String? key;

  factory AnnouncementAttachmentModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachmentModel(
      name: json['name'] as String? ?? json['Name'] as String? ?? '',
      url: json['url'] as String? ?? json['Url'] as String?,
      key: json['key'] as String? ?? json['Key'] as String?,
      size: (json['size'] as num?)?.toInt() ??
          (json['Size'] as num?)?.toInt(),
    );
  }
}
