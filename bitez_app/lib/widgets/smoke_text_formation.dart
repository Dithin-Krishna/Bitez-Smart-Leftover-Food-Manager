import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Renders "BITEZ" as hundreds of small smoke-colored dots that rise up
/// from scattered positions below and settle into the actual letterforms —
/// a real particle-formation effect, not just a blurred static label.
///
/// How it works: the word is rasterized once (off-screen) to read which
/// pixels belong to the letters. Each "on" pixel becomes a target point for
/// one particle. Particles start below and to the side of their target and
/// converge into place as [controller] runs through [startFraction] to
/// [endFraction], with a soft group blur that clears as they settle.
class SmokeTextFormation extends StatefulWidget {
  final Animation<double> controller;
  final double startFraction;
  final double endFraction;
  final String text;
  final double fontSize;
  final Color color;

  const SmokeTextFormation({
    super.key,
    required this.controller,
    required this.startFraction,
    required this.endFraction,
    this.text = 'BITEZ',
    this.fontSize = 64,
    this.color = const Color(0xFF2A4E7C),
  });

  @override
  State<SmokeTextFormation> createState() => _SmokeTextFormationState();
}

class _SmokeTextFormationState extends State<SmokeTextFormation> {
  List<Offset>? _targets;
  List<Offset>? _starts;
  List<double>? _delays;
  List<double>? _curls;
  Size? _textSize;

  @override
  void initState() {
    super.initState();
    _buildParticles();
  }

  Future<void> _buildParticles() async {
    final tp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: const Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width.ceil();
    final h = tp.height.ceil();
    if (w <= 0 || h <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    tp.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final targets = <Offset>[];
    const stride = 3; // lower = more particles = denser letters
    for (int y = 0; y < h; y += stride) {
      for (int x = 0; x < w; x += stride) {
        final idx = (y * w + x) * 4;
        final alpha = bytes[idx + 3];
        if (alpha > 120) {
          targets.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    final rand = Random(7); // fixed seed so layout is stable across rebuilds
    final starts = <Offset>[];
    final delays = <double>[];
    final curls = <double>[];
    for (final t in targets) {
      final dx = (rand.nextDouble() - 0.5) * 100;
      final dy = 50 + rand.nextDouble() * 110; // particles rise up into place
      starts.add(Offset(t.dx + dx, t.dy + dy));
      delays.add(rand.nextDouble() * 0.4); // stagger so it "assembles" gradually
      curls.add((rand.nextDouble() - 0.5) * 2); // swirl direction/strength
    }

    if (!mounted) return;
    setState(() {
      _targets = targets;
      _starts = starts;
      _delays = delays;
      _curls = curls;
      _textSize = Size(w.toDouble(), h.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_targets == null || _textSize == null) return const SizedBox.shrink();

    final curved = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(
        widget.startFraction.clamp(0.0, 1.0),
        widget.endFraction.clamp(0.0, 1.0),
        curve: Curves.linear,
      ),
    );

    return SizedBox(
      width: _textSize!.width,
      height: _textSize!.height,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final groupBlur = 9 * (1 - curved.value);
          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: groupBlur, sigmaY: groupBlur),
            child: CustomPaint(
              painter: _SmokeParticlesPainter(
                targets: _targets!,
                starts: _starts!,
                delays: _delays!,
                curls: _curls!,
                progress: curved.value,
                color: widget.color,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SmokeParticlesPainter extends CustomPainter {
  final List<Offset> targets;
  final List<Offset> starts;
  final List<double> delays;
  final List<double> curls;
  final double progress;
  final Color color;

  _SmokeParticlesPainter({
    required this.targets,
    required this.starts,
    required this.delays,
    required this.curls,
    required this.progress,
    required this.color,
  });

  // Moves a particle from start to target along a curved (bezier) path
  // instead of a straight line, with the curl bowing out early and
  // straightening as the particle settles — like a wisp curling into place.
  Offset _swirlPosition(Offset start, Offset target, double local, double curl) {
    final dir = target - start;
    final perp = Offset(-dir.dy, dir.dx);
    final perpLen = perp.distance;
    final perpNorm = perpLen == 0 ? Offset.zero : perp / perpLen;
    final swirl = perpNorm * curl * 46 * (1 - local);
    final control = Offset.lerp(start, target, 0.5)! + swirl;
    final a = Offset.lerp(start, control, local)!;
    final b = Offset.lerp(control, target, local)!;
    return Offset.lerp(a, b, local)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < targets.length; i++) {
      final delay = delays[i];
      double local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(local);
      if (eased <= 0) continue;
      final pos = _swirlPosition(starts[i], targets[i], eased, curls[i]);
      // slight shimmer while still forming, settles once fully in place
      final shimmer = eased < 1 ? (sin((i * 12.9898 + progress * 30)) * 0.08) : 0.0;
      final opacity = (eased * 0.9 + shimmer).clamp(0.0, 0.95);
      paint.color = color.withOpacity(opacity);
      final radius = 2.3 - (1 - eased) * 0.4;
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokeParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}