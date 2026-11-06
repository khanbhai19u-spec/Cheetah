import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'core.dart';
import 'downloads.dart';
import 'player.dart';
import 'sources.dart';

class DetailsPage extends StatefulWidget {
  final Movie movie;
  const DetailsPage({super.key, required this.movie});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  late Future<Map<String, dynamic>> _future;
  late final VideoSource _src;

  @override
  void initState() {
    super.initState();
    _src = sourceFor(widget.movie);
    _future =
        tmdb('/movie/${widget.movie.id}', {'append_to_response': 'credits'});
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  void _play() {
    final m = widget.movie;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerPage(
        title: m.title,
        streams: _src.streams,
        localPath: DownloadManager.I.localPath(m.id),
      ),
    ));
  }

  void _download() {
    final m = widget.movie;
    final url = _src.download;
    if (url == null) {
      _msg('এই ভিডিও শুধু স্ট্রিম করা যাবে, ডাউনলোড নেই');
      return;
    }
    DownloadManager.I.start(m.id, m.title, m.poster, url);
    _msg('ডাউনলোড শুরু হয়েছে');
  }

  Widget _downloadButton() {
    return ListenableBuilder(
      listenable: DownloadManager.I,
      builder: (context, _) {
        final m = widget.movie;
        final it = DownloadManager.I.get(m.id);
        var label = 'Download';
        var icon = Icons.download_rounded;
        VoidCallback onTap = _download;
        if (it != null) {
          switch (it.status) {
            case DlStatus.downloading:
              label = '${(it.progress * 100).toInt()}%';
              icon = Icons.pause_rounded;
              onTap = () => DownloadManager.I.pause(m.id);
              break;
            case DlStatus.paused:
              label = 'Resume';
              icon = Icons.play_arrow_rounded;
              onTap = () => DownloadManager.I.resume(m.id);
              break;
            case DlStatus.failed:
              label = 'Retry';
              icon = Icons.refresh_rounded;
              onTap = () => DownloadManager.I.resume(m.id);
              break;
            case DlStatus.done:
              label = 'Downloaded';
              icon = Icons.check_circle_rounded;
              onTap = _play;
              break;
          }
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                foregroundColor: kBlue,
                side: const BorderSide(color: kBlue),
                minimumSize: const Size.fromHeight(48)),
            icon: Icon(icon),
            label: Text(label),
          ),
          if (it != null && it.status != DlStatus.done)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: it.total > 0 ? it.progress : null,
                color: kBlue,
                backgroundColor: kCard,
                minHeight: 3,
              ),
            ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final genres = d == null
              ? <String>[]
              : (d['genres'] as List)
                  .map((g) => (g['name'] ?? '') as String)
                  .toList();
          final runtime = d == null ? 0 : ((d['runtime'] ?? 0) as int);
          final cast = d == null
              ? <Map<String, dynamic>>[]
              : ((d['credits']?['cast'] ?? []) as List)
                  .take(12)
                  .map((e) => e as Map<String, dynamic>)
                  .toList();

          return ListView(padding: EdgeInsets.zero, children: [
            Stack(children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: '${imgBase}w780${m.backdrop ?? m.poster}',
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: kCard),
                  errorWidget: (c, u, e) => Container(color: kCard),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black45, Colors.transparent, kBg],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: kOrange, size: 18),
                      const SizedBox(width: 4),
                      Text(m.rating.toStringAsFixed(1)),
                      const SizedBox(width: 12),
                      Text(m.year,
                          style: const TextStyle(color: Colors.white70)),
                      if (runtime > 0) ...[
                        const SizedBox(width: 12),
                        Text('${runtime ~/ 60}h ${runtime % 60}m',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final g in genres)
                        Chip(
                          label: Text(g, style: const TextStyle(fontSize: 12)),
                          backgroundColor: kCard,
                          side: const BorderSide(color: kBlue),
                          visualDensity: VisualDensity.compact,
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _play,
                              style: FilledButton.styleFrom(
                                  backgroundColor: kOrange,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(48)),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _downloadButton()),
                        ]),
                    if (_src.demo)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                            'ডেমো ভিডিও (টেস্ট লিংক) — নিজের লিংক sources.dart-এ বসাও',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                    const SizedBox(height: 20),
                    const Text('Story',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(m.overview.isEmpty ? '—' : m.overview,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.5)),
                    if (cast.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Cast',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: cast.length,
                          separatorBuilder: (c, i) => const SizedBox(width: 14),
                          itemBuilder: (c, i) {
                            final p = cast[i]['profile_path'] as String?;
                            return SizedBox(
                              width: 70,
                              child: Column(children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: kCard,
                                  backgroundImage: p == null
                                      ? null
                                      : CachedNetworkImageProvider(
                                          '${imgBase}w185$p'),
                                  child: p == null
                                      ? const Icon(Icons.person_rounded)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text((cast[i]['name'] ?? '') as String,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11)),
                              ]),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ]),
            ),
          ]);
        },
      ),
    );
  }
}
