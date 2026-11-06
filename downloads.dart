import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core.dart';
import 'player.dart';

enum DlStatus { downloading, paused, done, failed }

class DownloadItem {
  final int id;
  final String title;
  final String? poster;
  final String url;
  final String fileName;
  int received;
  int total;
  DlStatus status;

  DownloadItem({
    required this.id,
    required this.title,
    required this.poster,
    required this.url,
    required this.fileName,
    this.received = 0,
    this.total = 0,
    this.status = DlStatus.paused,
  });

  double get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'poster': poster,
        'url': url,
        'fileName': fileName,
        'received': received,
        'total': total,
        'status': status.index,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        id: j['id'] as int,
        title: j['title'] as String,
        poster: j['poster'] as String?,
        url: j['url'] as String,
        fileName: j['fileName'] as String,
        received: (j['received'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        status: DlStatus.values[(j['status'] ?? 1) as int],
      );
}

String fmtBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager I = DownloadManager._();

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));
  final Map<int, DownloadItem> items = {};
  final Map<int, CancelToken> _tokens = {};
  late Directory _dir;
  SharedPreferences? _prefs;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    _dir = Directory('${base.path}/downloads');
    if (!await _dir.exists()) await _dir.create(recursive: true);
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('downloads');
    if (raw != null) {
      for (final e in json.decode(raw) as List) {
        final it = DownloadItem.fromJson(e as Map<String, dynamic>);
        if (it.status == DlStatus.downloading) it.status = DlStatus.paused;
        items[it.id] = it;
      }
    }
  }

  List<DownloadItem> get list => items.values.toList().reversed.toList();

  DownloadItem? get(int id) => items[id];

  String pathOf(DownloadItem it) => '${_dir.path}/${it.fileName}';

  /// ডাউনলোড শেষ হলে লোকাল ফাইলের পাথ, নাহলে null
  String? localPath(int id) {
    final it = items[id];
    if (it == null || it.status != DlStatus.done) return null;
    final p = pathOf(it);
    return File(p).existsSync() ? p : null;
  }

  Future<void> _save() async {
    await _prefs?.setString(
        'downloads', json.encode(items.values.map((e) => e.toJson()).toList()));
  }

  void start(int id, String title, String? poster, String url) {
    final existing = items[id];
    if (existing != null) {
      if (existing.status == DlStatus.paused ||
          existing.status == DlStatus.failed) {
        resume(id);
      }
      return;
    }
    final it = DownloadItem(
      id: id,
      title: title,
      poster: poster,
      url: url,
      fileName: 'movie_$id.mp4',
      status: DlStatus.downloading,
    );
    items[id] = it;
    notifyListeners();
    _run(it);
  }

  void pause(int id) => _tokens[id]?.cancel('pause');

  void resume(int id) {
    final it = items[id];
    if (it == null ||
        it.status == DlStatus.downloading ||
        it.status == DlStatus.done) {
      return;
    }
    _run(it);
  }

  Future<void> remove(int id) async {
    final it = items.remove(id);
    _tokens[id]?.cancel('remove');
    _tokens.remove(id);
    if (it != null) {
      try {
        final f = File(pathOf(it));
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _save();
    notifyListeners();
  }

  Future<void> _run(DownloadItem it) async {
    final file = File(pathOf(it));
    var existing = await file.exists() ? await file.length() : 0;

    if (it.total > 0 && existing >= it.total) {
      it.received = existing;
      it.status = DlStatus.done;
      await _save();
      notifyListeners();
      return;
    }

    final token = CancelToken();
    _tokens[it.id] = token;
    it.status = DlStatus.downloading;
    notifyListeners();

    try {
      final res = await _dio.get<ResponseBody>(
        it.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: existing > 0 ? {'range': 'bytes=$existing-'} : null,
          validateStatus: (s) => s == 200 || s == 206,
        ),
      );
      final partial = res.statusCode == 206;
      if (!partial) existing = 0;
      final len =
          int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '') ??
              0;
      it.total = len > 0 ? existing + len : 0;
      it.received = existing;

      final sink =
          file.openWrite(mode: partial ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in res.data!.stream) {
          sink.add(chunk);
          it.received += chunk.length;
          final now = DateTime.now();
          if (now.difference(_lastNotify).inMilliseconds > 300) {
            _lastNotify = now;
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (it.total > 0 && it.received < it.total) {
        it.status = DlStatus.paused; // নেট কেটে গেছে, Resume করা যাবে
      } else {
        it.status = DlStatus.done;
      }
    } catch (_) {
      it.status = token.isCancelled ? DlStatus.paused : DlStatus.failed;
    }
    _tokens.remove(it.id);
    await _save();
    notifyListeners();
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: DownloadManager.I,
        builder: (context, _) {
          final list = DownloadManager.I.list;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Downloads',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.download_rounded, size: 64, color: kBlue),
                        SizedBox(height: 12),
                        Text('কোনো ডাউনলোড নেই',
                            style: TextStyle(color: Colors.white70)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (c, i) => _DlTile(item: list[i]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _DlTile extends StatelessWidget {
  final DownloadItem item;
  const _DlTile({required this.item});

  String _statusText() {
    final r = fmtBytes(item.received);
    final t = item.total > 0 ? fmtBytes(item.total) : '?';
    switch (item.status) {
      case DlStatus.downloading:
        return 'Downloading • $r / $t';
      case DlStatus.paused:
        return 'Paused • $r / $t';
      case DlStatus.failed:
        return 'Failed • Resume চাপো';
      case DlStatus.done:
        return 'Downloaded • ${fmtBytes(item.received)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mgr = DownloadManager.I;
    final done = item.status == DlStatus.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: done
              ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerPage(
                      title: item.title, localPath: mgr.pathOf(item))))
              : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 84,
                  child: item.poster == null
                      ? Container(color: kBg)
                      : CachedNetworkImage(
                          imageUrl: '${imgBase}w185${item.poster}',
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => Container(color: kBg),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(_statusText(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                      if (!done) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.total > 0 ? item.progress : null,
                          color: kBlue,
                          backgroundColor: Colors.white12,
                          minHeight: 4,
                        ),
                      ],
                    ]),
              ),
              if (item.status == DlStatus.downloading)
                IconButton(
                    icon: const Icon(Icons.pause_circle_rounded, color: kOrange),
                    onPressed: () => mgr.pause(item.id)),
              if (item.status == DlStatus.paused ||
                  item.status == DlStatus.failed)
                IconButton(
                    icon: const Icon(Icons.play_circle_rounded, color: kOrange),
                    onPressed: () => mgr.resume(item.id)),
              if (done)
                const Icon(Icons.play_circle_fill_rounded,
                    color: kBlue, size: 30),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white54),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ডিলিট করবে?'),
                      content: Text(item.title),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('না')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('হ্যাঁ')),
                      ],
                    ),
                  );
                  if (ok == true) mgr.remove(item.id);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
