import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Describes a bitmoji-style cartoon avatar's customizable properties.
class AvatarConfig {
  final bool isBoy;
  final Color skinTone;
  final Color hairColor;
  final Color shirtColor;
  final int hairStyle; // 0 or 1
  final String label;

  const AvatarConfig({
    required this.isBoy,
    required this.skinTone,
    required this.hairColor,
    required this.shirtColor,
    required this.hairStyle,
    this.label = 'Custom Avatar',
  });

  Map<String, dynamic> toJson() => {
        'isBoy': isBoy,
        'skinTone': skinTone.toARGB32(),
        'hairColor': hairColor.toARGB32(),
        'shirtColor': shirtColor.toARGB32(),
        'hairStyle': hairStyle,
        'label': label,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        isBoy: json['isBoy'] as bool? ?? true,
        skinTone: Color(json['skinTone'] as int? ?? 0xFFFFDBAC),
        hairColor: Color(json['hairColor'] as int? ?? 0xFF2C1810),
        shirtColor: Color(json['shirtColor'] as int? ?? 0xFF4A90D9),
        hairStyle: json['hairStyle'] as int? ?? 0,
        label: json['label'] as String? ?? 'Custom Avatar',
      );

  AvatarConfig copyWith({
    bool? isBoy,
    Color? skinTone,
    Color? hairColor,
    Color? shirtColor,
    int? hairStyle,
    String? label,
  }) {
    return AvatarConfig(
      isBoy: isBoy ?? this.isBoy,
      skinTone: skinTone ?? this.skinTone,
      hairColor: hairColor ?? this.hairColor,
      shirtColor: shirtColor ?? this.shirtColor,
      hairStyle: hairStyle ?? this.hairStyle,
      label: label ?? this.label,
    );
  }
}

/// Available customizable options
class AvatarOptions {
  static const List<Color> skinTones = [
    Color(0xFFFFDBAC),
    Color(0xFFF0C094),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];

  static const List<Color> hairColors = [
    Color(0xFF120500),
    Color(0xFF2C1810),
    Color(0xFF5C3317),
    Color(0xFFDBAA44),
    Color(0xFFB55239),
    Color(0xFFE84393),
  ];

  static const List<Color> shirtColors = [
    Color(0xFF2A4E7C),
    Color(0xFF1D9E75),
    Color(0xFFD45F2A),
    Color(0xFF7B4DAA),
    Color(0xFFE84393),
    Color(0xFF00BCD4),
    Color(0xFFE67E22),
    Color(0xFF3498DB),
  ];
}

/// 12 preset cute cartoon avatars – 6 boys + 6 girls.
const List<AvatarConfig> kAvatarPresets = [
  // ── Boys (0 = neat dome  |  1 = spiky) ─────────────────────────────────
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFFFDBAC), hairColor: Color(0xFF2C1810), shirtColor: Color(0xFF4A90D9), hairStyle: 0, label: 'Boy 1'),
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFFFDBAC), hairColor: Color(0xFF7B4B2A), shirtColor: Color(0xFF1D9E75), hairStyle: 1, label: 'Boy 2'),
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFF0C094), hairColor: Color(0xFF1A0800), shirtColor: Color(0xFFD45F2A), hairStyle: 0, label: 'Boy 3'),
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFF0C094), hairColor: Color(0xFF5C3317), shirtColor: Color(0xFF7B4DAA), hairStyle: 1, label: 'Boy 4'),
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFC68642), hairColor: Color(0xFF120500), shirtColor: Color(0xFF2A4E7C), hairStyle: 0, label: 'Boy 5'),
  AvatarConfig(isBoy: true,  skinTone: Color(0xFFC68642), hairColor: Color(0xFF2D1200), shirtColor: Color(0xFFE67E22), hairStyle: 1, label: 'Boy 6'),
  // ── Girls (0 = long hair  |  1 = bun) ──────────────────────────────────
  AvatarConfig(isBoy: false, skinTone: Color(0xFFFFDBAC), hairColor: Color(0xFFDBAA44), shirtColor: Color(0xFFE84393), hairStyle: 0, label: 'Girl 1'),
  AvatarConfig(isBoy: false, skinTone: Color(0xFFFFDBAC), hairColor: Color(0xFF7B4B2A), shirtColor: Color(0xFF9B59B6), hairStyle: 1, label: 'Girl 2'),
  AvatarConfig(isBoy: false, skinTone: Color(0xFFF0C094), hairColor: Color(0xFF3D2B1F), shirtColor: Color(0xFFE74C3C), hairStyle: 0, label: 'Girl 3'),
  AvatarConfig(isBoy: false, skinTone: Color(0xFFF0C094), hairColor: Color(0xFF1A0800), shirtColor: Color(0xFF3498DB), hairStyle: 1, label: 'Girl 4'),
  AvatarConfig(isBoy: false, skinTone: Color(0xFFC68642), hairColor: Color(0xFF2C1810), shirtColor: Color(0xFFE91E63), hairStyle: 0, label: 'Girl 5'),
  AvatarConfig(isBoy: false, skinTone: Color(0xFFC68642), hairColor: Color(0xFF120500), shirtColor: Color(0xFF00BCD4), hairStyle: 1, label: 'Girl 6'),
];

/// Renders a cartoon avatar clipped to a circle at the given [size].
/// Can accept an [index] into [kAvatarPresets] OR a custom [config].
class AvatarWidget extends StatelessWidget {
  final int? index;
  final AvatarConfig? config;
  final double size;

  const AvatarWidget({
    super.key,
    this.index,
    this.config,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final AvatarConfig cfg;
    if (config != null) {
      cfg = config!;
    } else if (index != null) {
      cfg = kAvatarPresets[index!.clamp(0, kAvatarPresets.length - 1)];
    } else {
      cfg = kAvatarPresets[0];
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AvatarPainter(cfg),
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _AvatarPainter extends CustomPainter {
  final AvatarConfig cfg;

  _AvatarPainter(this.cfg);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final hcy = h * 0.41; // head centre Y

    // 1 ── Soft tinted background ─────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = cfg.shirtColor.withValues(alpha: 0.20),
    );

    // 2 ── Shirt / body ────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - w * 0.44, h * 0.72, cx + w * 0.44, h + 2),
        topLeft: Radius.circular(w * 0.13),
        topRight: Radius.circular(w * 0.13),
      ),
      Paint()..color = cfg.shirtColor,
    );

    // 3 ── Neck ────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, h * 0.714), width: w * 0.17, height: h * 0.088),
        Radius.circular(3),
      ),
      Paint()..color = cfg.skinTone,
    );

    // 4 ── Ears (behind head) ──────────────────────────────────────────────────
    final earP = Paint()..color = cfg.skinTone;
    canvas.drawCircle(Offset(cx - w * 0.302, hcy + h * 0.018), w * 0.067, earP);
    canvas.drawCircle(Offset(cx + w * 0.302, hcy + h * 0.018), w * 0.067, earP);

    // 5 ── Head oval ───────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, hcy), width: w * 0.62, height: h * 0.67),
      Paint()..color = cfg.skinTone,
    );

    // 6 ── Hair ────────────────────────────────────────────────────────────────
    if (cfg.isBoy) {
      _boyHair(canvas, w, h, cx, hcy);
    } else {
      _girlHair(canvas, w, h, cx, hcy);
    }

    // 7 ── Eyebrows ────────────────────────────────────────────────────────────
    _eyebrows(canvas, w, h, cx, hcy);

    // 8 ── Eyes ────────────────────────────────────────────────────────────────
    _eyes(canvas, w, h, cx, hcy);

    // 9 ── Nose (subtle nostrils) ──────────────────────────────────────────────
    _nose(canvas, w, h, cx, hcy);

    // 10 ── Mouth (smile + teeth) ──────────────────────────────────────────────
    _mouth(canvas, w, h, cx, hcy);

    // 11 ── Blush cheeks ───────────────────────────────────────────────────────
    _blush(canvas, w, h, cx, hcy);
  }

  // ── Hair helpers ────────────────────────────────────────────────────────────

  void _boyHair(Canvas canvas, double w, double h, double cx, double hcy) {
    final p = Paint()..color = cfg.hairColor;

    if (cfg.hairStyle == 0) {
      // Neat dome cap
      final path = Path();
      path.moveTo(cx - w * 0.290, hcy - h * 0.220);
      path.cubicTo(
        cx - w * 0.275, hcy - h * 0.470,
        cx + w * 0.275, hcy - h * 0.470,
        cx + w * 0.290, hcy - h * 0.220,
      );
      path.cubicTo(
        cx + w * 0.140, hcy - h * 0.305,
        cx - w * 0.140, hcy - h * 0.305,
        cx - w * 0.290, hcy - h * 0.220,
      );
      path.close();
      canvas.drawPath(path, p);
    } else {
      // Spiky hair: base band + 3 spikes
      final base = Path();
      base.moveTo(cx - w * 0.290, hcy - h * 0.200);
      base.quadraticBezierTo(cx, hcy - h * 0.330, cx + w * 0.290, hcy - h * 0.200);
      base.quadraticBezierTo(cx + w * 0.140, hcy - h * 0.265, cx, hcy - h * 0.280);
      base.quadraticBezierTo(cx - w * 0.140, hcy - h * 0.265, cx - w * 0.290, hcy - h * 0.200);
      canvas.drawPath(base, p);
      for (final xf in [-0.130, 0.000, 0.130]) {
        final spike = Path();
        spike.moveTo(cx + w * (xf - 0.090), hcy - h * 0.210);
        spike.lineTo(cx + w * xf, hcy - h * 0.510);
        spike.lineTo(cx + w * (xf + 0.090), hcy - h * 0.210);
        spike.close();
        canvas.drawPath(spike, p);
      }
    }
  }

  void _girlHair(Canvas canvas, double w, double h, double cx, double hcy) {
    final p = Paint()..color = cfg.hairColor;

    if (cfg.hairStyle == 0) {
      // Long flowing side panels + top dome
      for (final side in [-1.0, 1.0]) {
        final panel = Path();
        panel.moveTo(cx + side * w * 0.290, hcy - h * 0.195);
        panel.quadraticBezierTo(
          cx + side * w * 0.470, hcy + h * 0.070,
          cx + side * w * 0.425, hcy + h * 0.390,
        );
        panel.quadraticBezierTo(
          cx + side * w * 0.380, hcy + h * 0.500,
          cx + side * w * 0.260, hcy + h * 0.465,
        );
        panel.lineTo(cx + side * w * 0.240, hcy + h * 0.255);
        panel.quadraticBezierTo(
          cx + side * w * 0.280, hcy + h * 0.075,
          cx + side * w * 0.200, hcy - h * 0.010,
        );
        panel.lineTo(cx + side * w * 0.050, hcy - h * 0.010);
        panel.lineTo(cx + side * w * 0.095, hcy - h * 0.270);
        panel.quadraticBezierTo(
          cx + side * w * 0.200, hcy - h * 0.260,
          cx + side * w * 0.290, hcy - h * 0.195,
        );
        canvas.drawPath(panel, p);
      }
      // Top dome
      final top = Path();
      top.moveTo(cx - w * 0.290, hcy - h * 0.195);
      top.quadraticBezierTo(cx - w * 0.240, hcy - h * 0.445, cx, hcy - h * 0.460);
      top.quadraticBezierTo(cx + w * 0.240, hcy - h * 0.445, cx + w * 0.290, hcy - h * 0.195);
      top.quadraticBezierTo(cx + w * 0.095, hcy - h * 0.300, cx, hcy - h * 0.320);
      top.quadraticBezierTo(cx - w * 0.095, hcy - h * 0.300, cx - w * 0.290, hcy - h * 0.195);
      canvas.drawPath(top, p);
    } else {
      // Bun: top band + bun circle + short side panels
      final band = Path();
      band.moveTo(cx - w * 0.290, hcy - h * 0.170);
      band.quadraticBezierTo(cx - w * 0.260, hcy - h * 0.390, cx, hcy - h * 0.410);
      band.quadraticBezierTo(cx + w * 0.260, hcy - h * 0.390, cx + w * 0.290, hcy - h * 0.170);
      band.quadraticBezierTo(cx + w * 0.140, hcy - h * 0.260, cx, hcy - h * 0.280);
      band.quadraticBezierTo(cx - w * 0.140, hcy - h * 0.260, cx - w * 0.290, hcy - h * 0.170);
      canvas.drawPath(band, p);
      // Bun circle
      canvas.drawCircle(Offset(cx, hcy - h * 0.510), w * 0.155, p);
      // Side panels
      for (final side in [-1.0, 1.0]) {
        final panel = Path();
        panel.moveTo(cx + side * w * 0.290, hcy - h * 0.140);
        panel.quadraticBezierTo(
          cx + side * w * 0.410, hcy + h * 0.040,
          cx + side * w * 0.380, hcy + h * 0.200,
        );
        panel.quadraticBezierTo(
          cx + side * w * 0.350, hcy + h * 0.280,
          cx + side * w * 0.260, hcy + h * 0.240,
        );
        panel.lineTo(cx + side * w * 0.170, hcy + h * 0.060);
        panel.quadraticBezierTo(
          cx + side * w * 0.210, hcy - h * 0.060,
          cx + side * w * 0.190, hcy - h * 0.140,
        );
        panel.quadraticBezierTo(
          cx + side * w * 0.250, hcy - h * 0.170,
          cx + side * w * 0.290, hcy - h * 0.140,
        );
        canvas.drawPath(panel, p);
      }
    }
  }

  // ── Face feature helpers ─────────────────────────────────────────────────────

  void _eyebrows(Canvas canvas, double w, double h, double cx, double hcy) {
    final p = Paint()
      ..color = cfg.hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.027
      ..strokeCap = StrokeCap.round;
    final by = hcy - h * 0.087;
    final xo = w * 0.134;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - xo, by), width: w * 0.175, height: h * 0.072),
      math.pi * 1.14, math.pi * 0.72, false, p,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + xo, by), width: w * 0.175, height: h * 0.072),
      math.pi * 0.14, math.pi * 0.72, false, p,
    );
  }

  void _eyes(Canvas canvas, double w, double h, double cx, double hcy) {
    final ey = hcy + h * 0.034;
    final xo = w * 0.134;
    final ew = w * 0.107;
    final eh = h * 0.083;
    for (final s in [-1.0, 1.0]) {
      final ex = cx + s * xo;
      // White
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, ey), width: ew, height: eh),
        Paint()..color = Colors.white,
      );
      // Iris
      final ir = eh * 0.37;
      canvas.drawCircle(Offset(ex, ey), ir, Paint()..color = const Color(0xFF2A1A0E));
      // Highlight sparkle
      canvas.drawCircle(
        Offset(ex + ir * 0.42, ey - ir * 0.42),
        ir * 0.30,
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      );
    }
    // Upper eyelid line
    final lid = Paint()
      ..color = const Color(0xFF1A0A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.021
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + s * xo, ey), width: ew * 1.07, height: eh * 1.07),
        math.pi, math.pi, false, lid,
      );
    }
  }

  void _nose(Canvas canvas, double w, double h, double cx, double hcy) {
    final hsl = HSLColor.fromColor(cfg.skinTone);
    final dark =
        hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
    canvas.drawCircle(Offset(cx - w * 0.040, hcy + h * 0.122), w * 0.022, Paint()..color = dark);
    canvas.drawCircle(Offset(cx + w * 0.040, hcy + h * 0.122), w * 0.022, Paint()..color = dark);
  }

  void _mouth(Canvas canvas, double w, double h, double cx, double hcy) {
    final my = hcy + h * 0.226;
    // Teeth fill
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, my + h * 0.005), width: w * 0.245, height: h * 0.078),
      0, math.pi, false, Paint()..color = Colors.white,
    );
    // Smile outline
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, my), width: w * 0.265, height: h * 0.092),
      0, math.pi, false,
      Paint()
        ..color = const Color(0xFFAA3355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round,
    );
  }

  void _blush(Canvas canvas, double w, double h, double cx, double hcy) {
    final p = Paint()..color = const Color(0xFFFF7799).withValues(alpha: 0.34);
    canvas.drawCircle(Offset(cx - w * 0.210, hcy + h * 0.168), w * 0.082, p);
    canvas.drawCircle(Offset(cx + w * 0.210, hcy + h * 0.168), w * 0.082, p);
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.cfg != cfg;
}
