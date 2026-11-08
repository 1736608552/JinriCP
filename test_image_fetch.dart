import 'dart:io';

void main() async {
  final url = 'https://pic.eanfog.cn/upload_01/upload/20260808/2026080817531451281.jpg?auth_key=1788318215-0-0-c26aff615471ccd1651bfe23dc9bd7f4';
  
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => true;
  
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14; Mobile)');
    req.headers.set('Referer', 'https://huangguoai.com/');
    
    final res = await req.close();
    print('Status: \${res.statusCode}');
    
    final bytes = <int>[];
    await for (final chunk in res) {
      bytes.addAll(chunk);
    }
    print('Length: \${bytes.length}');
    if (bytes.length > 10) {
      print('First 10 bytes: \${bytes.take(10).toList()}');
    }
  } catch (e) {
    print('Error: \$e');
  }
}
