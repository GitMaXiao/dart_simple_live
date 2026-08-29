import 'dart:convert';
import 'dart:io';

Future<dynamic> getJson(String url, {Map<String, String>? headers}) async {
  var client = HttpClient();
  var uri = Uri.parse(url);
  var req = await client.getUrl(uri);
  req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  if (headers != null) {
    headers.forEach((k, v) => req.headers.set(k, v));
  }
  var res = await req.close();
  var body = await res.transform(utf8.decoder).join();
  try {
    return json.decode(body);
  } catch (e) {
    return body;
  }
}

void main() async {
  var hashId = '2V0JMV1lrpa7RY5k';
  var pageHtml = await getJson(
    'https://v.douyu.com/show/$hashId',
    headers: {
      'referer': 'https://v.douyu.com',
    },
  );
  if (pageHtml is String) {
    var match = RegExp(r'window\.\$DATA\s*=\s*(\{.*?\});\s*(?:window|\n|<)', dotAll: true).firstMatch(pageHtml);
    if (match != null) {
      print('--- \$DATA matched ---');
      print(match.group(1));
    }
  }
}

