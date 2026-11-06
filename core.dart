import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const kOrange = Color(0xFFFF7A00);
const kBlue = Color(0xFF00B4FF);
const kBg = Color(0xFF0A0A0A);
const kCard = Color(0xFF181818);

const tmdbKey = String.fromEnvironment('TMDB_KEY');
const imgBase = 'https://image.tmdb.org/t/p/';

Future<Map<String, dynamic>> tmdb(String path,
    [Map<String, String> q = const {}]) async {
  final uri = Uri.https('api.themoviedb.org', '/3$path',
      {'api_key': tmdbKey, 'language': 'en-US', ...q});
  final r = await http.get(uri);
  if (r.statusCode != 200) {
    throw Exception('TMDB error ${r.statusCode}');
  }
  return json.decode(r.body) as Map<String, dynamic>;
}

class Movie {
  final int id;
  final String title;
  final String? poster;
  final String? backdrop;
  final double rating;
  final String year;
  final String overview;

  Movie({
    required this.id,
    required this.title,
    required this.poster,
    required this.backdrop,
    required this.rating,
    required this.year,
    required this.overview,
  });

  factory Movie.fromJson(Map<String, dynamic> j) {
    final date = (j['release_date'] ?? '') as String;
    return Movie(
      id: j['id'] as int,
      title: (j['title'] ?? j['name'] ?? '') as String,
      poster: j['poster_path'] as String?,
      backdrop: j['backdrop_path'] as String?,
      rating: ((j['vote_average'] ?? 0) as num).toDouble(),
      year: date.length >= 4 ? date.substring(0, 4) : '',
      overview: (j['overview'] ?? '') as String,
    );
  }
}

Future<List<Movie>> fetchMovies(String path,
    [Map<String, String> q = const {}]) async {
  final d = await tmdb(path, q);
  return (d['results'] as List)
      .map((e) => Movie.fromJson(e as Map<String, dynamic>))
      .where((m) => m.poster != null)
      .toList();
}
