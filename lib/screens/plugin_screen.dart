import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plugin_item.dart';
import 'player_screen.dart';
import '../services/system_controls_service.dart';

class PluginScreen extends StatefulWidget {
  const PluginScreen({super.key});

  @override
  State<PluginScreen> createState() => _PluginScreenState();
}

class _PluginScreenState extends State<PluginScreen> {
  List<PluginItem> _plugins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('custom_plugins');
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _plugins = list.map((e) => PluginItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _plugins = List.from(PluginItem.builtInPlugins);
      }
    } else {
      _plugins = List.from(PluginItem.builtInPlugins);
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePlugins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_plugins.map((e) => e.toJson()).toList());
    await prefs.setString('custom_plugins', jsonStr);
  }

  void _showAddPluginDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();
    PluginType selectedType = PluginType.m3u;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2033),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.extension_rounded, color: Colors.deepPurpleAccent),
              SizedBox(width: 8),
              Text('添加自定义插件/直播源', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '插件/源名称 (如: 我的备用直播源)',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '源地址 URL (.m3u8, .m3u, .json 或 站点网址)',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '备注描述 (可选)',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PluginType>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF252A42),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '插件类型',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PluginType.m3u,
                      child: Text('M3U / HLS 直播源订阅'),
                    ),
                    DropdownMenuItem(
                      value: PluginType.json,
                      child: Text('JSON 接口源'),
                    ),
                    DropdownMenuItem(
                      value: PluginType.customSite,
                      child: Text('Web 目录站点'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final url = urlController.text.trim();
                if (name.isNotEmpty && url.isNotEmpty) {
                  final newPlugin = PluginItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    description: descController.text.trim(),
                    url: url,
                    type: selectedType,
                  );
                  setState(() {
                    _plugins.add(newPlugin);
                  });
                  _savePlugins();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加插件: $name')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _testPlayUrl(PluginItem plugin) async {
    if (plugin.url.contains('.m3u8') || plugin.url.contains('.mp4')) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: plugin.name,
            videoUrl: plugin.url,
          ),
        ),
      );
      SystemControlsService.resetBrightness();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插件 ${plugin.name} 生效中 (目标: ${plugin.url})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141724),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.extension_rounded, color: Colors.deepPurpleAccent, size: 22),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '插件与源管理',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '自定义直播源 / 订阅 / 视频解析插件扩展',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.deepPurpleAccent, size: 26),
            tooltip: '添加插件源',
            onPressed: _showAddPluginDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plugins.length,
              itemBuilder: (context, index) {
                final plugin = _plugins[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181C2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: plugin.isEnabled
                          ? Colors.deepPurpleAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: plugin.type == PluginType.m3u
                            ? Colors.pinkAccent.withOpacity(0.15)
                            : plugin.type == PluginType.json
                                ? Colors.cyanAccent.withOpacity(0.15)
                                : Colors.amberAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        plugin.type == PluginType.m3u
                            ? Icons.live_tv_rounded
                            : plugin.type == PluginType.json
                                ? Icons.data_object_rounded
                                : Icons.language_rounded,
                        color: plugin.type == PluginType.m3u
                            ? Colors.pinkAccent
                            : plugin.type == PluginType.json
                                ? Colors.cyanAccent
                                : Colors.amberAccent,
                        size: 24,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            plugin.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plugin.type.name.toUpperCase(),
                            style: const TextStyle(color: Colors.white60, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          plugin.description.isNotEmpty ? plugin.description : plugin.url,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plugin.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white30, fontSize: 10),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.deepPurpleAccent),
                          tooltip: '测试/运行',
                          onPressed: () => _testPlayUrl(plugin),
                        ),
                        Switch(
                          value: plugin.isEnabled,
                          activeColor: Colors.deepPurpleAccent,
                          onChanged: (val) {
                            setState(() {
                              plugin.isEnabled = val;
                            });
                            _savePlugins();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
