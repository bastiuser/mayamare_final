// lib/services/media_cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CachedMedia {
  final int id;
  final String url;
  final String localPath; // absoluter Datei-Pfad

  CachedMedia({required this.id, required this.url, required this.localPath});

  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'localPath': localPath};

  static CachedMedia fromJson(Map<String, dynamic> m) => CachedMedia(
        id: m['id'] as int,
        url: m['url'] as String,
        localPath: m['localPath'] as String,
      );
}

/// Verwaltet Download, Manifest und Pfadauflösung für Videos/Audios.
class MediaCacheService {
  MediaCacheService({required this.cookie});
  final String cookie;

  static const _manifestFileName = 'manifest.json';
  static const _videosDirName = 'videos';
  static const _audiosDirName = 'audios';

  late Directory _root;
  late Directory _videosDir;
  late Directory _audiosDir;
  Map<String, dynamic> _manifest = {
    'videos': <Map<String, dynamic>>[],
    'audios': <Map<String, dynamic>>[],
  };

  Future<void> _ensureDirs() async {
    final base = await getApplicationDocumentsDirectory();
    _root = Directory('${base.path}/media_cache');
    _videosDir = Directory('${_root.path}/$_videosDirName');
    _audiosDir = Directory('${_root.path}/$_audiosDirName');
    if (!await _root.exists()) await _root.create(recursive: true);
    if (!await _videosDir.exists()) await _videosDir.create(recursive: true);
    if (!await _audiosDir.exists()) await _audiosDir.create(recursive: true);
  }

  Future<void> _readManifest() async {
    await _ensureDirs();
    final f = File('${_root.path}/$_manifestFileName');
    if (await f.exists()) {
      try {
        _manifest = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        _manifest = {'videos': <Map<String, dynamic>>[], 'audios': <Map<String, dynamic>>[]};
      }
    }
  }

  Future<void> _writeManifest() async {
    final f = File('${_root.path}/$_manifestFileName');
    await f.writeAsString(jsonEncode(_manifest));
  }

  Future<List<CachedMedia>> getCachedVideos() async {
    await _readManifest();
    final list = (_manifest['videos'] as List).cast<Map<String, dynamic>>();
    return list.map(CachedMedia.fromJson).toList();
  }

  Future<List<CachedMedia>> getCachedAudios() async {
    await _readManifest();
    final list = (_manifest['audios'] as List).cast<Map<String, dynamic>>();
    return list.map(CachedMedia.fromJson).toList();
  }

  /// Öffentliche API: nach Login aufrufen. Holt Listen + lädt fehlende Dateien.
  Future<void> syncAll() async {
    await _readManifest();
    await Future.wait([
      _syncCategory(
        listEndpoint: 'https://waterslide.works/app/videolist',
        targetDir: _videosDir,
        manifestKey: 'videos',
      ),
      _syncCategory(
        listEndpoint: 'https://waterslide.works/app/audiolist',
        targetDir: _audiosDir,
        manifestKey: 'audios',
      ),
    ]);
    await _writeManifest();
  }

  /// Liefert lokalen Pfad, wenn vorhanden – sonst null.
  Future<String?> resolveLocalPath({required String manifestKey, required int id, required String url}) async {
    await _readManifest();
    final list = (_manifest[manifestKey] as List).cast<Map<String, dynamic>>();
    final hit = list.cast<Map<String, dynamic>>().firstWhere(
      (m) => m['id'] == id && m['url'] == url,
      orElse: () => {},
    );
    if (hit.isEmpty) return null;
    final path = hit['localPath'] as String?;
    if (path == null) return null;
    return await File(path).exists() ? path : null;
  }

  /// ---------------- intern ----------------
  Future<void> _syncCategory({
    required String listEndpoint,
    required Directory targetDir,
    required String manifestKey,
  }) async {
    final resp = await http.get(
      Uri.parse(listEndpoint),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cookie': cookie,
      },
    );
    if (resp.statusCode != 200) {
      debugPrint('Media list error ($listEndpoint): HTTP ${resp.statusCode}');
      return;
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return;
    final data = decoded['data'];
    if (data is! List) return;

    // Manifestliste vorbereiten
    final manifestList = (_manifest[manifestKey] as List).cast<Map<String, dynamic>>();

    // Für jede Ressource prüfen, ob sie schon lokal existiert.
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'] is int ? raw['id'] as int : int.parse('${raw['id']}');
      final url = raw['url'] as String;
      final existingIndex = manifestList.indexWhere((m) => m['id'] == id && m['url'] == url);

      // Dateiname aus URL ableiten (id + ext), z.B. 123.mp4 / 42.mp3
      final fileName = _safeFileName(id, url);
      final file = File('${targetDir.path}/$fileName');

      final exists = await file.exists();
      if (!exists) {
        await _downloadToFile(url: url, outFile: file);
      }

      if (await file.exists()) {
        final entry = {
          'id': id,
          'url': url,
          'localPath': file.path,
        };
        if (existingIndex >= 0) {
          manifestList[existingIndex] = entry;
        } else {
          manifestList.add(entry);
        }
      }
    }

    // Optional: verwaiste Dateien lokal löschen (die nicht mehr in der Liste sind)
    final keepNames = manifestList
        .map((m) => _safeFileName(m['id'] as int, m['url'] as String))
        .toSet();
    for (final f in targetDir.listSync().whereType<File>()) {
      if (!keepNames.contains(f.uri.pathSegments.last)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _manifest[manifestKey] = manifestList;
  }

  Future<void> _downloadToFile({required String url, required File outFile}) async {
    debugPrint('Downloading $url -> ${outFile.path}');
    final req = http.Request('GET', Uri.parse(url));
    req.headers['Cookie'] = cookie; // wichtig falls nötig
    final streamed = await req.send();

    if (streamed.statusCode != 200) {
      debugPrint('Download failed $url : ${streamed.statusCode}');
      return;
    }
    final sink = outFile.openWrite();
    await streamed.stream.pipe(sink);
    await sink.close();
  }

  String _safeFileName(int id, String url) {
    final last = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : 'file';
    final dot = last.lastIndexOf('.');
    final ext = (dot >= 0 && dot < last.length - 1) ? last.substring(dot) : '';
    return '$id$ext';
  }
}