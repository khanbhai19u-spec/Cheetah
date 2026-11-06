import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'core.dart';
import 'detail.dart';
import 'downloads.dart';
import 'update.dart';

// ---------------------------------------------------------------- App

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DownloadManager.I.init();
  runApp(const CheetahApp());
}

class CheetahApp extends StatelessWidget {
  const CheetahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheetah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kOrange,
          secondary: kBlue,
          surface: kBg,
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: kBg, surfaceTintColor: Colors.transparent),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF111111),
          indicatorColor: kOrange.withOpacity(0.25),
        ),
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Shell()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset('logo.png', width: 170),
              ),
              const SizedBox(height: 20),
              const Text('CHEETAH',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: kOrange)),
            ],
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => checkForUpdate(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: const [
        HomePage(),
        SearchPage(),
        DownloadsPage(),
        PlaceholderPage(
            icon: Icons.person_rounded, text: 'প্রোফাইল শীঘ্রই আসছে'),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.download_rounded), label: 'Downloads'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String text;
  const PlaceholderPage({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: kBlue),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Home

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<List<Movie>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Future.wait([
      fetchMovies('/trending/movie/week'),
      fetchMovies('/movie/popular'),
      fetchMovies('/movie/top_rated'),
      fetchMovies('/movie/upcoming'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Movie>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: kBlue),
                const SizedBox(height: 12),
                Text(
                  tmdbKey.isEmpty
                      ? 'TMDB API Key সেট করা নেই'
                      : 'ডেটা লোড হয়নি। ইন্টারনেট চেক করো।',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('আবার চেষ্টা')),
              ]),
            ),
          );
        }
        final d = snap.data!;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Banner2(movies: d[0].take(6).toList()),
            Section(title: 'Trending Now', movies: d[0]),
            Section(title: 'Popular', movies: d[1]),
            Section(title: 'Top Rated', movies: d[2]),
            Section(title: 'Coming Soon', movies: d[3]),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class Banner2 extends StatelessWidget {
  final List<Movie> movies;
  const Banner2({super.key, required this.movies});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 460,
      child: PageView.builder(
        itemCount: movies.length,
        itemBuilder: (context, i) {
          final m = movies[i];
          return GestureDetector(
            onTap: () => openDetails(context, m),
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: '${imgBase}w780${m.poster}',
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: kCard),
                errorWidget: (c, u, e) => Container(color: kCard),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black38, Colors.transparent, kBg],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.star_rounded, color: kOrange, size: 18),
                        const SizedBox(width: 4),
                        Text(m.rating.toStringAsFixed(1)),
                        const SizedBox(width: 12),
                        Text(m.year,
                            style: const TextStyle(color: Colors.white70)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        FilledButton.icon(
                          onPressed: () => openDetails(context, m),
                          style: FilledButton.styleFrom(
                              backgroundColor: kOrange,
                              foregroundColor: Colors.black),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => openDetails(context, m),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: kBlue,
                              side: const BorderSide(color: kBlue)),
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const Text('Details'),
                        ),
                      ]),
                    ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  const Section({super.key, required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(children: [
          Container(width: 4, height: 18, color: kOrange),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: movies.length,
          separatorBuilder: (c, i) => const SizedBox(width: 12),
          itemBuilder: (c, i) => PosterCard(movie: movies[i], width: 132),
        ),
      ),
    ]);
  }
}

class PosterCard extends StatelessWidget {
  final Movie movie;
  final double? width;
  const PosterCard({super.key, required this.movie, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openDetails(context, movie),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: '${imgBase}w342${movie.poster}',
            fit: BoxFit.cover,
            placeholder: (c, u) => Container(color: kCard),
            errorWidget: (c, u, e) => Container(
                color: kCard, child: const Icon(Icons.movie_rounded)),
          ),
        ),
      ),
    );
  }
}

void openDetails(BuildContext context, Movie m) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => DetailsPage(movie: m)));
}

// ---------------------------------------------------------------- Search

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Movie> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(v));
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _query = q;
    });
    try {
      final r = await fetchMovies('/search/movie', {'query': q});
      if (!mounted) return;
      setState(() => _results = r);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'মুভি সার্চ করো...',
              prefixIcon: const Icon(Icons.search_rounded, color: kBlue),
              filled: true,
              fillColor: kCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kOrange))
              : _results.isEmpty
                  ? Center(
                      child: Text(
                          _query.isEmpty ? 'মুভির নাম লেখো' : 'কিছু পাওয়া যায়নি',
                          style: const TextStyle(color: Colors.white54)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (c, i) => PosterCard(movie: _results[i]),
                    ),
        ),
      ]),
    );
  }
}
