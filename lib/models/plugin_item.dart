enum PluginType { m3u, json, customSite }

class PluginItem {
  final String id;
  final String name;
  final String description;
  final String url;
  final PluginType type;
  bool isEnabled;

  PluginItem({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.type,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'url': url,
        'type': type.name,
        'isEnabled': isEnabled,
      };

  factory PluginItem.fromJson(Map<String, dynamic> json) => PluginItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        url: json['url'] as String,
        type: PluginType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PluginType.m3u,
        ),
        icon: json['icon'] as String?,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  static List<PluginItem> get builtInPlugins => [
        PluginItem(
          id: 'pandatv_official',
          name: 'PandaLive 官方直播源',
          description: '官方实时超清 HLS 直播源订阅',
          type: PluginType.m3u,
          url: 'https://raw.githubusercontent.com/djsevenx1/jinricp-pure-app/main/data/pandatv_live.json',
          icon: 'live_tv',
        ),
        PluginItem(
          id: 'flextv_official',
          name: 'FlexTV 官方直播源',
          description: '韩国 FlexTV 热门女主播实时流',
          type: PluginType.jsonApi,
          url: 'https://raw.githubusercontent.com/djsevenx1/jinricp-pure-app/main/data/flextv_live.json',
          icon: 'extension',
        ),
      ];
}
