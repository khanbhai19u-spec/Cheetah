import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core.dart';

/// app.config থেকে GITHUB_REPO পড়ে (যেমন: username/cheetah)
Future<String?> _readRepo() async {
  try {
    final t = await rootBundle.loadString('app.config');
    for (final line in t.split('\n')) {
      final l = line.trim();
      if (l.startsWith('GITHUB_REPO=')) {
        return l.substring('GITHUB_REPO='.length).replaceAll('"', '').trim();
      }
    }
  } catch (_) {}
  return null;
}

List<int> _parts(String v) => v
    .replaceAll(RegExp(r'[^0-9.]'), '')
    .split('.')
    .where((e) => e.isNotEmpty)
    .map((e) => int.tryParse(e) ?? 0)
    .toList();

bool _isNewer(String latest, String current) {
  final a = _parts(latest);
  final b = _parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// GitHub Releases-এ নতুন ভার্সন থাকলে আপডেট ডায়ালগ দেখায়
Future<void> checkForUpdate(BuildContext context) async {
  try {
    final repo = await _readRepo();
    if (repo == null || repo.isEmpty || repo.contains('YOUR_GITHUB')) return;

    final info = await PackageInfo.fromPlatform();
    final r = await http.get(
      Uri.https('api.github.com', '/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (r.statusCode != 200) return;

    final j = json.decode(r.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '') as String;
    if (!_isNewer(tag, info.version)) return;

    String? apkUrl;
    for (final a in (j['assets'] as List? ?? [])) {
      final name = (a['name'] ?? '') as String;
      if (name.endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null || !context.mounted) return;
    final url = apkUrl;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('নতুন ভার্সন এসেছে'),
        content: Text('Cheetah $tag পাওয়া যাচ্ছে।\nতোমার ভার্সন: ${info.version}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('পরে')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kOrange, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('আপডেট করো'),
          ),
        ],
      ),
    );
  } catch (_) {}
}
