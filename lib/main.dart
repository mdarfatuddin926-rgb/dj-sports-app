import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with D.J. Sports Project URL
  await Supabase.initialize(
    url: 'https://drpafmeyvgysqvhdprmy.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_PUBLIC_KEY',
  );

  runApp(const DJSportsApp());
}

class DJSportsApp extends StatelessWidget {
  const DJSportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D.J. Sports',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF16A34A),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF131B2E),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const LiveMatchesScreen(),
    );
  }
}

/// Data model representing a row in the 'matches' Supabase table
class SportsMatch {
  final int id;
  final String teamA;
  final String teamB;
  final String flagA;
  final String flagB;
  final String status;
  final String category;
  final String streamUrl;

  const SportsMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.flagA,
    required this.flagB,
    required this.status,
    required this.category,
    required this.streamUrl,
  });

  factory SportsMatch.fromMap(Map<String, dynamic> map) {
    return SportsMatch(
      id: (map['id'] as num?)?.toInt() ?? 0,
      teamA: (map['team_a'] ?? 'Team A').toString(),
      teamB: (map['team_b'] ?? 'Team B').toString(),
      flagA: (map['flag_a'] ?? '').toString(),
      flagB: (map['flag_b'] ?? '').toString(),
      status: (map['status'] ?? 'LIVE').toString().toUpperCase(),
      category: (map['category'] ?? 'Sports').toString(),
      streamUrl: (map['stream_url'] ?? '').toString(),
    );
  }
}

class LiveMatchesScreen extends StatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Cricket',
    'Football',
    'Tennis',
    'Basketball',
  ];

  /// Fetches live match details from the 'matches' table
  Future<List<SportsMatch>> _fetchMatches() async {
    final response = await _supabase
        .from('matches')
        .select('id, team_a, team_b, flag_a, flag_b, status, category, stream_url')
        .order('id', ascending: true);

    final List<dynamic> rows = response as List<dynamic>;
    return rows
        .map((row) => SportsMatch.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'D.J.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'D.J. Sports IPTV',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Matches',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Bar
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                  },
                  selectedColor: const Color(0xFF16A34A),
                  backgroundColor: const Color(0xFF131B2E),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              },
            ),
          ),

          // Matches List from Supabase 'matches' table
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('matches')
                  .stream(primaryKey: ['id'])
                  .order('id', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final allMatches = (snapshot.data ?? [])
                    .map((row) => SportsMatch.fromMap(row))
                    .toList();

                final filteredMatches = _selectedCategory == 'All'
                    ? allMatches
                    : allMatches
                        .where((m) =>
                            m.category.toLowerCase() ==
                            _selectedCategory.toLowerCase())
                        .toList();

                if (filteredMatches.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matches found in this category.',
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF16A34A),
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMatches.length,
                    itemBuilder: (context, index) {
                      final match = filteredMatches[index];
                      return MatchCard(
                        match: match,
                        onWatchTap: () => _openStream(context, match),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load matches from Supabase',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  void _openStream(BuildContext context, SportsMatch match) {
    if (match.streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream link is not available yet.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StreamPlayerScreen(match: match),
      ),
    );
  }
}

/// Clean UI Card Layout for displaying each match
class MatchCard extends StatelessWidget {
  final SportsMatch match;
  final VoidCallback onWatchTap;

  const MatchCard({
    super.key,
    required this.match,
    required this.onWatchTap,
  });

  bool get _isLive => match.status.toUpperCase() == 'LIVE';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLive
              ? const Color(0xFF16A34A).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onWatchTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top row: Category & Match Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    match.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  _StatusBadge(status: match.status),
                ],
              ),
              const SizedBox(height: 18),

              // Middle row: Team A vs Team B with Flag URLs
              Row(
                children: [
                  Expanded(
                    child: _TeamColumn(
                      teamName: match.teamA,
                      flagUrl: match.flagA,
                      alignEnd: false,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F17),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TeamColumn(
                      teamName: match.teamB,
                      flagUrl: match.flagB,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bottom row: Stream URL indicator & Watch Live CTA
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        match.streamUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: onWatchTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isLive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        _isLive ? 'Watch Live' : 'Open Stream',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String teamName;
  final String flagUrl;
  final bool alignEnd;

  const _TeamColumn({
    required this.teamName,
    required this.flagUrl,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: flagUrl,
            width: 48,
            height: 32,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 48,
              height: 32,
              color: const Color(0xFF1E293B),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 48,
              height: 32,
              color: const Color(0xFF1E293B),
              alignment: Alignment.center,
              child: const Icon(Icons.flag_rounded, size: 18, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status.toUpperCase() == 'LIVE';
    final isUpcoming = status.toUpperCase() == 'UPCOMING';

    final Color badgeColor = isLive
        ? const Color(0xFF16A34A)
        : isUpcoming
            ? const Color(0xFFD97706)
            : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Dedicated IPTV Stream Player Screen supporting HLS (.m3u8) & MP4 links
class StreamPlayerScreen extends StatefulWidget {
  final SportsMatch match;

  const StreamPlayerScreen({super.key, required this.match});

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.match.streamUrl),
      );
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        isLive: widget.match.status.toUpperCase() == 'LIVE',
        aspectRatio: _videoController.value.aspectRatio,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F17),
        title: Text('${widget.match.teamA} vs ${widget.match.teamB}'),
      ),
      body: Center(
        child: _hasError
            ? Text(
                'Could not play stream:\n${widget.match.streamUrl}',
                textAlign: TextAlign.center,
              )
            : _chewieController != null &&
                    _videoController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : const CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
    );
  }
}
