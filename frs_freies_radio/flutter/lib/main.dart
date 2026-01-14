import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const FrsApp());
}

const _accent = Color(0xFFFF6600);
const _streamUrl = 'https://streaming.fueralle.org/frs-hi.mp3';
const _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');

class FrsApp extends StatelessWidget {
  const FrsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freies Radio fuer Stuttgart',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0F1113),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const LiveTab(),
      const TodayTab(),
      const MediathekTab(),
      const MoreTab(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.headphones), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.today), label: 'Heute'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Mediathek'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mehr'),
        ],
      ),
    );
  }
}

class LiveTab extends StatefulWidget {
  const LiveTab({super.key});

  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> {
  final AudioPlayer _player = AudioPlayer();
  bool _stableStream = false;
  String _status = 'Gestoppt';
  String? _error;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      final processing = state.processingState;
      if (processing == ProcessingState.loading || processing == ProcessingState.buffering) {
        setState(() => _status = 'Puffert...');
      } else if (state.playing) {
        setState(() => _status = 'Live');
      } else {
        setState(() => _status = 'Gestoppt');
      }
    });
    _player.setVolume(_volume);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.stop();
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      await _player.setUrl(_streamUrl);
      if (_stableStream) {
        // Larger buffer strategy: wait for a minimum buffered position before play.
        await _waitForBuffer(const Duration(seconds: 12));
      }
      await _player.play();
    } catch (err) {
      setState(() {
        _error = 'Stream konnte nicht gestartet werden.';
      });
    }
  }

  Future<void> _waitForBuffer(Duration minimum) async {
    final completer = Completer<void>();
    late StreamSubscription<Duration> sub;
    sub = _player.bufferedPositionStream.listen((buffered) {
      if (buffered >= minimum && !completer.isCompleted) {
        completer.complete();
        sub.cancel();
      }
    });
    return completer.future.timeout(const Duration(seconds: 6), onTimeout: () {
      sub.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.headphones, size: 64, color: _accent),
                  const SizedBox(height: 10),
                  Text(_status, style: Theme.of(context).textTheme.titleLarge),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(_player.playing ? 'Pause' : 'Play'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Stabiler Stream'),
                      Switch(
                        value: _stableStream,
                        onChanged: (value) => setState(() => _stableStream = value),
                        activeColor: _accent,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            _player.setVolume(value);
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<MediathekItem>>(
                future: MediathekService().fetchToday(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Fehler beim Laden.'));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Keine Sendungen gefunden.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _MediathekCard(item: item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediathekTab extends StatelessWidget {
  const MediathekTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<MediathekDay>>(
                future: MediathekService().fetchWeek(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Fehler beim Laden.'));
                  }
                  final days = snapshot.data ?? [];
                  if (days.isEmpty) {
                    return const Center(child: Text('Keine Mediathek-Daten.'));
                  }
                  return ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(day.date, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          ...day.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MediathekCard(item: item),
                              )),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.freies-radio.de');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Website oeffnen'),
              onTap: _openWebsite,
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Impressum'),
              subtitle: Text('Platzhalter'),
            ),
            const ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('Datenschutz'),
              subtitle: Text('Platzhalter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/logo.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.radio, size: 36),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Freies Radio fuer Stuttgart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class MediathekItem {
  final String date;
  final String start;
  final String end;
  final String show;
  final String episode;
  final String? teaser;
  final String audioUrl;
  final bool audioAvailable;

  MediathekItem({
    required this.date,
    required this.start,
    required this.end,
    required this.show,
    required this.episode,
    required this.teaser,
    required this.audioUrl,
    required this.audioAvailable,
  });

  factory MediathekItem.fromJson(Map<String, dynamic> json) {
    return MediathekItem(
      date: json['date'] ?? '',
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      show: json['show'] ?? '',
      episode: json['episode'] ?? '',
      teaser: json['teaser'],
      audioUrl: json['audioUrl'] ?? '',
      audioAvailable: json['audioAvailable'] ?? false,
    );
  }
}

class MediathekDay {
  final String date;
  final List<MediathekItem> items;

  MediathekDay({required this.date, required this.items});

  factory MediathekDay.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((item) => MediathekItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return MediathekDay(date: json['date'] ?? '', items: items);
  }
}

class MediathekService {
  Future<List<MediathekItem>> fetchToday() async {
    final url = Uri.parse('$_apiBase/mediathek/today');
    final data = await _getJsonList(url);
    return data.map((item) => MediathekItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<MediathekDay>> fetchWeek() async {
    final url = Uri.parse('$_apiBase/mediathek/week');
    final data = await _getJsonList(url);
    return data.map((item) => MediathekDay.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<dynamic>> _getJsonList(Uri url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final resp = await http.get(url).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          return jsonDecode(resp.body) as List<dynamic>;
        }
      } catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 400));
          continue;
        }
      }
    }
    throw Exception('Request failed');
  }
}

class _MediathekCard extends StatelessWidget {
  final MediathekItem item;

  const _MediathekCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.start} - ${item.end}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(item.show, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (item.episode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.episode, style: const TextStyle(color: Colors.white70)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            color: _accent,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Play: ${item.show}')),
              );
            },
          ),
        ],
      ),
    );
  }
}
