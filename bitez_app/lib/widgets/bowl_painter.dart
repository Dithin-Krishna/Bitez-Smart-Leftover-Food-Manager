// import 'package:flutter/material.dart';

// /// Draws a simple flat-style bowl with three food items inside it.
// /// Sized to a 120x120 box, same proportions as the design mockup.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   @override
//   void paint(Canvas canvas, Size size) {
//     final double w = size.width;
//     final double h = size.height;

//     // Rim (background ellipse behind the bowl body)
//     final rimPaint = Paint()..color = const Color(0xFF1D9E75);
//     canvas.drawOval(
//       Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: w * 0.77, height: h * 0.23),
//       rimPaint,
//     );

//     // Bowl body (a curved wedge, like the SVG path)
//     final bowlPaint = Paint()..color = const Color(0xFF0F6E56);
//     final bowlPath = Path();
//     bowlPath.moveTo(w * 0.15, h * 0.57);
//     bowlPath.quadraticBezierTo(w * 0.5, h * 0.83, w * 0.85, h * 0.57);
//     bowlPath.lineTo(w * 0.80, h * 0.65);
//     bowlPath.quadraticBezierTo(w * 0.5, h * 0.88, w * 0.20, h * 0.65);
//     bowlPath.close();
//     canvas.drawPath(bowlPath, bowlPaint);

//     // Food items sitting in the bowl
//     canvas.drawCircle(Offset(w * 0.375, h * 0.48), w * 0.09, Paint()..color = const Color(0xFFD85A30));
//     canvas.drawCircle(Offset(w * 0.57, h * 0.43), w * 0.075, Paint()..color = const Color(0xFFEF9F27));
//     canvas.drawCircle(Offset(w * 0.50, h * 0.55), w * 0.065, Paint()..color = const Color(0xFF639922));
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }



//2nd one good
// import 'dart:math';
// import 'package:flutter/material.dart';

// /// Draws a big Chinese-style blue-and-white porcelain noodle bowl:
// /// wide flared rim, tapered body, a decorative blue band, broth,
// /// noodles, a few toppings, and a pair of chopsticks resting on top.
// ///
// /// Designed on a 300 x 260 canvas — pass any size in, it scales to fit.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   static const double _baseW = 300;
//   static const double _baseH = 260;

//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.save();
//     canvas.scale(size.width / _baseW, size.height / _baseH);

//     const cream = Color(0xFFF5F1E6);
//     const porcelainBlue = Color(0xFF2E5C8A);
//     const brothColor = Color(0xFFC17A3D);
//     const wood = Color(0xFFA97C50);

//     // ---- Bowl body (tapered trapezoid with curved sides) ----
//     final bodyPaint = Paint()..color = cream;
//     final bodyBorder = Paint()
//       ..color = porcelainBlue
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3;

//     final bodyPath = Path()
//       ..moveTo(20, 62)
//       ..quadraticBezierTo(20, 200, 70, 222)
//       ..quadraticBezierTo(150, 240, 230, 222)
//       ..quadraticBezierTo(280, 200, 280, 62)
//       ..quadraticBezierTo(150, 90, 20, 62)
//       ..close();
//     canvas.drawPath(bodyPath, bodyPaint);
//     canvas.drawPath(bodyPath, bodyBorder);

//     // ---- Decorative blue band near the rim ----
//     final bandRect = Rect.fromLTWH(28, 72, 244, 26);
//     final bandPaint = Paint()
//       ..color = porcelainBlue.withOpacity(0.85)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2;
//     canvas.drawArc(bandRect, pi * 0.05, pi * 0.9, false, bandPaint);

//     // small wave/cloud motifs along the band
//     final motifPaint = Paint()
//       ..color = porcelainBlue.withOpacity(0.7)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 7; i++) {
//       final cx = 46.0 + i * 32;
//       final path = Path()
//         ..moveTo(cx - 8, 88)
//         ..quadraticBezierTo(cx, 80, cx + 8, 88);
//       canvas.drawPath(path, motifPaint);
//     }

//     // ---- Rim ellipse (top opening) ----
//     final rimFill = Paint()..color = cream;
//     final rimRect = Rect.fromCenter(center: const Offset(150, 62), width: 260, height: 66);
//     canvas.drawOval(rimRect, rimFill);
//     canvas.drawOval(rimRect, bodyBorder);
//     // inner rim line for a lip effect
//     canvas.drawOval(
//       Rect.fromCenter(center: const Offset(150, 62), width: 244, height: 56),
//       Paint()
//         ..color = porcelainBlue.withOpacity(0.5)
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 1.5,
//     );

//     // ---- Broth surface ----
//     final brothRect = Rect.fromCenter(center: const Offset(150, 64), width: 220, height: 46);
//     canvas.drawOval(brothRect, Paint()..color = brothColor);

//     // ---- Noodles ----
//     final noodlePaint = Paint()
//       ..color = const Color(0xFFF6E7C8)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 5; i++) {
//       final yBase = 54.0 + i * 5;
//       final path = Path()..moveTo(70, yBase);
//       for (double x = 70; x <= 230; x += 20) {
//         path.quadraticBezierTo(x + 10, yBase - 8, x + 20, yBase);
//       }
//       canvas.drawPath(path, noodlePaint);
//     }

//     // ---- Toppings ----
//     // char siu (meat) slice
//     final meatRect = RRect.fromRectAndRadius(
//       const Rect.fromLTWH(178, 46, 34, 20),
//       const Radius.circular(6),
//     );
//     canvas.save();
//     canvas.translate(195, 56);
//     canvas.rotate(-0.25);
//     canvas.translate(-195, -56);
//     canvas.drawRRect(meatRect, Paint()..color = const Color(0xFFD85A30));
//     canvas.restore();

//     // soft-boiled egg half
//     canvas.drawOval(
//       const Rect.fromLTWH(96, 44, 26, 22),
//       Paint()..color = const Color(0xFFFDF6E3),
//     );
//     canvas.drawOval(
//       const Rect.fromLTWH(104, 50, 12, 12),
//       Paint()..color = const Color(0xFFEF9F27),
//     );

//     // scallion rings
//     final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
//     for (final c in [const Offset(130, 40), const Offset(150, 70), const Offset(210, 68)]) {
//       canvas.drawCircle(c, 4, scallionPaint);
//     }

//     // ---- Chopsticks resting on the rim ----
//     final chopstickPaint = Paint()..color = wood;
//     for (final dx in [-6.0, 6.0]) {
//       canvas.save();
//       canvas.translate(150 + dx, 40);
//       canvas.rotate(-0.55);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -110, 8, 220), const Radius.circular(4)),
//         chopstickPaint,
//       );
//       canvas.restore();
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }


//3rd one is better

// import 'dart:math';
// import 'package:flutter/material.dart';

// /// Big blue-and-white porcelain noodle bowl, styled after classic Ming-style
// /// bowls: flared rim with a pointed lappet border, a floral scroll band on
// /// the body, and a footring with a petal band — filled with noodles, broth
// /// and toppings, with chopsticks resting on top.
// ///
// /// Designed on a 300 x 280 canvas — pass any size in, it scales to fit.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   static const double _baseW = 300;
//   static const double _baseH = 280;

//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.save();
//     canvas.scale(size.width / _baseW, size.height / _baseH);

//     const cream = Color(0xFFFAF8F2);
//     const indigo = Color(0xFF2A4E7C);
//     const indigoLight = Color(0xFF5178A8);
//     const brothColor = Color(0xFFC17A3D);
//     const wood = Color(0xFFA97C50);

//     final border = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.5;

//     // ---- Body (tapered, slightly curved sides like the reference bowl) ----
//     final bodyPath = Path()
//       ..moveTo(24, 58)
//       ..cubicTo(18, 150, 55, 205, 92, 222)
//       ..quadraticBezierTo(150, 236, 208, 222)
//       ..cubicTo(245, 205, 282, 150, 276, 58)
//       ..quadraticBezierTo(150, 86, 24, 58)
//       ..close();
//     canvas.drawPath(bodyPath, Paint()..color = cream);
//     canvas.drawPath(bodyPath, border);

//     // ---- Footring ----
//     final footRect = Rect.fromCenter(center: const Offset(150, 234), width: 64, height: 16);
//     canvas.drawOval(footRect, Paint()..color = cream);
//     canvas.drawOval(footRect, border);
//     canvas.drawLine(const Offset(122, 226), const Offset(122, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);
//     canvas.drawLine(const Offset(178, 226), const Offset(178, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);

//     // petal band around the foot
//     final petalPaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.6;
//     for (int i = 0; i < 10; i++) {
//       final cx = 120.0 + i * 6.5;
//       canvas.drawLine(Offset(cx, 218), Offset(cx, 226), petalPaint);
//     }

//     // ---- Floral scroll band on the body ----
//     final scrollPaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.8
//       ..strokeCap = StrokeCap.round;
//     canvas.drawLine(const Offset(36, 150), const Offset(264, 150), scrollPaint);
//     canvas.drawLine(const Offset(30, 190), const Offset(270, 190), scrollPaint);
//     for (int i = 0; i < 8; i++) {
//       final cx = 46.0 + i * 29;
//       final cy = 170.0;
//       final path = Path()
//         ..moveTo(cx - 10, cy)
//         ..quadraticBezierTo(cx - 4, cy - 12, cx, cy)
//         ..quadraticBezierTo(cx + 4, cy + 12, cx + 10, cy);
//       canvas.drawPath(path, scrollPaint);
//       canvas.drawCircle(Offset(cx, cy), 2.6, Paint()..color = indigo);
//     }

//     // ---- Rim ellipse (top opening) ----
//     final rimRect = Rect.fromCenter(center: const Offset(150, 58), width: 256, height: 62);
//     canvas.drawOval(rimRect, Paint()..color = cream);
//     canvas.drawOval(rimRect, border);

//     // pointed lappet border just inside the rim
//     final lappetPaint = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.6;
//     for (int i = 0; i < 12; i++) {
//       final t = i / 11;
//       final cx = 44 + t * 212;
//       final path = Path()
//         ..moveTo(cx - 8, 82)
//         ..lineTo(cx, 70)
//         ..lineTo(cx + 8, 82);
//       canvas.drawPath(path, lappetPaint);
//     }
//     canvas.drawLine(const Offset(32, 84), const Offset(268, 84),
//         Paint()..color = indigoLight..strokeWidth = 1.2);

//     // ---- Broth surface ----
//     final brothRect = Rect.fromCenter(center: const Offset(150, 60), width: 216, height: 42);
//     canvas.drawOval(brothRect, Paint()..color = brothColor);

//     // ---- Noodles ----
//     final noodlePaint = Paint()
//       ..color = const Color(0xFFF6E7C8)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 5; i++) {
//       final yBase = 50.0 + i * 5;
//       final path = Path()..moveTo(72, yBase);
//       for (double x = 72; x <= 228; x += 20) {
//         path.quadraticBezierTo(x + 10, yBase - 7, x + 20, yBase);
//       }
//       canvas.drawPath(path, noodlePaint);
//     }

//     // ---- Toppings ----
//     canvas.save();
//     canvas.translate(195, 52);
//     canvas.rotate(-0.25);
//     canvas.translate(-195, -52);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(const Rect.fromLTWH(178, 42, 34, 20), const Radius.circular(6)),
//       Paint()..color = const Color(0xFFD85A30),
//     );
//     canvas.restore();

//     canvas.drawOval(const Rect.fromLTWH(96, 40, 26, 22), Paint()..color = const Color(0xFFFDF6E3));
//     canvas.drawOval(const Rect.fromLTWH(104, 46, 12, 12), Paint()..color = const Color(0xFFEF9F27));

//     final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
//     for (final c in [const Offset(130, 36), const Offset(150, 64), const Offset(210, 62)]) {
//       canvas.drawCircle(c, 4, scallionPaint);
//     }

//     // ---- Chopsticks resting on the rim ----
//     final chopstickPaint = Paint()..color = wood;
//     for (final dx in [-6.0, 6.0]) {
//       canvas.save();
//       canvas.translate(150 + dx, 36);
//       canvas.rotate(-0.55);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -110, 8, 220), const Radius.circular(4)),
//         chopstickPaint,
//       );
//       canvas.restore();
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }




//4th one fix
// import 'dart:math';
// import 'package:flutter/material.dart';

// /// Big blue-and-white porcelain noodle bowl, styled after classic Ming-style
// /// bowls: flared rim with a pointed lappet border, a floral scroll band on
// /// the body, and a footring with a petal band — filled with noodles, broth
// /// and toppings, with chopsticks resting on top.
// ///
// /// Designed on a 300 x 280 canvas — pass any size in, it scales to fit.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   static const double _baseW = 300;
//   static const double _baseH = 280;

//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.save();
//     canvas.scale(size.width / _baseW, size.height / _baseH);

//     const cream = Color(0xFFFAF8F2);
//     const indigo = Color(0xFF2A4E7C);
//     const indigoLight = Color(0xFF5178A8);
//     const brothColor = Color(0xFFC17A3D);
//     const wood = Color(0xFFA97C50);

//     final border = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.5;

//     // ---- Body (tapered, slightly curved sides like the reference bowl) ----
//     final bodyPath = Path()
//       ..moveTo(24, 58)
//       ..cubicTo(18, 150, 55, 205, 92, 222)
//       ..quadraticBezierTo(150, 236, 208, 222)
//       ..cubicTo(245, 205, 282, 150, 276, 58)
//       ..quadraticBezierTo(150, 86, 24, 58)
//       ..close();
//     canvas.drawPath(bodyPath, Paint()..color = cream);
//     canvas.drawPath(bodyPath, border);

//     // ---- Footring ----
//     final footRect = Rect.fromCenter(center: const Offset(150, 234), width: 64, height: 16);
//     canvas.drawOval(footRect, Paint()..color = cream);
//     canvas.drawOval(footRect, border);
//     canvas.drawLine(const Offset(122, 226), const Offset(122, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);
//     canvas.drawLine(const Offset(178, 226), const Offset(178, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);

//     // upright lotus petal panel band above the foot (classic Ming lower
//     // border — alternating pointed panels rather than plain tick marks)
//     final panelOutline = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.4;
//     final panelFill = Paint()..color = indigo.withOpacity(0.18);
//     for (int i = 0; i < 9; i++) {
//       final cx = 108.0 + i * 10.5;
//       final panel = Path()
//         ..moveTo(cx - 4.2, 222)
//         ..lineTo(cx - 4.2, 202)
//         ..quadraticBezierTo(cx, 194, cx + 4.2, 202)
//         ..lineTo(cx + 4.2, 222)
//         ..close();
//       canvas.drawPath(panel, panelFill);
//       canvas.drawPath(panel, panelOutline);
//     }
//     canvas.drawLine(const Offset(104, 222), const Offset(196, 222),
//         Paint()..color = indigoLight..strokeWidth = 1.2);

//     // ---- Floral scroll band on the body ----
//     final scrollPaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.8
//       ..strokeCap = StrokeCap.round;
//     canvas.drawLine(const Offset(36, 150), const Offset(264, 150), scrollPaint);
//     canvas.drawLine(const Offset(30, 190), const Offset(270, 190), scrollPaint);
//     for (int i = 0; i < 8; i++) {
//       final cx = 46.0 + i * 29;
//       final cy = 170.0;
//       final path = Path()
//         ..moveTo(cx - 10, cy)
//         ..quadraticBezierTo(cx - 4, cy - 12, cx, cy)
//         ..quadraticBezierTo(cx + 4, cy + 12, cx + 10, cy);
//       canvas.drawPath(path, scrollPaint);
//       canvas.drawCircle(Offset(cx, cy), 2.6, Paint()..color = indigo);
//     }

//     // ---- Floral medallion on the front of the body, like the roundel
//     // seen near the base of the reference bowl ----
//     const medallionCenter = Offset(150, 197);
//     final petalPaint2 = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5;
//     for (int i = 0; i < 8; i++) {
//       final angle = (i / 8) * 2 * pi;
//       final px = medallionCenter.dx + cos(angle) * 8;
//       final py = medallionCenter.dy + sin(angle) * 6;
//       canvas.drawOval(
//         Rect.fromCenter(center: Offset(px, py), width: 9, height: 5.5),
//         petalPaint2,
//       );
//     }
//     canvas.drawCircle(medallionCenter, 4.2, Paint()..color = indigoLight.withOpacity(0.35));
//     canvas.drawCircle(medallionCenter, 2.4, Paint()..color = indigo);

//     final tendrilPaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.2;
//     canvas.drawPath(
//       Path()
//         ..moveTo(medallionCenter.dx - 16, medallionCenter.dy)
//         ..quadraticBezierTo(medallionCenter.dx - 26, medallionCenter.dy - 10,
//             medallionCenter.dx - 34, medallionCenter.dy - 2),
//       tendrilPaint,
//     );
//     canvas.drawPath(
//       Path()
//         ..moveTo(medallionCenter.dx + 16, medallionCenter.dy)
//         ..quadraticBezierTo(medallionCenter.dx + 26, medallionCenter.dy + 8,
//             medallionCenter.dx + 34, medallionCenter.dy + 2),
//       tendrilPaint,
//     );

//     // ---- Rim ellipse (top opening) ----
//     final rimRect = Rect.fromCenter(center: const Offset(150, 58), width: 256, height: 62);
//     canvas.drawOval(rimRect, Paint()..color = cream);
//     canvas.drawOval(rimRect, border);

//     // pointed lappet border just inside the rim
//     final lappetPaint = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.6;
//     for (int i = 0; i < 12; i++) {
//       final t = i / 11;
//       final cx = 44 + t * 212;
//       final path = Path()
//         ..moveTo(cx - 8, 82)
//         ..lineTo(cx, 70)
//         ..lineTo(cx + 8, 82);
//       canvas.drawPath(path, lappetPaint);
//     }
//     canvas.drawLine(const Offset(32, 84), const Offset(268, 84),
//         Paint()..color = indigoLight..strokeWidth = 1.2);

//     // ---- Broth surface ----
//     final brothRect = Rect.fromCenter(center: const Offset(150, 60), width: 216, height: 42);
//     canvas.drawOval(brothRect, Paint()..color = brothColor);

//     // ---- Noodles ----
//     final noodlePaint = Paint()
//       ..color = const Color(0xFFF6E7C8)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 5; i++) {
//       final yBase = 50.0 + i * 5;
//       final path = Path()..moveTo(72, yBase);
//       for (double x = 72; x <= 228; x += 20) {
//         path.quadraticBezierTo(x + 10, yBase - 7, x + 20, yBase);
//       }
//       canvas.drawPath(path, noodlePaint);
//     }

//     // ---- Toppings ----
//     canvas.save();
//     canvas.translate(195, 52);
//     canvas.rotate(-0.25);
//     canvas.translate(-195, -52);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(const Rect.fromLTWH(178, 42, 34, 20), const Radius.circular(6)),
//       Paint()..color = const Color(0xFFD85A30),
//     );
//     canvas.restore();

//     canvas.drawOval(const Rect.fromLTWH(96, 40, 26, 22), Paint()..color = const Color(0xFFFDF6E3));
//     canvas.drawOval(const Rect.fromLTWH(104, 46, 12, 12), Paint()..color = const Color(0xFFEF9F27));

//     final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
//     for (final c in [const Offset(130, 36), const Offset(150, 64), const Offset(210, 62)]) {
//       canvas.drawCircle(c, 4, scallionPaint);
//     }

//     // ---- Chopsticks resting on the rim ----
//     final chopstickPaint = Paint()..color = wood;
//     for (final dx in [-6.0, 6.0]) {
//       canvas.save();
//       canvas.translate(150 + dx, 36);
//       canvas.rotate(-0.55);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -110, 8, 220), const Radius.circular(4)),
//         chopstickPaint,
//       );
//       canvas.restore();
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }








// import 'dart:math';
// import 'package:flutter/material.dart';

// /// A wide, shallow blue-and-white porcelain noodle bowl. Every decorative
// /// element (rim key-border, all-over floral fill, foot petal band) is
// /// drawn inside a canvas.clipPath() against the bowl's own silhouette (or
// /// the rim ellipse, for the rim border) — so nothing can ever render
// /// outside the bowl's true outline, regardless of the pattern math.
// ///
// /// Designed on a 340 x 210 canvas (wide + shallow) — pass any size in,
// /// it scales to fit.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   static const double _baseW = 340;
//   static const double _baseH = 210;

//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.save();
//     canvas.scale(size.width / _baseW, size.height / _baseH);

//     const cream = Color(0xFFFAF8F2);
//     const indigo = Color(0xFF2A4E7C);
//     const indigoLight = Color(0xFF6488B8);
//     const indigoPale = Color(0xFFAEC4E0);
//     const brothColor = Color(0xFFC17A3D);
//     const wood = Color(0xFFA97C50);

//     final thickBorder = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.6;
//     final thinBorder = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.3;

//     // ---- Body silhouette: wide, shallow, gently flared ----
//     final bodyPath = Path()
//       ..moveTo(14, 46)
//       ..cubicTo(8, 120, 60, 168, 110, 182)
//       ..quadraticBezierTo(170, 194, 230, 182)
//       ..cubicTo(280, 168, 332, 120, 326, 46)
//       ..quadraticBezierTo(170, 72, 14, 46)
//       ..close();
//     canvas.drawPath(bodyPath, Paint()..color = cream);

//     // ============ Everything below is hard-clipped to the body ============
//     // No pattern element can render outside the bowl's real outline,
//     // however its coordinates are computed.
//     canvas.save();
//     canvas.clipPath(bodyPath);

//     // ---- All-over floral fill covering the FULL body height, not just
//     // near the foot — six rows from just under the shoulder down to the
//     // foot, each row offset so it reads as continuous coverage.
//     final vinePaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5
//       ..strokeCap = StrokeCap.round;
//     final flowerCenter = Paint()..color = indigo;
//     final petalStroke = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.3;

//     const rowCount = 7;
//     const topY = 78.0;
//     const bottomY = 186.0;
//     for (int row = 0; row < rowCount; row++) {
//       final rowY = topY + row * (bottomY - topY) / (rowCount - 1);
//       final offset = row.isOdd ? 15.0 : 0.0;
//       for (int col = -1; col < 10; col++) {
//         final cx = 10.0 + offset + col * 24;
//         final cy = rowY;
//         for (int p = 0; p < 5; p++) {
//           final angle = (p / 5) * 2 * pi;
//           final px = cx + cos(angle) * 5.6;
//           final py = cy + sin(angle) * 4.4;
//           canvas.drawOval(
//             Rect.fromCenter(center: Offset(px, py), width: 6.4, height: 4.2),
//             petalStroke,
//           );
//         }
//         canvas.drawCircle(Offset(cx, cy), 2.1, flowerCenter);
//         final vine = Path()
//           ..moveTo(cx - 11, cy + 4)
//           ..quadraticBezierTo(cx - 5, cy + 10, cx + 3, cy + 6)
//           ..quadraticBezierTo(cx + 11, cy + 2, cx + 15, cy + 9);
//         canvas.drawPath(vine, vinePaint);
//       }
//     }

//     // ---- Lotus petal panel band just above the foot ----
//     final panelFill = Paint()..color = indigoPale.withOpacity(0.6);
//     for (int i = 0; i < 13; i++) {
//       final cx = 100.0 + i * 10.8;
//       final panel = Path()
//         ..moveTo(cx - 4.8, 190)
//         ..lineTo(cx - 4.8, 166)
//         ..quadraticBezierTo(cx, 157, cx + 4.8, 166)
//         ..lineTo(cx + 4.8, 190)
//         ..close();
//       canvas.drawPath(panel, panelFill);
//       canvas.drawPath(panel, thinBorder);
//     }
//     canvas.drawLine(const Offset(94, 190), const Offset(246, 190), thinBorder);

//     canvas.restore(); // ============ end body clip ============

//     // body outline drawn on top of the pattern, sharp and clean
//     canvas.drawPath(bodyPath, thickBorder);

//     // ---- Footring (its own small ellipse below the body, unclipped
//     // since it's a distinct separate shape, not part of the body fill) ----
//     final footRect = Rect.fromCenter(center: const Offset(170, 190), width: 74, height: 14);
//     canvas.drawOval(footRect, Paint()..color = cream);
//     canvas.drawOval(footRect, thinBorder);

//     // ---- Thick banded rim ----
//     final rimOuterRect = Rect.fromCenter(center: const Offset(170, 44), width: 316, height: 60);
//     final rimInnerRect = Rect.fromCenter(center: const Offset(170, 46), width: 288, height: 50);
//     canvas.drawOval(rimOuterRect, Paint()..color = cream);

//     // ---- Key/wave motif around the rim — clipped to the rim ellipse so
//     // it can never poke past the rim's own oval edge ----
//     canvas.save();
//     canvas.clipPath(Path()..addOval(rimOuterRect));
//     final wavePaint = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.6
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 16; i++) {
//       final t = i / 15;
//       final cx = 34 + t * 272;
//       final path = Path()
//         ..moveTo(cx - 7, 30)
//         ..lineTo(cx - 7, 22)
//         ..lineTo(cx, 22)
//         ..lineTo(cx, 16)
//         ..lineTo(cx + 7, 16)
//         ..lineTo(cx + 7, 22);
//       canvas.drawPath(path, wavePaint);
//     }
//     canvas.drawLine(const Offset(26, 32), const Offset(314, 32), thinBorder);
//     canvas.restore();

//     canvas.drawOval(rimOuterRect, thickBorder);
//     canvas.drawOval(rimInnerRect, thinBorder);

//     // small florets on the shoulder, clipped to the body so they can't
//     // sit outside the curve where it narrows near the rim ends
//     canvas.save();
//     canvas.clipPath(bodyPath);
//     for (int i = 0; i < 12; i++) {
//       final cx = 24.0 + i * 26;
//       canvas.drawCircle(Offset(cx, 60), 2.4, Paint()..color = indigoLight);
//     }
//     canvas.restore();

//     // ---- Broth surface ----
//     final brothRect = Rect.fromCenter(center: const Offset(170, 46), width: 244, height: 40);
//     canvas.drawOval(brothRect, Paint()..color = brothColor);

//     // ---- Noodles ----
//     final noodlePaint = Paint()
//       ..color = const Color(0xFFF6E7C8)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 5; i++) {
//       final yBase = 36.0 + i * 5;
//       final path = Path()..moveTo(80, yBase);
//       for (double x = 80; x <= 260; x += 20) {
//         path.quadraticBezierTo(x + 10, yBase - 7, x + 20, yBase);
//       }
//       canvas.drawPath(path, noodlePaint);
//     }

//     // ---- Toppings ----
//     canvas.save();
//     canvas.translate(218, 38);
//     canvas.rotate(-0.25);
//     canvas.translate(-218, -38);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(const Rect.fromLTWH(200, 28, 34, 20), const Radius.circular(6)),
//       Paint()..color = const Color(0xFFD85A30),
//     );
//     canvas.restore();

//     canvas.drawOval(const Rect.fromLTWH(116, 26, 26, 22), Paint()..color = const Color(0xFFFDF6E3));
//     canvas.drawOval(const Rect.fromLTWH(124, 32, 12, 12), Paint()..color = const Color(0xFFEF9F27));

//     final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
//     for (final c in [const Offset(150, 22), const Offset(170, 50), const Offset(232, 48)]) {
//       canvas.drawCircle(c, 4, scallionPaint);
//     }

//     // ---- Chopsticks resting on the rim ----
//     final chopstickPaint = Paint()..color = wood;
//     for (final dx in [-6.0, 6.0]) {
//       canvas.save();
//       canvas.translate(170 + dx, 20);
//       canvas.rotate(-0.5);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -100, 8, 200), const Radius.circular(4)),
//         chopstickPaint,
//       );
//       canvas.restore();
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }




// import 'dart:math';
// import 'package:flutter/material.dart';

// /// Big blue-and-white porcelain noodle bowl, styled after classic Ming-style
// /// bowls: flared rim with a pointed lappet border, a floral scroll band on
// /// the body, a medallion roundel, and a footring with an upright petal
// /// band — filled with noodles, broth and toppings, chopsticks on top.
// ///
// /// Every decorative element on the body (petal band, scroll band,
// /// medallion) is drawn inside a canvas.clipPath() against the bowl's own
// /// silhouette, and the rim's lappet border is clipped to the rim ellipse
// /// — so nothing can ever render outside the bowl's true outline.
// ///
// /// Designed on a 300 x 280 canvas — pass any size in, it scales to fit.
// class BowlPainter extends CustomPainter {
//   const BowlPainter();

//   static const double _baseW = 300;
//   static const double _baseH = 280;

//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.save();
//     canvas.scale(size.width / _baseW, size.height / _baseH);

//     const cream = Color(0xFFFAF8F2);
//     const indigo = Color(0xFF2A4E7C);
//     const indigoLight = Color(0xFF5178A8);
//     const brothColor = Color(0xFFC17A3D);
//     const wood = Color(0xFFA97C50);

//     final border = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.5;

//     // ---- Body (tapered, slightly curved sides) ----
//     final bodyPath = Path()
//       ..moveTo(24, 58)
//       ..cubicTo(18, 150, 55, 205, 92, 222)
//       ..quadraticBezierTo(150, 236, 208, 222)
//       ..cubicTo(245, 205, 282, 150, 276, 58)
//       ..quadraticBezierTo(150, 86, 24, 58)
//       ..close();
//     canvas.drawPath(bodyPath, Paint()..color = cream);

//     // ============ Everything on the body is hard-clipped to bodyPath ============
//     canvas.save();
//     canvas.clipPath(bodyPath);

//     // upright lotus petal panel band above the foot
//     final panelOutline = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.4;
//     final panelFill = Paint()..color = indigo.withOpacity(0.18);
//     for (int i = 0; i < 9; i++) {
//       final cx = 108.0 + i * 10.5;
//       final panel = Path()
//         ..moveTo(cx - 4.2, 222)
//         ..lineTo(cx - 4.2, 202)
//         ..quadraticBezierTo(cx, 194, cx + 4.2, 202)
//         ..lineTo(cx + 4.2, 222)
//         ..close();
//       canvas.drawPath(panel, panelFill);
//       canvas.drawPath(panel, panelOutline);
//     }
//     canvas.drawLine(const Offset(104, 222), const Offset(196, 222),
//         Paint()..color = indigoLight..strokeWidth = 1.2);

//     // ---- Dense all-over floral fill covering the FULL body, from just
//     // under the rim shoulder down to the foot band — not just one thin
//     // strip. Rows are offset so it reads as continuous coverage.
//     final vinePaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.4
//       ..strokeCap = StrokeCap.round;
//     final flowerCenter = Paint()..color = indigo;
//     final petalStroke = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.2;

//     const rowCount = 6;
//     const topY = 94.0;
//     const bottomY = 196.0;
//     for (int row = 0; row < rowCount; row++) {
//       final rowY = topY + row * (bottomY - topY) / (rowCount - 1);
//       final offset = row.isOdd ? 13.0 : 0.0;
//       for (int col = -1; col < 12; col++) {
//         final cx = 8.0 + offset + col * 24;
//         final cy = rowY;
//         for (int p = 0; p < 5; p++) {
//           final angle = (p / 5) * 2 * pi;
//           final px = cx + cos(angle) * 5.2;
//           final py = cy + sin(angle) * 4.0;
//           canvas.drawOval(
//             Rect.fromCenter(center: Offset(px, py), width: 5.8, height: 3.8),
//             petalStroke,
//           );
//         }
//         canvas.drawCircle(Offset(cx, cy), 1.8, flowerCenter);
//         final vine = Path()
//           ..moveTo(cx - 10, cy + 3)
//           ..quadraticBezierTo(cx - 4, cy + 9, cx + 2, cy + 5)
//           ..quadraticBezierTo(cx + 8, cy + 1, cx + 13, cy + 7);
//         canvas.drawPath(vine, vinePaint);
//       }
//     }

//     // ---- Floral medallion roundel on the front of the body ----
//     const medallionCenter = Offset(150, 197);
//     final petalPaint2 = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5;
//     for (int i = 0; i < 8; i++) {
//       final angle = (i / 8) * 2 * pi;
//       final px = medallionCenter.dx + cos(angle) * 8;
//       final py = medallionCenter.dy + sin(angle) * 6;
//       canvas.drawOval(
//         Rect.fromCenter(center: Offset(px, py), width: 9, height: 5.5),
//         petalPaint2,
//       );
//     }
//     canvas.drawCircle(medallionCenter, 4.2, Paint()..color = indigoLight.withOpacity(0.35));
//     canvas.drawCircle(medallionCenter, 2.4, Paint()..color = indigo);

//     final tendrilPaint = Paint()
//       ..color = indigoLight
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.2;
//     canvas.drawPath(
//       Path()
//         ..moveTo(medallionCenter.dx - 16, medallionCenter.dy)
//         ..quadraticBezierTo(medallionCenter.dx - 26, medallionCenter.dy - 10,
//             medallionCenter.dx - 34, medallionCenter.dy - 2),
//       tendrilPaint,
//     );
//     canvas.drawPath(
//       Path()
//         ..moveTo(medallionCenter.dx + 16, medallionCenter.dy)
//         ..quadraticBezierTo(medallionCenter.dx + 26, medallionCenter.dy + 8,
//             medallionCenter.dx + 34, medallionCenter.dy + 2),
//       tendrilPaint,
//     );

//     canvas.restore(); // ============ end body clip ============

//     // body outline on top, sharp and clean
//     canvas.drawPath(bodyPath, border);

//     // ---- Footring ----
//     final footRect = Rect.fromCenter(center: const Offset(150, 234), width: 64, height: 16);
//     canvas.drawOval(footRect, Paint()..color = cream);
//     canvas.drawOval(footRect, border);
//     canvas.drawLine(const Offset(122, 226), const Offset(122, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);
//     canvas.drawLine(const Offset(178, 226), const Offset(178, 234),
//         Paint()..color = indigo..strokeWidth = 2.5);

//     // ---- Rim ellipse (top opening) ----
//     final rimRect = Rect.fromCenter(center: const Offset(150, 58), width: 256, height: 62);
//     canvas.drawOval(rimRect, Paint()..color = cream);

//     // pointed lappet border, clipped to the rim ellipse so it can never
//     // poke past the rim's own oval edge
//     canvas.save();
//     canvas.clipPath(Path()..addOval(rimRect));
//     final lappetPaint = Paint()
//       ..color = indigo
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.6;
//     for (int i = 0; i < 12; i++) {
//       final t = i / 11;
//       final cx = 44 + t * 212;
//       final path = Path()
//         ..moveTo(cx - 8, 82)
//         ..lineTo(cx, 70)
//         ..lineTo(cx + 8, 82);
//       canvas.drawPath(path, lappetPaint);
//     }
//     canvas.drawLine(const Offset(32, 84), const Offset(268, 84),
//         Paint()..color = indigoLight..strokeWidth = 1.2);
//     canvas.restore();

//     canvas.drawOval(rimRect, border);

//     // ---- Broth surface ----
//     final brothRect = Rect.fromCenter(center: const Offset(150, 60), width: 216, height: 42);
//     canvas.drawOval(brothRect, Paint()..color = brothColor);

//     // ---- Noodles ----
//     final noodlePaint = Paint()
//       ..color = const Color(0xFFF6E7C8)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//     for (int i = 0; i < 5; i++) {
//       final yBase = 50.0 + i * 5;
//       final path = Path()..moveTo(72, yBase);
//       for (double x = 72; x <= 228; x += 20) {
//         path.quadraticBezierTo(x + 10, yBase - 7, x + 20, yBase);
//       }
//       canvas.drawPath(path, noodlePaint);
//     }

//     // ---- Toppings ----
//     canvas.save();
//     canvas.translate(195, 52);
//     canvas.rotate(-0.25);
//     canvas.translate(-195, -52);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(const Rect.fromLTWH(178, 42, 34, 20), const Radius.circular(6)),
//       Paint()..color = const Color(0xFFD85A30),
//     );
//     canvas.restore();

//     canvas.drawOval(const Rect.fromLTWH(96, 40, 26, 22), Paint()..color = const Color(0xFFFDF6E3));
//     canvas.drawOval(const Rect.fromLTWH(104, 46, 12, 12), Paint()..color = const Color(0xFFEF9F27));

//     final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
//     for (final c in [const Offset(130, 36), const Offset(150, 64), const Offset(210, 62)]) {
//       canvas.drawCircle(c, 4, scallionPaint);
//     }

//     // ---- Chopsticks resting on the rim ----
//     final chopstickPaint = Paint()..color = wood;
//     for (final dx in [-6.0, 6.0]) {
//       canvas.save();
//       canvas.translate(150 + dx, 36);
//       canvas.rotate(-0.55);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -110, 8, 220), const Radius.circular(4)),
//         chopstickPaint,
//       );
//       canvas.restore();
//     }

//     canvas.restore();
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }



import 'dart:math';
import 'package:flutter/material.dart';

/// Big blue-and-white porcelain noodle bowl, styled after classic Ming-style
/// bowls: flared rim with a pointed lappet border, a floral scroll band on
/// the body, a medallion roundel, and a footring with an upright petal
/// band — filled with noodles, broth and toppings, chopsticks on top.
///
/// Every decorative element on the body (petal band, scroll band,
/// medallion) is drawn inside a canvas.clipPath() against the bowl's own
/// silhouette, and the rim's lappet border is clipped to the rim ellipse
/// — so nothing can ever render outside the bowl's true outline.
///
/// Designed on a 300 x 280 canvas — pass any size in, it scales to fit.
class BowlPainter extends CustomPainter {
  const BowlPainter();

  static const double _baseW = 300;
  static const double _baseH = 280;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _baseW, size.height / _baseH);

    const cream = Color(0xFFFAF8F2);
    const indigo = Color(0xFF2A4E7C);
    const indigoLight = Color(0xFF5178A8);
    const brothColor = Color(0xFFC17A3D);
    const wood = Color(0xFFA97C50);

    final border = Paint()
      ..color = indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // ---- Body (tapered, slightly curved sides) ----
    final bodyPath = Path()
      ..moveTo(24, 58)
      ..cubicTo(18, 150, 55, 205, 92, 222)
      ..quadraticBezierTo(150, 236, 208, 222)
      ..cubicTo(245, 205, 282, 150, 276, 58)
      ..quadraticBezierTo(150, 86, 24, 58)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = cream);

    // ============ Everything on the body is hard-clipped to bodyPath ============
    canvas.save();
    canvas.clipPath(bodyPath);

    // upright lotus petal panel band above the foot
    final panelOutline = Paint()
      ..color = indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final panelFill = Paint()..color = indigo.withOpacity(0.18);
    for (int i = 0; i < 9; i++) {
      final cx = 108.0 + i * 10.5;
      final panel = Path()
        ..moveTo(cx - 4.2, 222)
        ..lineTo(cx - 4.2, 202)
        ..quadraticBezierTo(cx, 194, cx + 4.2, 202)
        ..lineTo(cx + 4.2, 222)
        ..close();
      canvas.drawPath(panel, panelFill);
      canvas.drawPath(panel, panelOutline);
    }
    canvas.drawLine(const Offset(104, 222), const Offset(196, 222),
        Paint()..color = indigoLight..strokeWidth = 1.2);

    // ---- Dense all-over floral fill covering the FULL body, from just
    // under the rim shoulder down to the foot band — not just one thin
    // strip. Rows are offset so it reads as continuous coverage.
    final vinePaint = Paint()
      ..color = indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final flowerCenter = Paint()..color = indigo;
    final petalStroke = Paint()
      ..color = indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const rowCount = 6;
    const topY = 104.0;
    const bottomY = 196.0;
    for (int row = 0; row < rowCount; row++) {
      final rowY = topY + row * (bottomY - topY) / (rowCount - 1);
      final offset = row.isOdd ? 13.0 : 0.0;
      for (int col = -1; col < 12; col++) {
        final cx = 8.0 + offset + col * 24;
        final cy = rowY;
        for (int p = 0; p < 5; p++) {
          final angle = (p / 5) * 2 * pi;
          final px = cx + cos(angle) * 5.2;
          final py = cy + sin(angle) * 4.0;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(px, py), width: 5.8, height: 3.8),
            petalStroke,
          );
        }
        canvas.drawCircle(Offset(cx, cy), 1.8, flowerCenter);
        final vine = Path()
          ..moveTo(cx - 10, cy + 3)
          ..quadraticBezierTo(cx - 4, cy + 9, cx + 2, cy + 5)
          ..quadraticBezierTo(cx + 8, cy + 1, cx + 13, cy + 7);
        canvas.drawPath(vine, vinePaint);
      }
    }

    // ---- Floral medallion roundel on the front of the body ----
    const medallionCenter = Offset(150, 197);
    final petalPaint2 = Paint()
      ..color = indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final px = medallionCenter.dx + cos(angle) * 8;
      final py = medallionCenter.dy + sin(angle) * 6;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: 9, height: 5.5),
        petalPaint2,
      );
    }
    canvas.drawCircle(medallionCenter, 4.2, Paint()..color = indigoLight.withOpacity(0.35));
    canvas.drawCircle(medallionCenter, 2.4, Paint()..color = indigo);

    final tendrilPaint = Paint()
      ..color = indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(
      Path()
        ..moveTo(medallionCenter.dx - 16, medallionCenter.dy)
        ..quadraticBezierTo(medallionCenter.dx - 26, medallionCenter.dy - 10,
            medallionCenter.dx - 34, medallionCenter.dy - 2),
      tendrilPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(medallionCenter.dx + 16, medallionCenter.dy)
        ..quadraticBezierTo(medallionCenter.dx + 26, medallionCenter.dy + 8,
            medallionCenter.dx + 34, medallionCenter.dy + 2),
      tendrilPaint,
    );

    canvas.restore(); // ============ end body clip ============

    // body outline on top, sharp and clean
    canvas.drawPath(bodyPath, border);

    // ---- Footring ----
    final footRect = Rect.fromCenter(center: const Offset(150, 234), width: 64, height: 16);
    canvas.drawOval(footRect, Paint()..color = cream);
    canvas.drawOval(footRect, border);
    canvas.drawLine(const Offset(122, 226), const Offset(122, 234),
        Paint()..color = indigo..strokeWidth = 2.5);
    canvas.drawLine(const Offset(178, 226), const Offset(178, 234),
        Paint()..color = indigo..strokeWidth = 2.5);

    // ---- Rim ellipse (top opening) — kept plain, no pattern here, so
    // the area framing the soup stays clean and uncluttered ----
    final rimRect = Rect.fromCenter(center: const Offset(150, 58), width: 256, height: 62);
    canvas.drawOval(rimRect, Paint()..color = cream);
    canvas.drawOval(rimRect, border);

    // ---- Broth surface ----
    final brothRect = Rect.fromCenter(center: const Offset(150, 60), width: 216, height: 42);
    canvas.drawOval(brothRect, Paint()..color = brothColor);

    // ---- Noodles ----
    final noodlePaint = Paint()
      ..color = const Color(0xFFF6E7C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final yBase = 50.0 + i * 5;
      final path = Path()..moveTo(72, yBase);
      for (double x = 72; x <= 228; x += 20) {
        path.quadraticBezierTo(x + 10, yBase - 7, x + 20, yBase);
      }
      canvas.drawPath(path, noodlePaint);
    }

    // ---- Toppings ----
    canvas.save();
    canvas.translate(195, 52);
    canvas.rotate(-0.25);
    canvas.translate(-195, -52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(178, 42, 34, 20), const Radius.circular(6)),
      Paint()..color = const Color(0xFFD85A30),
    );
    canvas.restore();

    canvas.drawOval(const Rect.fromLTWH(96, 40, 26, 22), Paint()..color = const Color(0xFFFDF6E3));
    canvas.drawOval(const Rect.fromLTWH(104, 46, 12, 12), Paint()..color = const Color(0xFFEF9F27));

    final scallionPaint = Paint()..color = const Color(0xFF5B8C3E);
    for (final c in [const Offset(130, 36), const Offset(150, 64), const Offset(210, 62)]) {
      canvas.drawCircle(c, 4, scallionPaint);
    }

    // ---- Chopsticks resting on the rim ----
    final chopstickPaint = Paint()..color = wood;
    for (final dx in [-6.0, 6.0]) {
      canvas.save();
      canvas.translate(150 + dx, 36);
      canvas.rotate(-0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -110, 8, 220), const Radius.circular(4)),
        chopstickPaint,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}