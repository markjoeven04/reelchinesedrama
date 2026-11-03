import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/layout.dart';
import '../../app/router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../data/drama_repository.dart';
import '../../widgets/common.dart';
import '../drama/drama_screen.dart';

class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key, required this.dramaKey, this.episode});

  final String dramaKey;
  final int? episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dramaProvider(dramaKey))
      .when(
        loading: () => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 14)),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: MessageView(icon: CupertinoIcons.exclamationmark_triangle, title: 'Error', message: '$e'),
        ),
        data: (d) => d == null || (episode != null && d.episode(episode!) == null)
            ? const NotFoundScreen()
            : PlayerView(drama: d, initialEpisode: episode),
      );
}

/// Picks the source for [server]/[quality], falling back to the first server and preferred quality.
VideoSource pickSource(Episode ep, {String? server, String? quality, String preferredQuality = '480p'}) {
  final s = ep.servers.contains(server) ? server : ep.servers.first;
  final candidates = ep.sources.where((v) => v.server == s).toList();
  return candidates.where((v) => v.quality == quality).firstOrNull ??
      candidates.where((v) => v.quality == preferredQuality).firstOrNull ??
      candidates.first;
}

/// Lowest numeric quality (e.g. "240p") offered by [server]; non-numeric labels like "Auto" sort last.
String lowestQuality(Episode ep, String server) {
  int rank(String q) => int.tryParse(q.replaceAll(RegExp(r'\D'), '')) ?? 1 << 30;
  final qs = [for (final s in ep.sources.where((s) => s.server == server)) s.quality]
    ..sort((a, b) => rank(a).compareTo(rank(b)));
  return qs.first;
}

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key, required this.drama, this.initialEpisode});

  final Drama drama;
  final int? initialEpisode;

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> with WidgetsBindingObserver {
  late final LibraryNotifier _library = ref.read(libraryProvider.notifier);
  Drama get drama => widget.drama;

  VideoPlayerController? _ctrl;
  String? _loadedUrl;
  late Episode _ep;
  late VideoSource _source;
  Object? _error;
  bool _loading = true;
  bool _endHandled = false;
  bool _fullscreen = false;
  late bool _fill = _library.fillScreen;
  int _token = 0;
  Timer? _saveTimer;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    final last = _library.repo.history[drama.key];
    final number = widget.initialEpisode ?? last?.episode ?? drama.episodes.first.number;
    _ep = drama.episode(number) ?? drama.episodes.first;
    _source = pickSource(_ep, preferredQuality: _library.preferredQuality);
    _pages = PageController(initialPage: drama.episodes.indexOf(_ep));
    // Resume where the user left off unless the episode was essentially finished.
    final resume = last != null && last.episode == _ep.number && last.progress < 0.97 && last.position.inSeconds > 3
        ? last.position
        : Duration.zero;
    _open(_ep.number, resume: resume);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_ctrl?.value.isPlaying ?? false) _saveProgress();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _pages.dispose();
    _saveProgress();
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    WakelockPlus.disable();
    if (_fullscreen) _setSystemFullscreen(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _ctrl?.pause();
      _saveProgress();
    }
  }

  Duration get _epStart => _ep.start;
  Duration get _epEnd => _ep.end ?? _ctrl?.value.duration ?? Duration.zero;
  Duration get _epLength => _epEnd - _epStart;
  Duration _posInEp(VideoPlayerValue v) {
    final p = v.position - _epStart;
    return p.isNegative ? Duration.zero : (p > _epLength ? _epLength : p);
  }

  void _saveProgress() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    // Saved without awaiting so it also works from dispose().
    _library.saveProgress(drama, _ep.number, _posInEp(c.value), _epLength);
  }

  Future<void> _open(int number, {Duration resume = Duration.zero, String? server, String? quality}) async {
    final ep = drama.episode(number);
    if (ep == null) return;
    if (_ctrl?.value.isInitialized ?? false) _saveProgress();
    final token = ++_token;
    final source = pickSource(
      ep,
      server: server ?? _source.server,
      quality: quality ?? _source.quality,
      preferredQuality: _library.preferredQuality,
    );
    setState(() {
      _ep = ep;
      _source = source;
      _error = null;
      _loading = true;
      _endHandled = false;
    });
    // Keep the reel in step when the episode changes from buttons, the episode sheet or auto-advance.
    final page = drama.episodes.indexOf(ep);
    if (_pages.hasClients && _pages.page?.round() != page) _pages.jumpToPage(page);

    final lowest = lowestQuality(ep, source.server);
    var ctrl = _ctrl;
    if (ctrl == null || _loadedUrl != source.url || !ctrl.value.isInitialized || ctrl.value.hasError) {
      _ctrl = null;
      _loadedUrl = null;
      ctrl?.removeListener(_onTick);
      await ctrl?.dispose();
      ctrl = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        formatHint: switch (source.format) {
          'hls' => VideoFormat.hls,
          'dash' => VideoFormat.dash,
          _ => null,
        },
        httpHeaders: const {'User-Agent': userAgent},
      );
      try {
        // Higher qualities get a short deadline so slow connections fall back quickly.
        await ctrl.initialize().timeout(Duration(seconds: source.quality == lowest ? 60 : 12));
      } on Object catch (e) {
        await ctrl.dispose();
        if (token != _token || !mounted) return;
        if (source.quality != lowest) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Slow connection: switched to $lowest')));
          return _open(number, resume: resume, server: source.server, quality: lowest);
        }
        setState(() {
          _error = e;
          _loading = false;
        });
        return;
      }
      if (token != _token || !mounted) {
        await ctrl.dispose();
        return;
      }
      ctrl.addListener(_onTick);
      _ctrl = ctrl;
      _loadedUrl = source.url;
    }
    await ctrl.seekTo(ep.start + resume);
    await ctrl.play();
    if (token != _token || !mounted) return;
    _library.markWatched(drama.key, ep.number);
    setState(() => _loading = false);
  }

  void _onTick() {
    final c = _ctrl;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Playback failed');
      return;
    }
    if (_loading || _endHandled || !v.isInitialized) return;
    if (v.isCompleted || v.position >= _epEnd - const Duration(milliseconds: 200)) {
      _endHandled = true;
      _onEpisodeEnd();
    }
  }

  void _onEpisodeEnd() {
    _ctrl?.pause();
    _saveProgress();
    final next = drama.episode(_ep.number + 1);
    if (next != null && _library.autoplayNext) {
      _open(next.number);
    } else {
      setState(() {});
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You finished the last episode')));
      }
    }
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _saveProgress();
    } else if (_endHandled) {
      // Replay the finished episode.
      _open(_ep.number);
    } else {
      c.play();
    }
    setState(() {});
  }

  void _step(int delta) {
    final target = drama.episode(_ep.number + delta);
    if (target != null) _open(target.number);
  }

  Future<void> _retry() => _open(_ep.number, resume: _ctrl == null ? Duration.zero : _posInEp(_ctrl!.value));

  Future<void> _setSystemFullscreen(bool on) async {
    if (on) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final ratio = _ctrl?.value.aspectRatio ?? 1;
      if (ratio > 1) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([]);
    }
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    _setSystemFullscreen(_fullscreen);
  }

  Future<void> _sheet(Widget Function(BuildContext) builder) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: builder(c)),
      ),
    ),
  );

  void _showEpisodes() => _sheet(
    (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Episodes', style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 12),
        EpisodeMatrix(
          drama: drama,
          current: _ep.number,
          onSelect: (e) {
            Navigator.pop(c);
            _open(e.number);
          },
        ),
      ],
    ),
  );

  void _showChoices(String title, List<String> options, String current, ValueChanged<String> onPick) =>
      showCupertinoModalPopup<void>(
        context: context,
        builder: (c) => CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final o in options)
              CupertinoActionSheetAction(
                isDefaultAction: o == current,
                onPressed: () {
                  Navigator.pop(c);
                  if (o != current) onPick(o);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(o),
                    if (o == current)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(CupertinoIcons.checkmark_alt, size: 20),
                      ),
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ),
      );

  Duration get _currentPos => _ctrl == null ? Duration.zero : _posInEp(_ctrl!.value);

  void _showServers() => _showChoices(
    'Server',
    _ep.servers,
    _source.server,
    (s) => _open(_ep.number, resume: _currentPos, server: s, quality: _source.quality),
  );

  void _showQualities() => _showChoices(
    'Quality',
    [for (final s in _ep.sources.where((s) => s.server == _source.server)) s.quality],
    _source.quality,
    (q) {
      _library.setPref('quality', q);
      _open(_ep.number, resume: _currentPos, quality: q);
    },
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final wide = windowSizeFor(MediaQuery.sizeOf(context).width).index >= WindowSize.expanded.index;
    final size = MediaQuery.sizeOf(context);
    final built = _buildPlayer(context);
    // Phones show the reel edge to edge; wider windows get a centered 9:16 reel.
    final player = _fullscreen || size.width / size.height <= 9 / 16 || !wide && size.width < size.height
        ? built
        : Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRect(child: built),
            ),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: wide && !_fullscreen
            ? Row(
                children: [
                  Expanded(child: player),
                  SizedBox(
                    width: 360,
                    child: _SidePanel(drama: drama, current: _ep.number, onSelect: (e) => _open(e.number)),
                  ),
                ],
              )
            : player,
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;
    final liked = _library.isLiked(drama.key);
    final saved = _library.isBookmarked(drama.key);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Reels-style vertical feed: one page per episode, only the current page holds the live video.
        PageView.builder(
          key: const ValueKey('reel'),
          controller: _pages,
          scrollDirection: Axis.vertical,
          physics: _fullscreen ? const NeverScrollableScrollPhysics() : null,
          itemCount: drama.episodes.length,
          onPageChanged: (i) {
            final n = drama.episodes[i].number;
            if (n != _ep.number) _open(n);
          },
          itemBuilder: (context, i) {
            final e = drama.episodes[i];
            if (e.number != _ep.number || !ready) {
              final art = e.thumbnail ?? drama.poster;
              return Opacity(opacity: 0.5, child: Poster(art, radius: 0));
            }
            return GestureDetector(
              key: const ValueKey('player-surface'),
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: _fill && !_fullscreen
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
                      ),
                    )
                  : Center(
                      child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
                    ),
            );
          },
        ),
        // Readability scrims behind the top bar and the caption.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.15, 0.6, 1],
                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
        if (_error == null && (_loading || (ready && c.value.isBuffering)))
          const Center(
            child: CupertinoActivityIndicator(key: ValueKey('buffering'), color: Colors.white, radius: 16),
          ),
        if (ready && !_loading && _error == null && !c.value.isPlaying)
          IgnorePointer(
            child: Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 76,
                    height: 76,
                    color: const Color(0x4D000000),
                    child: Icon(
                      _endHandled ? CupertinoIcons.arrow_counterclockwise : CupertinoIcons.play_fill,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          _ErrorPanel(error: _error!, onRetry: _retry, onServers: _ep.servers.length > 1 ? _showServers : null),
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 4),
                GlassButton(
                  tooltip: _fullscreen ? 'Exit full screen' : 'Back',
                  icon: _fullscreen ? CupertinoIcons.fullscreen_exit : CupertinoIcons.chevron_down,
                  onPressed: _fullscreen ? _toggleFullscreen : () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${drama.title} · EP ${_ep.number}/${drama.episodes.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      shadows: _shadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_fullscreen)
          // Sits between the top bar and the bottom controls; scrolls when the screen is short (landscape phones).
          Positioned(
            right: 8,
            top: 56,
            bottom: 64,
            child: SafeArea(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  children: [
                    _RailButton(
                      icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: liked ? const Color(0xFFFF375F) : null,
                      label: 'Like',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _library.toggleLike(drama.key);
                      },
                    ),
                    _RailButton(icon: CupertinoIcons.list_bullet, label: 'Episodes', onTap: _showEpisodes),
                    _RailButton(icon: CupertinoIcons.share, label: 'Share', onTap: () => shareDrama(drama)),
                    _RailButton(
                      icon: saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                      label: saved ? 'Saved' : 'Save',
                      onTap: () => _library.toggleBookmark(drama),
                    ),
                    _RailButton(
                      icon: CupertinoIcons.antenna_radiowaves_left_right,
                      label: 'Server',
                      onTap: _showServers,
                    ),
                    _RailButton(icon: CupertinoIcons.sparkles, label: _source.quality, onTap: _showQualities),
                    _RailButton(
                      icon: _fill
                          ? CupertinoIcons.rectangle_compress_vertical
                          : CupertinoIcons.rectangle_expand_vertical,
                      label: _fill ? 'Fit' : 'Fill',
                      onTap: () {
                        setState(() => _fill = !_fill);
                        _library.setPref('video_fit', _fill ? 'cover' : 'contain');
                      },
                    ),
                    _RailButton(icon: CupertinoIcons.fullscreen, label: 'Full screen', onTap: _toggleFullscreen),
                  ],
                ),
              ),
            ),
          ),
        // Bottom: episode/server badges, prev/next and progress.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_fullscreen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 64, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drama.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              shadows: _shadow,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            drama.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, shadows: _shadow),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _GlassLabel('EP ${_ep.number}'),
                        _GlassLabel('${_source.server} · ${_source.quality}'),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous episode',
                        color: Colors.white,
                        onPressed: drama.episode(_ep.number - 1) == null ? null : () => _step(-1),
                        icon: const Icon(CupertinoIcons.backward_end_fill, size: 22),
                      ),
                      Expanded(
                        child: ready
                            ? _Progress(ctrl: c, start: _epStart, length: _epLength)
                            : const SizedBox(height: 48),
                      ),
                      IconButton(
                        tooltip: 'Next episode',
                        color: Colors.white,
                        onPressed: drama.episode(_ep.number + 1) == null ? null : () => _step(1),
                        icon: const Icon(CupertinoIcons.forward_end_fill, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatefulWidget {
  const _Progress({required this.ctrl, required this.start, required this.length});

  final VideoPlayerController ctrl;
  final Duration start;
  final Duration length;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  double? _drag;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.ctrl,
    builder: (context, v, _) {
      final len = widget.length.inMilliseconds;
      final pos = (v.position - widget.start).inMilliseconds.clamp(0, len < 1 ? 1 : len);
      final value = _drag ?? (len < 1 ? 0.0 : pos / len);
      final shown = Duration(milliseconds: (value * len).round());
      return Row(
        children: [
          Text(
            formatDuration(shown),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 4,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white30,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                trackShape: RoundedRectSliderTrackShape(),
                // ignore: deprecated_member_use
                year2023: true,
              ),
              child: Slider(
                key: const ValueKey('progress'),
                value: value.clamp(0.0, 1.0),
                onChanged: (x) => setState(() => _drag = x),
                onChangeEnd: (x) async {
                  await widget.ctrl.seekTo(widget.start + Duration(milliseconds: (x * len).round()));
                  if (mounted) setState(() => _drag = null);
                },
              ),
            ),
          ),
          Text(
            formatDuration(widget.length),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      );
    },
  );
}

const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 3), Shadow(color: Color(0x80000000), blurRadius: 10)];

class _GlassLabel extends StatelessWidget {
  const _GlassLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        color: const Color(0x4D000000),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      children: [
        GlassButton(icon: icon, tooltip: label, color: color, onPressed: onTap),
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, shadows: _shadow),
          ),
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry, this.onServers});

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onServers;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            color: const Color(0xB31C1C1E),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.wifi_slash, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'This episode could not be played',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check your connection and try again.\n$error',
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ),
                if (onServers != null)
                  CupertinoButton(
                    onPressed: onServers,
                    child: const Text('Switch server', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.drama, required this.current, required this.onSelect});

  final Drama drama;
  final int current;
  final ValueChanged<Episode> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(drama.catalogName.toUpperCase(), style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(drama.title, style: t.headlineMedium),
            const SizedBox(height: 8),
            Text(drama.description, style: t.bodyMedium),
            const SizedBox(height: 24),
            Text('Episodes', style: t.headlineSmall),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            EpisodeMatrix(drama: drama, current: current, onSelect: onSelect),
            if (drama.license != null) ...[
              const SizedBox(height: 16),
              Text(
                '${drama.attribution ?? ''} · ${drama.license}',
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
