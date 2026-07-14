// import 'package:flutter/material.dart';

// /// Draws 3 curved steam wisps that continuously rise and fade.
// /// `phase` runs 0 -> 1 on a loop (driven by an AnimationController.repeat()).
// /// `groupOpacity` lets the whole steam cluster be faded out separately,
// /// e.g. once the bowl animates away and the login form appears.
// class SteamPainter extends CustomPainter {
//   final double phase;
//   final double groupOpacity;

//   SteamPainter({required this.phase, required this.groupOpacity});

//   // One wisp's opacity/rise curve for a given local phase (0..1).
//   double _wispOpacity(double p) {
//     if (p < 0.3) return (p / 0.3) * 0.65; // ramp up
//     return 0.65 * (1 - ((p - 0.3) / 0.7)); // ramp down to 0
//   }

//   double _wispRise(double p) => -38.0 * p;

//   void _drawWisp(Canvas canvas, Offset base, double localPhase, Color color) {
//     final opacity = (_wispOpacity(localPhase) * groupOpacity).clamp(0.0, 1.0);
//     if (opacity <= 0) return;

//     final riseY = _wispRise(localPhase);
//     final paint = Paint()
//       ..color = color.withOpacity(opacity)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 5
//       ..strokeCap = StrokeCap.round;

//     final path = Path();
//     path.moveTo(base.dx, base.dy + riseY);
//     path.cubicTo(
//       base.dx - 4, base.dy - 30 + riseY,
//       base.dx + 12, base.dy - 40 + riseY,
//       base.dx + 5, base.dy - 70 + riseY,
//     );
//     canvas.drawPath(path, paint);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     const color = Color(0xFFB4B2A9);
//     // Three wisps with staggered phase offsets so they don't rise in sync.
//     final offsets = [0.0, 0.33, 0.66];
//     final bases = [
//       Offset(size.width * 0.36, size.height * 0.92),
//       Offset(size.width * 0.5, size.height * 0.92),
//       Offset(size.width * 0.64, size.height * 0.92),
//     ];
//     for (var i = 0; i < 3; i++) {
//       final localPhase = (phase + offsets[i]) % 1.0;
//       _drawWisp(canvas, bases[i], localPhase, color);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant SteamPainter oldDelegate) {
//     return oldDelegate.phase != phase || oldDelegate.groupOpacity != groupOpacity;
//   }
// }


//2nd one good
// import 'package:flutter/material.dart';

// /// Draws several curved steam wisps rising off the bowl's rim, looping
// /// continuously. Sized to fill whatever canvas it's given — designed to
// /// sit directly above a BowlPainter of the same width.
// ///
// /// `phase` runs 0 -> 1 on a loop (drive it with AnimationController.repeat()).
// /// `groupOpacity` fades the whole cluster, e.g. when the splash screen
// /// cross-fades into the login screen.
// class SteamPainter extends CustomPainter {
//   final double phase;
//   final double groupOpacity;
//   final int wispCount;

//   SteamPainter({
//     required this.phase,
//     required this.groupOpacity,
//     this.wispCount = 5,
//   });

//   double _wispOpacity(double p) {
//     if (p < 0.25) return (p / 0.25) * 0.55;
//     return 0.55 * (1 - ((p - 0.25) / 0.75));
//   }

//   void _drawWisp(Canvas canvas, Offset base, double riseHeight, double localPhase, Color color) {
//     final opacity = (_wispOpacity(localPhase) * groupOpacity).clamp(0.0, 1.0);
//     if (opacity <= 0) return;

//     final riseY = -riseHeight * localPhase;
//     final sway = 14 * (0.5 - (localPhase - 0.5).abs()); // gentle side drift mid-rise

//     final paint = Paint()
//       ..color = color.withOpacity(opacity)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 6
//       ..strokeCap = StrokeCap.round;

//     final path = Path();
//     path.moveTo(base.dx, base.dy + riseY);
//     path.cubicTo(
//       base.dx - sway, base.dy + riseY - riseHeight * 0.35,
//       base.dx + sway, base.dy + riseY - riseHeight * 0.55,
//       base.dx + sway * 0.4, base.dy + riseY - riseHeight * 0.85,
//     );
//     canvas.drawPath(path, paint);
//   }

//   @override
//   void paint(Canvas canvas, Size size) {
//     const color = Color(0xFFE4E0D6);
//     final riseHeight = size.height * 0.75;
//     final baseY = size.height * 0.98;

//     final offsets = List.generate(wispCount, (i) => i / wispCount);
//     final spacing = size.width * 0.7 / (wispCount - 1);
//     final startX = size.width * 0.15;

//     for (int i = 0; i < wispCount; i++) {
//       final localPhase = (phase + offsets[i]) % 1.0;
//       final base = Offset(startX + spacing * i, baseY);
//       _drawWisp(canvas, base, riseHeight, localPhase, color);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant SteamPainter oldDelegate) {
//     return oldDelegate.phase != phase || oldDelegate.groupOpacity != groupOpacity;
//   }
// }



//3rd one better fix
import 'package:flutter/material.dart';

/// Draws several curved steam wisps rising off the bowl's rim, looping
/// continuously. Sized to fill whatever canvas it's given — designed to
/// sit directly above a BowlPainter of the same width.
///
/// `phase` runs 0 -> 1 on a loop (drive it with AnimationController.repeat()).
/// `groupOpacity` fades the whole cluster, e.g. when the splash screen
/// cross-fades into the login screen.
class SteamPainter extends CustomPainter {
  final double phase;
  final double groupOpacity;
  final int wispCount;

  SteamPainter({
    required this.phase,
    required this.groupOpacity,
    this.wispCount = 5,
  });

  double _wispOpacity(double p) {
    if (p < 0.25) return (p / 0.25) * 0.55;
    return 0.55 * (1 - ((p - 0.25) / 0.75));
  }

  void _drawWisp(Canvas canvas, Offset base, double riseHeight, double localPhase, Color color) {
    final opacity = (_wispOpacity(localPhase) * groupOpacity).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final riseY = -riseHeight * localPhase;
    final sway = 14 * (0.5 - (localPhase - 0.5).abs()); // gentle side drift mid-rise

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(base.dx, base.dy + riseY);
    path.cubicTo(
      base.dx - sway, base.dy + riseY - riseHeight * 0.35,
      base.dx + sway, base.dy + riseY - riseHeight * 0.55,
      base.dx + sway * 0.4, base.dy + riseY - riseHeight * 0.85,
    );
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFE4E0D6);
    final riseHeight = size.height * 0.75;
    final baseY = size.height * 0.98;

    final offsets = List.generate(wispCount, (i) => i / wispCount);
    final spacing = size.width * 0.7 / (wispCount - 1);
    final startX = size.width * 0.15;

    for (int i = 0; i < wispCount; i++) {
      final localPhase = (phase + offsets[i]) % 1.0;
      final base = Offset(startX + spacing * i, baseY);
      _drawWisp(canvas, base, riseHeight, localPhase, color);
    }
  }

  @override
  bool shouldRepaint(covariant SteamPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.groupOpacity != groupOpacity;
  }
}




