import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isChinese = true;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  void _toggleLanguage() {
    setState(() {
      _isChinese = !_isChinese;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThinkingOrbs Showcase',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ShowcaseHomePage(
        onToggleTheme: _toggleTheme,
        onToggleLanguage: _toggleLanguage,
        isDark: _themeMode == ThemeMode.dark,
        isChinese: _isChinese,
      ),
    );
  }
}

class ShowcaseHomePage extends StatefulWidget {
  const ShowcaseHomePage({
    super.key,
    required this.onToggleTheme,
    required this.onToggleLanguage,
    required this.isDark,
    required this.isChinese,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;
  final bool isDark;
  final bool isChinese;

  @override
  State<ShowcaseHomePage> createState() => _ShowcaseHomePageState();
}

class _ShowcaseHomePageState extends State<ShowcaseHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isPaused = false;
  double _speed = 1.0;

  // Playground state
  OrbDesign _selectedDesign = OrbDesign.searching;
  OrbSize _selectedSize = OrbSize.regular;
  double _diameter = 64.0;
  Color? _customColor;
  late TextEditingController _labelTextController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _labelTextController = TextEditingController(
      text: widget.isChinese ? '正在全网检索文献…' : 'Searching the web…',
    );
  }

  @override
  void didUpdateWidget(covariant ShowcaseHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChinese != widget.isChinese) {
      if (widget.isChinese &&
          _labelTextController.text == 'Searching the web…') {
        _labelTextController.text = '正在全网检索文献…';
      } else if (!widget.isChinese &&
          _labelTextController.text == '正在全网检索文献…') {
        _labelTextController.text = 'Searching the web…';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _labelTextController.dispose();
    super.dispose();
  }

  String _designTitle(OrbDesign d) {
    if (!widget.isChinese) return d.title;
    switch (d) {
      case OrbDesign.working:
        return '运转 · Working';
      case OrbDesign.searching:
        return '检索 · Searching';
      case OrbDesign.solving:
        return '求解 · Solving';
      case OrbDesign.listening:
        return '聆听 · Listening';
      case OrbDesign.connecting:
        return '互联 · Connecting';
      case OrbDesign.weaving:
        return '编织 · Weaving';
      case OrbDesign.composing:
        return '撰写 · Composing';
      case OrbDesign.breathing:
        return '呼吸 · Breathing';
      case OrbDesign.shaping:
        return '塑形 · Shaping';
    }
  }

  String _designSummary(OrbDesign d) {
    if (!widget.isChinese) return d.summary;
    switch (d) {
      case OrbDesign.working:
        return '倾斜轨道上的循环粒子，适用于后台任务与通用繁忙状态';
      case OrbDesign.searching:
        return '子午线扫描光带扫过点阵球，适用于网络检索与知识召回';
      case OrbDesign.solving:
        return '环带切片快速扰动后清脆复位，适用于逻辑推导、代码与数学计算';
      case OrbDesign.listening:
        return '声学波形沿纬度环涌动起伏，适用于实时语音与音频转录';
      case OrbDesign.connecting:
        return '星座网络自组织布线与脉冲传输，适用于工具调用与 API 状态同步';
      case OrbDesign.weaving:
        return '三股发辫沿球面自旋交织，适用于多步规划与智能体任务拆解';
      case OrbDesign.composing:
        return '微动起伏的三维多轨飘带，适用于文本起草与回复流式生成';
      case OrbDesign.breathing:
        return '正向环形轻缓舒张起伏，适用于待机思考与闲置就绪';
      case OrbDesign.shaping:
        return '圆→三角→方形等距平滑形变，适用于生图排版与 UI 构型';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ThinkingOrbs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.isChinese
                  ? '专为 AI / Agent 打造的纯 3D 点阵加载动效'
                  : 'Dotted, genuinely 3D loading indicators for AI agents',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.language, size: 18),
            label: Text(widget.isChinese ? 'EN' : '中文'),
            onPressed: widget.onToggleLanguage,
          ),
          // Pause / Play
          IconButton(
            tooltip: _isPaused
                ? (widget.isChinese ? '恢复播放' : 'Resume')
                : (widget.isChinese ? '暂停冻结' : 'Pause'),
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          // Theme Switcher
          IconButton(
            tooltip: widget.isChinese ? '切换主题' : 'Toggle Theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              text: widget.isChinese ? '九款矩阵' : 'All Designs',
            ),
            Tab(
              icon: const Icon(Icons.smart_toy_outlined, size: 18),
              text: widget.isChinese ? 'Agent 场景' : 'AI Scenarios',
            ),
            Tab(
              icon: const Icon(Icons.tune_rounded, size: 18),
              text: widget.isChinese ? '交互试验台' : 'Playground',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDesignsTab(theme, isDark),
          _buildScenariosTab(theme, isDark),
          _buildPlaygroundTab(theme, isDark),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ALL DESIGNS (九款矩阵)
  // ==========================================
  Widget _buildDesignsTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Global Speed Slider Card
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF161E2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  widget.isChinese
                      ? '动效速率: ${_speed.toStringAsFixed(1)}x'
                      : 'Tempo Speed: ${_speed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 0.2,
                    max: 3.0,
                    divisions: 14,
                    label: '${_speed.toStringAsFixed(1)}x',
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _speed = 1.0),
                  child: Text(widget.isChinese ? '重置' : 'Reset'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 9 Designs List
        ...OrbDesign.values.map((design) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: isDark ? const Color(0xFF161E2E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Regular 64 pt
                  ThinkingOrb(
                    design: design,
                    size: OrbSize.regular,
                    speed: _speed,
                    isPaused: _isPaused,
                  ),
                  const SizedBox(width: 20),
                  // Small 20 pt
                  ThinkingOrb(
                    design: design,
                    size: OrbSize.small,
                    speed: _speed,
                    isPaused: _isPaused,
                  ),
                  const SizedBox(width: 20),
                  // Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _designTitle(design),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '.${design.name}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _designSummary(design),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
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
    );
  }

  // ==========================================
  // TAB 2: AI AGENT SCENARIOS (智能体场景演示)
  // ==========================================
  Widget _buildScenariosTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.isChinese
              ? 'Agent 状态反馈典型范式'
              : 'Typical Agent Status Feedback Patterns',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isChinese
              ? '在长链条推理、工具调用与多模态交互中，通过微动点阵精准传达智能体的运转意图。'
              : 'Convey precise agent intent across multi-turn reasoning, tool execution, and multimodal pipelines.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),

        // Scenario 1: Web RAG Search
        _buildScenarioCard(
          theme: theme,
          isDark: isDark,
          tag: widget.isChinese ? '知识检索' : 'RAG Retrieval',
          tagColor: Colors.blueAccent,
          icon: Icons.travel_explore_rounded,
          design: OrbDesign.searching,
          label: widget.isChinese
              ? '正在全网检索 14 份行业研报与技术文档…'
              : 'Searching 14 technical RFCs and documentation…',
          detail: widget.isChinese
              ? '子午线扫描光带扫过球面点阵，自然传达“全域雷达探测/向量召回”意图。'
              : 'A sweeping meridian evokes planetary radar mapping, signaling high-dimensional vector search.',
        ),

        // Scenario 2: Reasoning & Code
        _buildScenarioCard(
          theme: theme,
          isDark: isDark,
          tag: widget.isChinese ? '逻辑求解' : 'Code Reasoning',
          tagColor: Colors.purpleAccent,
          icon: Icons.terminal_rounded,
          design: OrbDesign.solving,
          label: widget.isChinese
              ? '正在沙箱中执行符号求解并验证断言…'
              : 'Running symbolic derivation & executing sandbox tests…',
          detail: widget.isChinese
              ? '环带切片快速扰动并在阶段终点整齐锁死复位，模拟魔方解题与严谨推理。'
              : 'Bands scramble rapidly then click back into a solved state, visually mirroring deterministic code compilation.',
        ),

        // Scenario 3: Multi-agent Planning
        _buildScenarioCard(
          theme: theme,
          isDark: isDark,
          tag: widget.isChinese ? '协同编排' : 'Multi-Agent',
          tagColor: Colors.tealAccent,
          icon: Icons.account_tree_rounded,
          design: OrbDesign.weaving,
          label: widget.isChinese
              ? '正在编排 3 个子代理工作流并拆解依赖…'
              : 'Weaving 3 sub-agent DAG workflows & scheduling tasks…',
          detail: widget.isChinese
              ? '三股细丝环绕球面平滑穿梭交织，精准契合多工作流的依赖拆分与编织。'
              : 'Three braided strands plait around the globe, ideal for parallel agent pipelines converging into synthesis.',
        ),

        // Scenario 4: Real-time Audio Stream
        _buildScenarioCard(
          theme: theme,
          isDark: isDark,
          tag: widget.isChinese ? '语音感知' : 'Voice Input',
          tagColor: Colors.orangeAccent,
          icon: Icons.graphic_eq_rounded,
          design: OrbDesign.listening,
          label: widget.isChinese
              ? '正在以 16kHz 低延迟转录用户语音输入…'
              : 'Listening & streaming 16kHz acoustic transcription…',
          detail: widget.isChinese
              ? '双频声学波沿纬线环涌动，无需彩色繁琐波形即可高雅传递语音监听态。'
              : 'Dual acoustic waveforms ripple across latitude rings, offering quiet, non-intrusive voice feedback.',
        ),

        // Scenario 5: Response Synthesis with Shimmer
        _buildScenarioCard(
          theme: theme,
          isDark: isDark,
          tag: widget.isChinese ? '流式回复' : 'Streaming Output',
          tagColor: Colors.pinkAccent,
          icon: Icons.auto_awesome_rounded,
          design: OrbDesign.composing,
          label: widget.isChinese
              ? '正在合成最终回复…'
              : 'Synthesizing final executive response…',
          detail: widget.isChinese
              ? '微动多轨飘带与文本 2.0s 线性扫光同步律动，彰显内容正在鲜活流淌。'
              : 'Multi-band sash undulation paired with synchronous 2.0s text highlight shimmer conveys live streaming output.',
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required ThemeData theme,
    required bool isDark,
    required String tag,
    required Color tagColor,
    required IconData icon,
    required OrbDesign design,
    required String label,
    required String detail,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF161E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tagColor),
                const SizedBox(width: 8),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // The active ThinkingOrbLabel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: ThinkingOrbLabel(
                label,
                design: design,
                size: OrbSize.small,
                speed: _speed,
                isPaused: _isPaused,
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: PLAYGROUND (交互试验台)
  // ==========================================
  Widget _buildPlaygroundTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Live Preview Stage
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF161E2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Centered large Orb preview
                Center(
                  child: ThinkingOrb(
                    design: _selectedDesign,
                    size: _selectedSize,
                    diameter: _diameter,
                    speed: _speed,
                    isPaused: _isPaused,
                    color: _customColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Shimmering Label Preview
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: ThinkingOrbLabel(
                    _labelTextController.text.isEmpty
                        ? _selectedDesign.accessibilityLabel
                        : _labelTextController.text,
                    design: _selectedDesign,
                    size: OrbSize.small,
                    speed: _speed,
                    isPaused: _isPaused,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Controls
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF161E2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Design Selector
                Text(
                  widget.isChinese ? '选择设计形态' : 'Select Design',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OrbDesign.values.map((d) {
                    final isSelected = d == _selectedDesign;
                    return ChoiceChip(
                      label: Text(_designTitle(d)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedDesign = d),
                    );
                  }).toList(),
                ),
                const Divider(height: 32),

                // 2. Base Size Profile
                Text(
                  widget.isChinese ? '基准微调预设 (Base Size)' : 'Tuned Base Size',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SegmentedButton<OrbSize>(
                  segments: [
                    ButtonSegment(
                      value: OrbSize.regular,
                      label: Text(
                        widget.isChinese ? '常规 (64 pt)' : 'Regular (64 pt)',
                      ),
                    ),
                    ButtonSegment(
                      value: OrbSize.small,
                      label: Text(
                        widget.isChinese ? '微型 (20 pt)' : 'Small (20 pt)',
                      ),
                    ),
                  ],
                  selected: {_selectedSize},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedSize = set.first;
                      _diameter = _selectedSize.points;
                    });
                  },
                ),
                const Divider(height: 32),

                // 3. Diameter Slider
                Row(
                  children: [
                    Text(
                      widget.isChinese
                          ? '物理尺寸直径 (Diameter): ${_diameter.toInt()} pt'
                          : 'Diameter: ${_diameter.toInt()} pt',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          setState(() => _diameter = _selectedSize.points),
                      child: Text(widget.isChinese ? '重置' : 'Default'),
                    ),
                  ],
                ),
                Slider(
                  value: _diameter,
                  min: 16.0,
                  max: 128.0,
                  divisions: 28,
                  label: '${_diameter.toInt()} pt',
                  onChanged: (v) => setState(() => _diameter = v),
                ),
                const Divider(height: 32),

                // 4. Color Tint (Optional)
                Text(
                  widget.isChinese ? '着色模式 (Color Tint)' : 'Color Mode',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: [
                    _buildColorChip(
                      null,
                      widget.isChinese ? '单色 (黑白自适应)' : 'Monochrome',
                    ),
                    _buildColorChip(const Color(0xFF00E5FF), 'Cyan AI'),
                    _buildColorChip(const Color(0xFFB388FF), 'Violet'),
                    _buildColorChip(const Color(0xFF00E676), 'Emerald'),
                    _buildColorChip(const Color(0xFFFFD740), 'Amber'),
                  ],
                ),
                const Divider(height: 32),

                // 5. Custom Label Text
                Text(
                  widget.isChinese ? '自定义状态标语' : 'Custom Status Label',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _labelTextController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    hintText: widget.isChinese
                        ? '输入您希望伴随扫光的文字…'
                        : 'Enter live status text…',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Generated Code Snippet
        Card(
          elevation: 0,
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.isChinese ? '即用代码 (Code)' : 'Code Snippet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      tooltip: widget.isChinese ? '复制代码' : 'Copy Code',
                      onPressed: () {
                        final code = _generateCode();
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.isChinese ? '代码已复制到剪贴板' : 'Code copied!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _generateCode(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorChip(Color? color, String name) {
    final isSelected = _customColor == color;
    return ChoiceChip(
      avatar: color == null
          ? const Icon(Icons.contrast, size: 16)
          : CircleAvatar(backgroundColor: color, radius: 8),
      label: Text(name),
      selected: isSelected,
      onSelected: (_) => setState(() => _customColor = color),
    );
  }

  String _generateCode() {
    final colorParam = _customColor == null
        ? ''
        : ', color: const Color(0x${_customColor!.toARGB32().toRadixString(16).toUpperCase()})';
    final diameterParam = _diameter == _selectedSize.points
        ? ''
        : ', diameter: ${_diameter.toInt()}';
    final speedParam = _speed == 1.0 ? '' : ', speed: $_speed';

    return '''ThinkingOrbLabel(
  '${_labelTextController.text}',
  design: OrbDesign.${_selectedDesign.name},
  size: OrbSize.${_selectedSize.name}$diameterParam$speedParam$colorParam,
);''';
  }
}
