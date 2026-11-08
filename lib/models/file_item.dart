enum ItemType { folder, video, text, image, other }

class FileItem {
  final String name;
  final String path;
  final String url;
  final String date;
  final String size;
  final ItemType type;

  FileItem({
    required this.name,
    required this.path,
    required this.url,
    required this.date,
    required this.size,
    required this.type,
  });

  bool get isFolder => type == ItemType.folder;
  bool get isVideo => type == ItemType.video;
  bool get isText => type == ItemType.text;
  bool get isImage => type == ItemType.image;
  String get modifiedTime => date;
}
