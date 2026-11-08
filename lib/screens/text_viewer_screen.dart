import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';

class TextViewerScreen extends StatefulWidget {
  final String title;
  final String url;
  final ApiService apiService;

  const TextViewerScreen({
    super.key,
    required this.title,
    required this.url,
    required this.apiService,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  Future<void> _loadText() async {
    final text = await widget.apiService.fetchRawText(widget.url);
    if (mounted) {
      setState(() {
        _content = text;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? Center(
              child: SpinKitCircle(color: theme.colorScheme.primary, size: 40),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content,
                style: const TextStyle(fontSize: 14, height: 1.6, fontFamily: 'monospace'),
              ),
            ),
    );
  }
}
