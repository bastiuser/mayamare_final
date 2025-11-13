import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_wead/UserStore.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accountmenu.dart';
import 'commonfunctions.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'signup.dart';
import 'commonfunctions.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:conversion/conversion.dart';
import 'UserStore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ThemeProfile.dart';
import 'services/media_cache_service.dart';
import 'package:path/path.dart' as p; // optional

class Slidepicker extends StatefulWidget {
  const Slidepicker({Key? key}) : super(key: key);

  @override
  State<Slidepicker> createState() => _SlidepickerState();
}

class AudioItem {
  final int id;
  final String url;
  AudioItem({required this.id, required this.url});
  factory AudioItem.fromJson(Map<String, dynamic> json) => AudioItem(
        id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
        url: json['url'] as String,
      );
}

class VideoItem {
  final int id;
  final String url;

  VideoItem({required this.id, required this.url});

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as int,
      url: json['url'] as String,
    );
  }
}

class _SlidepickerState extends State<Slidepicker> {
  /// -- VIDEO: jetzt dynamisch --
  List<VideoItem> _videos = []; // vorher: fixe Liste
  final PageController _pageController = PageController();

  List<VideoPlayerController?> _videoControllers = [];
  int? _selectedVideoIndex;
  int _currentVideoIndex = 0;
  final Set<int> _initializing = <int>{};
  List<AudioItem> _audios = []; // dynamische Liste aus API
  final List<AudioPlayer?> _audioPlayers = []; // growable, nur 1x zugewiesen
  final PageController _musicController = PageController();
  final Map<String, ThemeProfile> _profiles = {};
  int? _selectedMusicIndex;
  int _currentMusicPageIndex = 0;
  final musicOptions = const [
    DropdownOption('chill', 'Theme 1', Icons.spa),
    DropdownOption('epic', 'Theme 2', Icons.movie_creation_outlined),
    DropdownOption('lofi', 'Theme 3', Icons.nightlight_round),
    DropdownOption('pop', 'Theme 4', Icons.music_note),
    DropdownOption('none', 'Theme 5', Icons.block),
  ];
  late MediaCacheService _mediaSvc; // mit Cookie initialisieren
  final List<Duration> _positions = [];
  final List<Duration> _durations = [];
  String? _selectedStyle = 'chill';
  bool _noInternet = false; // <<< NEU: Status für Netzfehler

  int get _customThemeIndex {
    final i = musicOptions.indexWhere((o) => o.value == _selectedStyle);
    return i < 0 ? 0 : i; // Fallback auf 0, wenn nichts gefunden
    }

  @override
  void initState() {
    super.initState();
    _loadProfiles(); // <— Profile laden
    _mediaSvc = MediaCacheService(
      cookie: Provider.of<UserStore>(context, listen: false).cookie,
    );
    // --- VIDEO: dynamisch laden & initialisieren ---
    _fetchAndInitVideos(); // lädt Liste & preloaded 0±1
    // -- AUDIO INITIALISIERUNG --
    _fetchAndInitAudios(); // dynamisch laden + Player aufsetzen
  }

  // <<< NEU: Scrollbarer Platzhalter für leere/Fehler-Zustände (nur dann Refresh) >>>
  Widget _refreshableInfo(String message, double boxHeight) {
    return SizedBox(
      height: boxHeight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: boxHeight / 2 - 12),
        children: [
          Center(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // <<< NEU: Pull-to-Refresh nur im Leerzustand verwenden
  Future<void> _refreshAll() async {
    try {
      await Future.wait([
        _fetchAndInitVideos(),
        _fetchAndInitAudios(),
      ]);
    } catch (_) {
      // UI-Feedback wird in den Fetch-Methoden gehandhabt
    }
  }

  Future<void> _ensureLocalAudios(List<AudioItem> items) async {
    bool allThere = true;
    for (final a in items) {
      final lp = await _mediaSvc.resolveLocalPath(
          manifestKey: 'audios', id: a.id, url: a.url);
      if (lp == null || !(await File(lp).exists())) {
        allThere = false;
        break;
      }
    }
    if (!allThere) {
      await _mediaSvc.syncAll();
    }
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    for (final opt in musicOptions) {
      final key = 'theme_${opt.value}';
      final s = prefs.getString(key);
      if (s != null) {
        _profiles[opt.value] = ThemeProfile.fromMap(jsonDecode(s));
      }
    }
  }

  Future<void> _saveCurrentToProfile() async {
    final style = _selectedStyle;
    if (style == null) return;

    final vIndex = (_selectedVideoIndex ?? _currentVideoIndex)
        .clamp(0, _videos.length > 0 ? _videos.length - 1 : 0);
    final mIndex = (_selectedMusicIndex ?? _currentMusicPageIndex)
        .clamp(0, _audios.length > 0 ? _audios.length - 1 : 0);
    final int? videoId = _videos.isNotEmpty ? _videos[vIndex].id : null;
    final int? audioId = _audios.isNotEmpty ? _audios[mIndex].id : null;
    final p = ThemeProfile(videoIndex: vIndex, musicIndex: mIndex);
    _profiles[style] = p;
    final body = jsonEncode({
      'customThemeID': _customThemeIndex,
      'videoID': videoId,
      'audioID': audioId,
    });
    try {
      final resp = await http.post(
        Uri.parse('https://waterslide.works/app/setcustomtheme'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
        body: body,
      );
    } catch (_) {
      // Ignorieren – nur lokales Speichern/Feedback
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_$style', jsonEncode(p.toMap()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Theme gespeichert'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  void _applyTheme(String style) {
    final p = _profiles[style];
    if (p == null) return;

    if (p.videoIndex >= 0 && p.videoIndex < _videos.length) {
      _pageController.jumpToPage(p.videoIndex);
      _currentVideoIndex = p.videoIndex;
      _selectedVideoIndex = p.videoIndex;
      _showOnly(p.videoIndex);
    }

    if (p.musicIndex >= 0 && p.musicIndex < _audios.length) {
      _musicController.jumpToPage(p.musicIndex);
      _currentMusicPageIndex = p.musicIndex;
      _selectedMusicIndex = p.musicIndex;
      for (int i = 0; i < _audioPlayers.length; i++) {
        if (i != p.musicIndex) {
          _audioPlayers[i]?.pause();
        }
      }
      _audioPlayers[p.musicIndex]?.resume();
      setState(() {});
    }
  }

  Future<void> _showOnly(int index) async {
    if (!mounted || index < 0 || index >= _videos.length) return;

    for (int i = 0; i < _videoControllers.length; i++) {
      if (i != index && _videoControllers[i] != null) {
        _videoControllers[i]!.pause();
        _videoControllers[i]!.dispose();
        _videoControllers[i] = null;
      }
    }

    await _initVideoAt(index);
    final cur = _videoControllers[index];
    if (cur != null) {
      await cur.setLooping(true);
      await cur.setVolume(0.0);
      await cur.play();
    }
  }

  Future<void> _fetchAndInitAudios() async {
    try {
      final response = await http.get(
        Uri.parse('https://waterslide.works/app/audiolist'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        return;
      }

      final items = (decoded['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => AudioItem.fromJson(m))
          .toList();

      await _ensureLocalAudios(items);

      if (!mounted) return;

      setState(() {
        _noInternet = false;
        _audios = items;
        _audioPlayers
          ..clear()
          ..addAll(List<AudioPlayer?>.filled(_audios.length, null, growable: true));
        _positions
          ..clear()
          ..addAll(List<Duration>.filled(_audios.length, Duration.zero, growable: true));
        _durations
          ..clear()
          ..addAll(List<Duration>.filled(_audios.length, Duration.zero, growable: true));
      });

      for (int i = 0; i < _audios.length && mounted; i++) {
        final p = AudioPlayer();

        p.onPositionChanged.listen((pos) {
          if (i < _positions.length) _positions[i] = pos;
          if (_currentMusicPageIndex == i && mounted) setState(() {});
        });
        p.onDurationChanged.listen((dur) {
          if (i < _durations.length) _durations[i] = dur;
          if (_currentMusicPageIndex == i && mounted) setState(() {});
        });

        final a = _audios[i];
        final localPath = await _mediaSvc.resolveLocalPath(
          manifestKey: 'audios',
          id: a.id,
          url: a.url,
        );

        if (localPath == null || !(await File(localPath).exists())) {
          continue;
        }

        await p.setSourceDeviceFile(localPath);
        await p.setReleaseMode(ReleaseMode.stop);

        await p.resume();
        await Future.delayed(const Duration(milliseconds: 120));
        await p.pause();

        _audioPlayers[i] = p;
      }
    } on SocketException {
      if (!mounted) return;
      setState(() => _noInternet = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Internetverbindung'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // andere Fehler ignoriert -> leere Liste => leerer Zustand
    }
  }

  Future<void> _initVideoAt(int i) async {
    if (!mounted || i < 0 || i >= _videos.length) return;
    if (_videoControllers[i] != null || _initializing.contains(i)) return;

    _initializing.add(i);
    final cookie = Provider.of<UserStore>(context, listen: false).cookie;

    final vid = _videos[i];

    final localPath = await _mediaSvc.resolveLocalPath(
      manifestKey: 'videos',
      id: vid.id,
      url: vid.url,
    );

    VideoPlayerController c;
    if (localPath != null && await File(localPath).exists()) {
      c = VideoPlayerController.file(
        File(localPath),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      c = VideoPlayerController.networkUrl(
        Uri.parse(vid.url),
        httpHeaders: {'Cookie': cookie},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _videoControllers[i] = c;
      if (mounted) setState(() {});
    } catch (e) {
      await c.dispose();
    } finally {
      _initializing.remove(i);
    }
  }

  Future<void> _fetchAndInitVideos() async {
    try {
      final response = await http.get(
        Uri.parse('https://waterslide.works/app/videolist'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': Provider.of<UserStore>(context, listen: false).cookie,
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final success = decoded['success'] == true;
      if (!success) {
        return;
      }

      final data = decoded['data'];
      if (data is! List) {
        return;
      }

      final videos = data
          .whereType<Map<String, dynamic>>()
          .map((e) => VideoItem.fromJson(e))
          .toList();

      if (!mounted) return;

      setState(() {
        _noInternet = false;
        _videos = videos;
        _videoControllers = List<VideoPlayerController?>.filled(
          _videos.length,
          null,
          growable: false,
        );
        _currentVideoIndex = 0;
      });

      await _showOnly(0);

      final first = _videoControllers[_currentVideoIndex];
      first?.setVolume(0.0);
      first?.play();
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _noInternet = true;
        _videos = [];
        _videoControllers = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Internetverbindung'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // andere Fehler -> leerer Zustand
      if (!mounted) return;
      setState(() {
        _videos = [];
        _videoControllers = [];
      });
    }
  }

  @override
  void dispose() {
    for (final vc in _videoControllers) {
      vc?.dispose();
    }
    for (final ap in _audioPlayers) {
      ap?.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    _currentVideoIndex = newIndex;

    for (final vc in _videoControllers) {
      vc?.pause();
    }
    _showOnly(newIndex);
  }

  void _onVideoTapped(int index) {
    setState(() {
      if (_selectedVideoIndex == index) {
        _selectedVideoIndex = null;
      } else {
        _selectedVideoIndex = index;
      }
    });
  }

  void _onMusicTapped(int index) async {
    final re =
        RegExp(r'/audio/(?:[A-Za-z0-9]+[-_])*([A-Za-z]{5,})(?=[-_./?#]|$)');
    final match = re.firstMatch(_audios[index].url);
    final firstWord = match?.group(1);
    setState(() {
      if (_selectedMusicIndex == index) {
        _selectedMusicIndex = null;
      } else {
        _selectedMusicIndex = index;
      }
    });
  }

  void _onMusicPageChanged(int newIndex) {
    setState(() {
      _currentMusicPageIndex = newIndex;
    });

    for (int i = 0; i < _audioPlayers.length; i++) {
      if (i != newIndex) {
        _audioPlayers[i]?.pause();
      } else {
        if (_selectedMusicIndex == i) {
          _audioPlayers[i]?.resume();
        }
      }
    }
  }

  void _playTrack(int index) async {
    final a = _audios[index];
    final localPath = await _mediaSvc.resolveLocalPath(
      manifestKey: 'audios',
      id: a.id,
      url: a.url,
    );
    if (localPath != null && await File(localPath).exists()) {
      await _audioPlayers[index]?.play(DeviceFileSource(localPath));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio wird noch heruntergeladen…'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    }
  }

  void _pauseTrack(int index) async {
    await _audioPlayers[index]?.pause();
  }

  void _stopTrack(int index) async {
    await _audioPlayers[index]?.stop();
    await _audioPlayers[index]?.play(UrlSource(_audios[index].url));
    await _audioPlayers[index]?.stop();
  }

  Future<void> _seekTo(int index, Duration position) async {
    await _audioPlayers[index]?.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double w = constraints.maxWidth;
        double h = constraints.maxHeight;

        final bool isEmptyState = _videos.isEmpty || _audios.isEmpty;

        return Scaffold(
          body: Container(
            color: const Color(0xFFEAEAEA),
            child: Column(
              children: [
                // Header (unverändert)
                Container(
                  height: h * 0.29,
                  child: Stack(children: [
                    Positioned(
                      left: w * 0.8,
                      top: 0,
                      height: h * 0.10,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Image(
                              image: AssetImage('assets/newlogo.png'),
                              width: 100,
                              height: 100,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: h * 0.08),
                          child: Center(
                            child: Container(
                              width: w * 0.7,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: w * 0.7,
                                    child: Consumer<UserStore>(
                                      builder: (context, value, child) => Text(
                                        'Hallo, ${value.user} !',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w500,
                                          height: 0.08,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: h * 0.01),
                          child: Center(
                            child: Container(
                              width: w * 0.7,
                              height: h * 0.1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: w * 0.7,
                                    child: Text(
                                      'Custom Slide',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 32,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: h * 0.01),
                          child: Center(
                            child: Container(
                              width: 0.7 * w,
                              height: h * 0.08,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 0.7 * w,
                                    height: h * 0.14,
                                    child: Text(
                                      'Stelle dir hier deine ganz eigene Rutschen-Erfahrung und zusammen',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    )
                  ]),
                ),

                SizedBox(
                  width: w * 0.7,
                  height: h * 0.10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: h * 0.01),
                          child: NiceDropdown(
                            label: 'Theme',
                            options: musicOptions,
                            value: _selectedStyle,
                            onChanged: (v) {
                              setState(() => _selectedStyle = v);
                              if (v != null) _applyTheme(v);
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: w * 0.015),
                      Padding(
                        padding: EdgeInsets.only(bottom: h * 0.02, top: h * 0.01),
                        child: SizedBox(
                          height: h * 0.10 - h * 0.01,
                          child: FilledButton.icon(
                            onPressed: (_videos.isEmpty || _audios.isEmpty)
                                ? null
                                : _saveCurrentToProfile,
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Speichern'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: w * 0.02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // UNTERER BEREICH
                Container(
                  height: h * 0.61,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1, -0.8),
                      end: Alignment(0.85, 0.95),
                      colors: [Colors.white, Color(0xFFDCDCDC)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                  ),

                  // <<< NEU: RefreshIndicator nur sinnvoll bei leerem Inhalt, weil nur dann Kind scrollt >>>
                  child: isEmptyState
                      ? RefreshIndicator(
                          onRefresh: _refreshAll,
                          child: _refreshableInfo(
                            _noInternet
                                ? 'Keine Internetverbindung'
                                : 'Hier sieht es ganz schön leer aus',
                            h * 0.61,
                          ),
                        )
                      : Column(
                          children: [
                            // VIDEO-KARUSSELL
                            Container(
                              height: 0.3 * h,
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: _onPageChanged,
                                itemCount: _videos.length,
                                itemBuilder: (context, index) {
                                  final controller = (index < _videoControllers.length)
                                      ? _videoControllers[index]
                                      : null;
                                  if (controller == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  } else {
                                    return GestureDetector(
                                      onTap: () => _onVideoTapped(index),
                                      child: _buildVideoPage(controller, index),
                                    );
                                  }
                                },
                              ),
                            ),

                            // MUSIK-KARUSSELL
                            Container(
                              height: h * 0.24,
                              child: PageView.builder(
                                controller: _musicController,
                                itemCount: _audios.length,
                                onPageChanged: _onMusicPageChanged,
                                itemBuilder: (context, index) {
                                  final ap = (index < _audioPlayers.length)
                                      ? _audioPlayers[index]
                                      : null;
                                  if (ap == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  } else {
                                    return _buildMusicPage(ap, index);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPage(VideoPlayerController controller, int index) {
    final isReady = controller.value.isInitialized;
    final isSelected = (index == _selectedVideoIndex);
    final borderColor = isSelected
        ? const Color.fromARGB(234, 193, 194, 193)
        : const Color.fromARGB(234, 220, 220, 220);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 1.0),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 12.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: isReady ? controller.value.aspectRatio : 16 / 9,
              child: isReady
                  ? VideoPlayer(controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: isSelected
                    ? const Icon(
                        Icons.check_circle_outline,
                        key: ValueKey('selectedIcon'),
                        color: Colors.green,
                        size: 32,
                      )
                    : const SizedBox(
                        key: ValueKey('unselectedPlaceholder'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicPage(AudioPlayer audioPlayer, int index) {
    final isSelected = (index == _selectedMusicIndex);
    final re = RegExp(
        r'/audio/(?:[A-Za-z0-9]{1,4}[-_]+)*([A-Za-z]{5,})(?=[-_./?#]|$)');
    final match = re.firstMatch(_audios[index].url);
    String? firstWord = match?.group(1);
    if (firstWord != null) {
      firstWord = firstWord[0].toUpperCase() + firstWord.substring(1).toLowerCase();
    }
    final currentPos = _positions[index];
    final totalDur = _durations[index];

    return Center(
      child: Container(
        margin: const EdgeInsets.all(7.0),
        padding: const EdgeInsets.all(7.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 4.0,
          ),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _onMusicTapped(index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$firstWord', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(currentPos)),
                            Text(_formatDuration(totalDur)),
                          ],
                        ),
                        Slider(
                          min: 0.0,
                          max: (totalDur.inMilliseconds > 0
                              ? totalDur.inMilliseconds.toDouble()
                              : 1.0),
                          value: (totalDur.inMilliseconds > 0
                              ? currentPos.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, totalDur.inMilliseconds.toDouble())
                              : 0.0),
                          onChanged: (totalDur.inMilliseconds > 0)
                              ? (newValue) {
                                  final clamped = newValue
                                      .clamp(0.0, totalDur.inMilliseconds.toDouble());
                                  _seekTo(index,
                                      Duration(milliseconds: clamped.round()));
                                }
                              : null,
                        )
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Play',
                        onPressed: () => _playTrack(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.pause),
                        tooltip: 'Pause',
                        onPressed: () => _pauseTrack(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop),
                        tooltip: 'Stop',
                        onPressed: () => _stopTrack(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        key: ValueKey('selectedMusicIcon'),
                        color: Colors.green,
                        size: 32,
                      )
                    : const SizedBox(
                        key: ValueKey('unselectedMusicPlaceholder'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
