import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/fridge_service.dart';

/// Realistic top-bottom double-door fridge.
/// • TOP  = Freezer door – hinge LEFT, handle RIGHT, opens leftward (rotateY)
/// • BOT  = Fridge door  – same orientation
/// App-theme colours: indigo #2A4E7C family
class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});
  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen>
    with TickerProviderStateMixin {

  // ── App-theme palette ──────────────────────────────────────────────────────
  static const Color _appIndigo  = Color(0xFF2A4E7C);
  static const Color _appDark    = Color(0xFF1A3560);
  static const Color _appMid     = Color(0xFF3A6499);
  static const Color _bodyBg     = Color(0xFF0A1628);
  static const Color _handleCol  = Color(0xFF4A90C4);

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _topCtrl;
  late final AnimationController _botCtrl;
  late final AnimationController _glowCtrl;

  late final Animation<double> _topAngle;
  late final Animation<double> _botAngle;
  late final Animation<double> _topFade;
  late final Animation<double> _botFade;
  late final Animation<double> _glow;

  bool _topOpen = false;
  bool _botOpen = false;

  // ── Fridge data ────────────────────────────────────────────────────────────
  // Lists are mutable; each item is a map from the API that includes '_id'.
  List<Map<String, dynamic>> _frozen = [];
  List<Map<String, dynamic>> _dairy  = [];
  List<Map<String, dynamic>> _vegs   = [];
  List<Map<String, dynamic>> _fruits = [];

  bool _loadingItems = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _topCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _botCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _topAngle = CurvedAnimation(
        parent: _topCtrl, curve: Curves.easeInOutCubic);
    _botAngle = CurvedAnimation(
        parent: _botCtrl, curve: Curves.easeInOutCubic);
    _topFade = CurvedAnimation(
        parent: _topCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn));
    _botFade = CurvedAnimation(
        parent: _botCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn));
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _topCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _topOpen = true);
      if (s == AnimationStatus.dismissed) setState(() => _topOpen = false);
    });
    _botCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _botOpen = true);
      if (s == AnimationStatus.dismissed) setState(() => _botOpen = false);
    });

    // Load items from API after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
  }

  Future<void> _loadItems() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      setState(() { _loadingItems = true; _loadError = null; });
      final grouped = await FridgeService.instance.getGrouped(token);
      if (!mounted) return;
      setState(() {
        _frozen = _mapList(grouped['frozen']);
        _dairy  = _mapList(grouped['dairy']);
        _vegs   = _mapList(grouped['veggies']);
        _fruits = _mapList(grouped['fruits']);
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loadingItems = false; });
    }
  }

  /// Converts API item (with MongoDB types) to a Dart-friendly map.
  List<Map<String, dynamic>> _mapList(List<Map<String, dynamic>>? raw) {
    if (raw == null) return [];
    return raw.map((item) => {
      '_id':   item['_id']?.toString() ?? '',
      'emoji': item['emoji']?.toString() ?? '',
      'label': item['label']?.toString() ?? '',
      'qty':   (item['qty'] as num?)?.toInt() ?? 0,
      'color': (item['color'] as num?)?.toInt() ?? 0xFF2A4E7C,
    }).toList();
  }


  @override
  void dispose() {
    _topCtrl.dispose();
    _botCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _toggleTop() {
    if (_topCtrl.isAnimating) return;
    _topOpen ? _topCtrl.reverse() : _topCtrl.forward();
  }

  void _toggleBot() {
    if (_botCtrl.isAnimating) return;
    _botOpen ? _botCtrl.reverse() : _botCtrl.forward();
  }

  Future<void> _changeQty(
      List<Map<String, dynamic>> list, int i, int d) async {
    HapticFeedback.lightImpact();
    final item = list[i];
    final newQty = ((item['qty'] as int) + d).clamp(0, 999);
    setState(() => item['qty'] = newQty);

    final id    = item['_id']?.toString() ?? '';
    final token = context.read<AuthProvider>().token;
    if (id.isEmpty || token == null) return; // offline / demo item
    try {
      await FridgeService.instance.updateQty(token: token, id: id, delta: d);
    } catch (_) {
      // Silently revert on failure
      if (mounted) setState(() => item['qty'] = (item['qty'] as int) - d);
    }
  }

  // ── Root ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bodyBg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _topBar(),
            Expanded(child: _fridgeUnit()),
            _totalBar(),
          ]),
          // Loading overlay
          if (_loadingItems)
            Container(
              color: _bodyBg.withValues(alpha: 0.75),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90C4)),
              ),
            ),
          // Error overlay
          if (_loadError != null && !_loadingItems)
            Container(
              color: _bodyBg.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A4E7C),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Fridge',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(
            '${_topOpen ? "❄️ Freezer open" : "❄️ Tap freezer"}  •  '
            '${_botOpen ? "🥗 Fridge open" : "🥗 Tap fridge"}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10),
          ),
        ]),
        const Spacer(),
        if (_topOpen || _botOpen)
          GestureDetector(
            onTap: () {
              _topCtrl.reverse();
              _botCtrl.reverse();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _appIndigo.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _appIndigo.withValues(alpha: 0.5)),
              ),
              child: const Text('Close all',
                  style:
                      TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ]),
    );
  }

  // ── Fridge body ────────────────────────────────────────────────────────────
  Widget _fridgeUnit() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight - 4; // border: 2px top + 2px bottom = 4px content loss
        final topH = h * 0.37;
        final botH = h * 0.63;

        return Container(
          width: w,
          decoration: BoxDecoration(
            // Indigo-themed body
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF152D4B), Color(0xFF0F2035)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _appMid.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                  color: _appIndigo.withValues(alpha: 0.4),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 10)),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(children: [

              // ── FREEZER (top) ─────────────────────────────────────────────
              SizedBox(
                height: topH,
                child: AnimatedBuilder(
                  animation: _topCtrl,
                  builder: (ctx, ignored) => Stack(
                    children: [
                      // Interior (always rendered)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _topFade.value,
                          child: _freezerInterior(),
                        ),
                      ),
                      // Door – rotates on LEFT hinge, opens leftward (Y-axis)
                      if (_topAngle.value < 0.98)
                        Positioned.fill(
                          child: Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0009)
                              ..rotateY(
                                  _topAngle.value * (math.pi / 2)),
                            child: _doorPanel(
                              isFreeze: true,
                              onTap: _toggleTop,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Middle divider bar (with right-side hinge detail) ─────────
              _dividerBar(),

              // ── FRIDGE (bottom) ───────────────────────────────────────────
              SizedBox(
                height: botH - 12,
                child: AnimatedBuilder(
                  animation: _botCtrl,
                  builder: (ctx, ignored) => Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: _botFade.value,
                          child: _fridgeInterior(),
                        ),
                      ),
                      if (_botAngle.value < 0.98)
                        Positioned.fill(
                          child: Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0009)
                              ..rotateY(
                                  _botAngle.value * (math.pi / 2)),
                            child: _doorPanel(
                              isFreeze: false,
                              onTap: _toggleBot,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Middle divider bar ─────────────────────────────────────────────────────
  Widget _dividerBar() {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _appDark.withValues(alpha: 0.9),
            _appMid.withValues(alpha: 0.5),
            _appDark.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Hinge screw on right side
          Container(
            margin: const EdgeInsets.only(right: 18),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _handleCol,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 3,
                    offset: const Offset(1, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Single unified door panel (both freezer and fridge) ───────────────────
  Widget _doorPanel({required bool isFreeze, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Indigo-themed door with top-to-bottom gradient
          gradient: LinearGradient(
            colors: isFreeze
                ? [
                    const Color(0xFF1C3D6B),
                    const Color(0xFF163258),
                    const Color(0xFF102546),
                  ]
                : [
                    const Color(0xFF1A3A66),
                    const Color(0xFF142E54),
                    const Color(0xFF0E2240),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [

          // ── Metallic sheen overlay ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ── Left edge hinge line ──────────────────────────────────────
          Positioned(
            top: 0, bottom: 0, left: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),

          // ── Branding / label (centre) ──────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _glow,
                  builder: (ctx, ignored) => Icon(
                    isFreeze
                        ? Icons.ac_unit_rounded
                        : Icons.kitchen_rounded,
                    size: isFreeze ? 44 : 52,
                    color: Colors.white.withValues(
                        alpha: _glow.value * 0.45),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isFreeze ? 'FREEZER' : 'BITEZ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: isFreeze ? 14 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isFreeze ? 5 : 7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFreeze ? '– tap to open –' : '– tap to open –',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Vertical handle on RIGHT side ─────────────────────────────
          Positioned(
            top: 0, bottom: 0, right: 20,
            child: Center(
              child: Container(
                width: 10,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _handleCol.withValues(alpha: 0.9),
                      _handleCol.withValues(alpha: 0.5),
                      _handleCol.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(-3, 0)),
                    BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(1, 0)),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Freezer interior ──────────────────────────────────────────────────────
  Widget _freezerInterior() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB3E5FC), Color(0xFFE1F5FE), Color(0xFFBBDEFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _FrostPainter())),
        Positioned(top: 0, left: 0, right: 0,
            child: _lightStrip(isFreeze: true)),
        Positioned.fill(
          top: 22,
          child: Column(children: [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                const Text('❄️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                const Text('FREEZER',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF01579B),
                        letterSpacing: 2)),
                const Spacer(),
                _addBtn(() => _showAddDialog(
                    _frozen, const Color(0xFF0288D1), 'Add Frozen Item')),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _topOpen
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _frozen.length,
                      itemBuilder: (ctx, i) =>
                          _foodTile(_frozen, i, isFreeze: true),
                    )
                  : const SizedBox(),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Fridge interior ───────────────────────────────────────────────────────
  Widget _fridgeInterior() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD6EAF8), Color(0xFFEBF5FB), Color(0xFFD6EAF8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        _lightStrip(isFreeze: false),
        Expanded(
          child: _botOpen
              ? ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _shelf(label: 'Dairy & Eggs', emoji: '🥛',
                        color: const Color(0xFF1565C0), items: _dairy),
                    _glassShelf(),
                    _shelf(label: 'Vegetables', emoji: '🥗',
                        color: const Color(0xFF2E7D32), items: _vegs),
                    _glassShelf(),
                    _shelf(label: 'Fruits', emoji: '🍑',
                        color: const Color(0xFFE65100), items: _fruits),
                  ],
                )
              : const SizedBox(),
        ),
      ]),
    );
  }

  // ── Light strip ───────────────────────────────────────────────────────────
  Widget _lightStrip({required bool isFreeze}) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (ctx, ignored) => Container(
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFreeze
                ? [
                    const Color(0xFFE1F5FE).withValues(alpha: 0.8),
                    const Color(0xFFE1F5FE),
                    const Color(0xFFE1F5FE).withValues(alpha: 0.8),
                  ]
                : [
                    const Color(0xFFE3F2FD).withValues(alpha: 0.8),
                    const Color(0xFFE3F2FD),
                    const Color(0xFFE3F2FD).withValues(alpha: 0.8),
                  ],
          ),
        ),
        child: Center(
          child: Container(
            height: 6,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: (isFreeze ? Colors.lightBlue : Colors.white)
                      .withValues(alpha: _glow.value * 0.9),
                  blurRadius: 14,
                  spreadRadius: 4,
                ),
              ],
              gradient: LinearGradient(
                colors: isFreeze
                    ? [
                        Colors.lightBlue.shade100,
                        Colors.white,
                        Colors.lightBlue.shade100,
                      ]
                    : [Colors.white70, Colors.white, Colors.white70],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Glass shelf divider ───────────────────────────────────────────────────
  Widget _glassShelf() {
    return Container(
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x44A0C4E0),
            Color(0x88A0C4E0),
            Color(0xBB6EB0D4),
            Color(0x66A0C4E0),
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 5,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: 2,
              offset: const Offset(0, -1)),
        ],
      ),
    );
  }

  // ── Shelf row ─────────────────────────────────────────────────────────────
  Widget _shelf({
    required String label,
    required String emoji,
    required Color color,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.4)),
          const Spacer(),
          _addBtn(() => _showAddDialog(items, color, 'Add $label')),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 138,    // tall enough so label never overflows
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _foodTile(items, i, isFreeze: false),
          ),
        ),
      ]),
    );
  }

  // ── Food tile ─────────────────────────────────────────────────────────────
  Widget _foodTile(List<Map<String, dynamic>> list, int i,
      {required bool isFreeze}) {
    final item = list[i];
    final qty  = item['qty'] as int;
    final ac   = Color(item['color'] as int);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 220 + i * 45),
      curve: Curves.easeOutBack,
      builder: (ctx, v, child) =>
          Transform.scale(scale: v, child: child),
      child: Container(
        width: 94,
        margin: const EdgeInsets.only(right: 9, bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isFreeze ? const Color(0xFFDEF0FD) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ac.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: ac.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large emoji in circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ac.withValues(alpha: isFreeze ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(item['emoji'] as String,
                    style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 5),
            // Label – FittedBox prevents overflow
            SizedBox(
              width: 82,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item['label'] as String,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isFreeze
                          ? const Color(0xFF01579B)
                          : Colors.grey.shade700),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Qty row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _qBtn(
                icon: qty == 0
                    ? Icons.delete_outline_rounded
                    : Icons.remove,
                color: qty == 0 ? Colors.red.shade400 : ac,
                onTap: qty > 0
                    ? () => _changeQty(list, i, -1)
                    : () => _confirmRemove(list, i),
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text('$qty',
                    key: ValueKey(qty),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: qty == 0 ? Colors.red.shade400 : ac)),
              ),
              const SizedBox(width: 5),
              _qBtn(
                icon: Icons.add,
                color: ac,
                onTap: () => _changeQty(list, i, 1),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Small + button ────────────────────────────────────────────────────────
  Widget _addBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _appIndigo.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _appIndigo.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.add_rounded, size: 12, color: Color(0xFF2A4E7C)),
          SizedBox(width: 2),
          Text('Add',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF2A4E7C),
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Qty button ────────────────────────────────────────────────────────────
  Widget _qBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  // ── Add item dialog ────────────────────────────────────────────────────────
  void _showAddDialog(
      List<Map<String, dynamic>> shelf, Color color, String title) {
    final ec = TextEditingController();
    final lc = TextEditingController();
    final qc = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(ec, 'Emoji  e.g. 🥑', color),
          const SizedBox(height: 10),
          _field(lc, 'Name', color),
          const SizedBox(height: 10),
          _field(qc, 'Qty', color, num: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final e = ec.text.trim();
              final l = lc.text.trim();
              final q = int.tryParse(qc.text) ?? 1;
              if (e.isNotEmpty && l.isNotEmpty) {
                setState(() => shelf.add({
                      'emoji': e,
                      'label': l,
                      'qty': q,
                      'color': color.toARGB32(),
                    }));
                Navigator.pop(ctx);
              }
            },
            child: Text('Add',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, Color col,
      {bool num = false}) {
    return TextField(
      controller: c,
      keyboardType: num ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        enabledBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: col.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: col),
            borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ── Confirm remove ─────────────────────────────────────────────────────────
  void _confirmRemove(List<Map<String, dynamic>> list, int i) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Remove ${list[i]['label']}?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Out of stock. Remove from shelf?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() => list.removeAt(i));
              Navigator.pop(ctx);
            },
            child: const Text('Remove',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Summary bar ────────────────────────────────────────────────────────────
  Widget _totalBar() {
    int tot(List<Map<String, dynamic>> l) =>
        l.fold(0, (s, e) => s + (e['qty'] as int));
    final fz = tot(_frozen);
    final d  = tot(_dairy);
    final v  = tot(_vegs);
    final fr = tot(_fruits);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E4A), Color(0xFF132540)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _appIndigo.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chip('❄️', 'Frozen', fz),
          _div(),
          _chip('🥛', 'Dairy', d),
          _div(),
          _chip('🥗', 'Vegs', v),
          _div(),
          _chip('🍑', 'Fruits', fr),
          _div(),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${fz + d + v + fr}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const Text('Total',
                style:
                    TextStyle(color: Colors.white38, fontSize: 9)),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String emoji, String label, int count) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text('$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 9)),
    ]);
  }

  Widget _div() => Container(
      height: 32, width: 1,
      color: Colors.white.withValues(alpha: 0.1));
}

// ── Frost painter ─────────────────────────────────────────────────────────────
class _FrostPainter extends CustomPainter {
  final _rand = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int k = 0; k < 55; k++) {
      final x = _rand.nextDouble() * size.width;
      final y = _rand.nextDouble() * size.height;
      final r = 2.5 + _rand.nextDouble() * 7.0;
      for (int arm = 0; arm < 6; arm++) {
        final a = arm * math.pi / 3;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + math.cos(a) * r, y + math.sin(a) * r),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
