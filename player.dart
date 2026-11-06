import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final Map<String, String> streams;
  final String? localPath;

  const PlayerPage({
    super.key,
    required this.title,
    this.streams = const {},
    this.localPath,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  VideoPlayerController? _c;
  String _quality = '';
  double _speed = 1.0;
  bool _show = true;
  bool _error = false;
  Timer? _hide;
  double? _drag;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    if (widget.streams.isNotEmpty) {
      _quality = widget.streams.containsKey('720p')
          ? '720p'
          : widget.streams.keys.first;
    }
    _open();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _open({Duration start = Duration.zero}) async {
    final local = widget.localPath;
    final url = widget.streams[_quality];
    if (local == null && url == null) {
      setState(() => _error = true);
      return;
    }
    setState(() => _error = false);
    final old = _c;
    final c = local != null
        ? VideoPlayerController.file(File(local))
        : VideoPlayerController.networkUrl(Uri.parse(url!));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setPlaybackSpeed(_speed);
      if (start > Duration.zero) await c.seekTo(start);
      await c.play();
      setState(() => _c = c);
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      _autoHide();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _error = true);
    }
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) {
        setState(() => _show = false);
      }
    });
  }

  void _toggle() {
    setState(() => _show = !_show);
    if (_show) _autoHide();
  }

  void _skip(int seconds) {
    final c = _c;
    if (c == null) return;
    final t = c.value.position + Duration(seconds: seconds);
    final max = c.value.duration;
    c.seekTo(t < Duration.zero ? Duration.zero : (t > max ? max : t));
    setState(() => _show = true);
    _autoHide();
  }

  void _playPause(VideoPlayerController c) {
    c.value.isPlaying ? c.pause() : c.play();
    _autoHide();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (c != null)
          Center(
            child: AspectRatio(
                aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          ),
        if (c == null && !_error)
          const Center(child: CircularProgressIndicator(color: kOrange)),
        if (_error)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: kBlue),
              const SizedBox(height: 8),
              const Text('ভিডিও চালানো যায়নি'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => _open(), child: const Text('আবার চেষ্টা')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back')),
            ]),
          ),
        Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTap: () => _skip(-10),
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTap: () => _skip(10),
              child: const SizedBox.expand(),
            ),
          ),
        ]),
        if (c != null)
          IgnorePointer(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) => v.isBuffering
                  ? const Center(
                      child: CircularProgressIndicator(color: kOrange))
                  : const SizedBox.shrink(),
            ),
          ),
        if (c != null)
          IgnorePointer(
            ignoring: !_show,
            child: AnimatedOpacity(
              opacity: _show ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _controls(c),
            ),
          ),
      ]),
    );
  }

  Widget _controls(VideoPlayerController c) {
    final canPickQuality = widget.localPath == null && widget.streams.length > 1;
    return Stack(children: [
      // Top bar
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (canPickQuality)
              PopupMenuButton<String>(
                tooltip: 'Quality',
                initialValue: _quality,
                icon: const Icon(Icons.hd_rounded, color: kBlue),
                onSelected: (q) {
                  if (q == _quality) return;
                  final pos = _c?.value.position ?? Duration.zero;
                  setState(() => _quality = q);
                  _open(start: pos);
                },
                itemBuilder: (_) => [
                  for (final q in widget.streams.keys)
                    PopupMenuItem<String>(value: q, child: Text(q)),
                ],
              ),
            PopupMenuButton<double>(
              tooltip: 'Speed',
              initialValue: _speed,
              onSelected: (s) {
                _c?.setPlaybackSpeed(s);
                setState(() => _speed = s);
              },
              itemBuilder: (_) => [
                for (final s in _speeds)
                  PopupMenuItem<double>(value: s, child: Text('${s}x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${_speed}x',
                    style: const TextStyle(
                        color: kBlue, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
      // Center buttons
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            iconSize: 44,
            icon: const Icon(Icons.replay_10_rounded),
            onPressed: () => _skip(-10),
          ),
          const SizedBox(width: 24),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, v, _) => IconButton(
              iconSize: 64,
              color: kOrange,
              icon: Icon(v.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded),
              onPressed: () => _playPause(c),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            iconSize: 44,
            icon: const Icon(Icons.forward_10_rounded),
            onPressed: () => _skip(10),
          ),
        ]),
      ),
      // Bottom bar
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, v, _) {
              final maxMs = v.duration.inMilliseconds > 0
                  ? v.duration.inMilliseconds.toDouble()
                  : 1.0;
              final posMs = (_drag ?? v.position.inMilliseconds.toDouble())
                  .clamp(0.0, maxMs)
                  .toDouble();
              return Row(children: [
                Text(_fmt(Duration(milliseconds: posMs.toInt())),
                    style: const TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: posMs,
                    max: maxMs,
                    activeColor: kOrange,
                    inactiveColor: Colors.white24,
                    onChanged: (x) => setState(() => _drag = x),
                    onChangeEnd: (x) {
                      c.seekTo(Duration(milliseconds: x.toInt()));
                      setState(() => _drag = null);
                      _autoHide();
                    },
                  ),
                ),
                Text(_fmt(v.duration), style: const TextStyle(fontSize: 12)),
              ]);
            },
          ),
        ),
      ),
    ]);
  }
}
