import 'package:flutter/material.dart';
import 'package:flutter_thinking_orbs/flutter_thinking_orbs.dart';

void main() {
  runApp(const ThinkingOrbsExampleApp());
}

class ThinkingOrbsExampleApp extends StatefulWidget {
  const ThinkingOrbsExampleApp({super.key});

  @override
  State<ThinkingOrbsExampleApp> createState() => _ThinkingOrbsExampleAppState();
}

class _ThinkingOrbsExampleAppState extends State<ThinkingOrbsExampleApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThinkingOrbs Demo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: DemoHomePage(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  bool _isPaused = false;
  double _speed = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ThinkingOrbs'),
        actions: [
          IconButton(
            tooltip: _isPaused ? 'Resume' : 'Pause',
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
            },
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Header description
          Text(
            'Dotted, genuinely 3D loading indicators for AI and agent interfaces.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          // Shimmer Status Labels Section
          Text(
            'Status Labels & Shimmer',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThinkingOrbLabel(
                    'Searching the web…',
                    design: OrbDesign.searching,
                    speed: _speed,
                    isPaused: _isPaused,
                  ),
                  const SizedBox(height: 16),
                  ThinkingOrbLabel(
                    'Reading 14 files…',
                    design: OrbDesign.working,
                    speed: _speed,
                    isPaused: _isPaused,
                    textStyle: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ThinkingOrbLabel(
                        'Thinking…',
                        design: OrbDesign.breathing,
                        size: OrbSize.regular,
                        diameter: 36,
                        speed: _speed,
                        isPaused: _isPaused,
                        textStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'Composing a synthesized answer with live shimmer…',
                          overflow: TextOverflow.ellipsis,
                        ).thinkingShimmer(isActive: !_isPaused),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Speed Control
          Row(
            children: [
              Text('Speed: ${_speed.toStringAsFixed(1)}x'),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.2,
                  max: 3.0,
                  divisions: 14,
                  label: '${_speed.toStringAsFixed(1)}x',
                  onChanged: (val) {
                    setState(() {
                      _speed = val;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // The 9 Designs
          Text(
            'The Nine Designs',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...OrbDesign.values.map((design) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Regular 64 pt
                    ThinkingOrb(
                      design: design,
                      size: OrbSize.regular,
                      speed: _speed,
                      isPaused: _isPaused,
                    ),
                    const SizedBox(width: 16),
                    // Small 20 pt
                    ThinkingOrb(
                      design: design,
                      size: OrbSize.small,
                      speed: _speed,
                      isPaused: _isPaused,
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            design.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            design.summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
