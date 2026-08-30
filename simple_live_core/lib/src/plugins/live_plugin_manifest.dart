import 'dart:convert';

enum LivePluginType {
  js,
  dsl,
}

class LivePluginManifest {
  final String id;
  final String name;
  final String version;
  final LivePluginType type;
  final String author;
  final String description;
  final String? icon;
  final String entry;
  final String? updateUrl;
  final String? homepage;
  final String? minAppVersion;
  final List<String> permissions;
  
  /// In-memory or loaded rule/script content
  String? scriptContent;

  LivePluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    this.author = '',
    this.description = '',
    this.icon,
    this.entry = 'index.js',
    this.updateUrl,
    this.homepage,
    this.minAppVersion,
    this.permissions = const [],
    this.scriptContent,
  });

  factory LivePluginManifest.fromJson(Map<String, dynamic> json) {
    var typeStr = json['type']?.toString().toLowerCase() ?? 'js';
    var type = typeStr == 'dsl' ? LivePluginType.dsl : LivePluginType.js;

    List<String> perms = [];
    if (json['permissions'] is List) {
      perms = (json['permissions'] as List).map((e) => e.toString()).toList();
    }

    return LivePluginManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0.0',
      type: type,
      author: json['author']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString(),
      entry: json['entry']?.toString() ?? (type == LivePluginType.dsl ? 'rules.json' : 'index.js'),
      updateUrl: json['updateUrl']?.toString(),
      homepage: json['homepage']?.toString(),
      minAppVersion: json['minAppVersion']?.toString(),
      permissions: perms,
      scriptContent: json['scriptContent']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'type': type == LivePluginType.dsl ? 'dsl' : 'js',
      'author': author,
      'description': description,
      if (icon != null) 'icon': icon,
      'entry': entry,
      if (updateUrl != null) 'updateUrl': updateUrl,
      if (homepage != null) 'homepage': homepage,
      if (minAppVersion != null) 'minAppVersion': minAppVersion,
      'permissions': permissions,
      if (scriptContent != null) 'scriptContent': scriptContent,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

