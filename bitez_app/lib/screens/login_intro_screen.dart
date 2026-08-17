// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';

// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   // Total intro length. Everything below is timed against this, in ms,
//   // so the weights of each TweenSequence step below equal milliseconds.
//   static const int _totalMs = 2800;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _bowlOpacity;
//   late final Animation<double> _bowlScale;
//   late final Animation<double> _bowlTranslateY;
//   late final Animation<double> _steamGroupOpacity;
//   late final Animation<double> _brandOpacity;
//   late final Animation<double> _formOpacity;
//   late final Animation<double> _formTranslateY;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     // Loops continuously to drive the rising steam wisps.
//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat();

//     // --- Bowl: scales/fades in, holds, then shrinks up and fades out ---
//     _bowlOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 200),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1000),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 500),
//     ]).animate(_main);

//     _bowlScale = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.4), weight: 200),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.4, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1000),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.55).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.55), weight: 500),
//     ]).animate(_main);

//     _bowlTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1700),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: -40.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(-40.0), weight: 500),
//     ]).animate(_main);

//     // Fades the whole steam cluster out once the bowl starts leaving.
//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1900),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 300,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 600),
//     ]).animate(_main);

//     // --- Brand name/logo text ---
//     _brandOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1900),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 400),
//     ]).animate(_main);

//     // --- Login form ---
//     _formOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2200),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 600,
//       ),
//     ]).animate(_main);

//     _formTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(8.0), weight: 2200),
//       TweenSequenceItem(
//         tween: Tween(begin: 8.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 600,
//       ),
//     ]).animate(_main);

//     _main.forward();
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Center(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 32),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Bowl + steam group
//                     AnimatedBuilder(
//                       animation: Listenable.merge([_main, _steamLoop]),
//                       builder: (context, _) {
//                         return Opacity(
//                           opacity: _bowlOpacity.value,
//                           child: Transform.translate(
//                             offset: Offset(0, _bowlTranslateY.value),
//                             child: Transform.scale(
//                               scale: _bowlScale.value,
//                               child: SizedBox(
//                                 width: 140,
//                                 height: 140,
//                                 child: Stack(
//                                   alignment: Alignment.center,
//                                   children: [
//                                     CustomPaint(
//                                       size: const Size(120, 120),
//                                       painter: const BowlPainter(),
//                                     ),
//                                     CustomPaint(
//                                       size: const Size(140, 140),
//                                       painter: SteamPainter(
//                                         phase: _steamLoop.value,
//                                         groupOpacity: _steamGroupOpacity.value,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),

//                     const SizedBox(height: 8),

//                     // Brand name
//                     AnimatedBuilder(
//                       animation: _main,
//                       builder: (context, _) => Opacity(
//                         opacity: _brandOpacity.value,
//                         child: Column(
//                           children: const [
//                             Text(
//                               'BITEZ',
//                               style: TextStyle(
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.w600,
//                                 letterSpacing: 0.5,
//                                 color: Color(0xFF1A1A18),
//                               ),
//                             ),
//                             SizedBox(height: 2),
//                             Text(
//                               'Smart leftover food manager',
//                               style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 28),

//                     // Login form
//                     AnimatedBuilder(
//                       animation: _main,
//                       builder: (context, child) => Opacity(
//                         opacity: _formOpacity.value,
//                         child: Transform.translate(
//                           offset: Offset(0, _formTranslateY.value),
//                           child: child,
//                         ),
//                       ),
//                       child: const _LoginForm(),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             // Replay button, top-right — remove this in production, it's
//             // just here so you can preview the intro repeatedly.
//             Positioned(
//               top: 8,
//               right: 8,
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _LoginForm extends StatelessWidget {
//   const _LoginForm();

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         TextField(
//           decoration: InputDecoration(
//             hintText: 'name@email.com',
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//           ),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           obscureText: true,
//           decoration: InputDecoration(
//             hintText: 'Password',
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//           ),
//         ),
//         const SizedBox(height: 16),
//         SizedBox(
//           width: double.infinity,
//           child: ElevatedButton(
//             onPressed: () {
//               // TODO: hook up to your auth flow (Firebase Auth, etc.)
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF1D9E75),
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//             ),
//             child: const Text('Log in'),
//           ),
//         ),
//         const SizedBox(height: 14),
//         RichText(
//           text: const TextSpan(
//             style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//             children: [
//               TextSpan(text: "Don't have an account? "),
//               TextSpan(
//                 text: 'Sign up',
//                 style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }


//2nd one good

// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';

// /// Full-screen intro: a big bowl with rising steam holds the screen,
// /// then cross-fades into the login form. Two full-screen layers are
// /// stacked and opacity-swapped rather than trying to morph one shape
// /// into another — simpler to reason about and to restyle later.
// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   static const int _totalMs = 3000;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _splashOpacity;
//   late final Animation<double> _loginOpacity;
//   late final Animation<double> _loginTranslateY;
//   late final Animation<double> _steamGroupOpacity;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat();

//     _splashOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 2000),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 400),
//     ]).animate(_main);

//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1900),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 700),
//     ]).animate(_main);

//     _loginOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2200),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 200),
//     ]).animate(_main);

//     _loginTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(18.0), weight: 2200),
//       TweenSequenceItem(
//         tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 200),
//     ]).animate(_main);

//     _main.forward();
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     // Bowl fills most of the screen width, capped so it doesn't look
//     // absurd on tablets.
//     final bowlWidth = (screen.width * 0.82).clamp(220.0, 380.0);
//     final bowlHeight = bowlWidth * (260 / 300);
//     final steamHeight = bowlHeight * 1.1;

//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF7EF),
//       body: Stack(
//         children: [
//           // ---------------- Splash layer ----------------
//           AnimatedBuilder(
//             animation: Listenable.merge([_main, _steamLoop]),
//             builder: (context, _) {
//               final opacity = _splashOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.05,
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Container(
//                     color: const Color(0xFFFBF7EF),
//                     width: double.infinity,
//                     height: double.infinity,
//                     child: Center(
//                       child: SizedBox(
//                         width: bowlWidth,
//                         height: bowlHeight + steamHeight * 0.7,
//                         child: Stack(
//                           alignment: Alignment.bottomCenter,
//                           children: [
//                             Positioned(
//                               top: 0,
//                               child: SizedBox(
//                                 width: bowlWidth,
//                                 height: steamHeight,
//                                 child: CustomPaint(
//                                   painter: SteamPainter(
//                                     phase: _steamLoop.value,
//                                     groupOpacity: _steamGroupOpacity.value,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             Positioned(
//                               bottom: 0,
//                               child: SizedBox(
//                                 width: bowlWidth,
//                                 height: bowlHeight,
//                                 child: const CustomPaint(painter: BowlPainter()),
//                               ),
//                             ),
//                             Positioned(
//                               bottom: -36,
//                               child: Column(
//                                 children: const [
//                                   Text(
//                                     'BITEZ',
//                                     style: TextStyle(
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.w600,
//                                       letterSpacing: 0.5,
//                                       color: Color(0xFF1A1A18),
//                                     ),
//                                   ),
//                                   SizedBox(height: 2),
//                                   Text(
//                                     'Smart leftover food manager',
//                                     style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),

//           // ---------------- Login layer ----------------
//           AnimatedBuilder(
//             animation: _main,
//             builder: (context, child) {
//               final opacity = _loginOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.95 ? false : false, // always interactive once visible
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Transform.translate(
//                     offset: Offset(0, _loginTranslateY.value),
//                     child: child,
//                   ),
//                 ),
//               );
//             },
//             child: const _LoginScreenContent(),
//           ),

//           // Replay button — remove before shipping, it's just for previewing.
//           Positioned(
//             top: 44,
//             right: 12,
//             child: SafeArea(
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _LoginScreenContent extends StatelessWidget {
//   const _LoginScreenContent();

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Small bowl mark for continuity with the splash.
//               SizedBox(
//                 width: 64,
//                 height: 56,
//                 child: const CustomPaint(painter: BowlPainter()),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 'Welcome back',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 24),
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'name@email.com',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Password',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: hook up to your auth flow (Firebase Auth, etc.)
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2E5C8A),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   child: const Text('Log in'),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               RichText(
//                 text: const TextSpan(
//                   style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                   children: [
//                     TextSpan(text: "Don't have an account? "),
//                     TextSpan(
//                       text: 'Sign up',
//                       style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




//3rd one better fix
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';

// /// Full intro sequence:
// /// 1. Big bowl + rising steam, full screen.
// /// 2. Bowl fades away, steam keeps rising and "condenses" into the BITEZ
// ///    wordmark (each letter blurs into focus, staggered, like it's
// ///    forming out of the smoke).
// /// 3. A full-screen smoke whiteout sweeps over everything.
// /// 4. The smoke clears to reveal the login screen underneath.
// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   static const int _totalMs = 3400;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _bowlOpacity;
//   late final Animation<double> _steamGroupOpacity;
//   late final Animation<double> _smokeOverlayOpacity;
//   late final Animation<double> _loginOpacity;
//   late final Animation<double> _loginTranslateY;

//   // Condense window (ms) during which the BITEZ letters resolve from blur.
//   static const double _condenseStartMs = 1700;
//   static const double _condenseEndMs = 2300;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat();

//     _bowlOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1500),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1500),
//     ]).animate(_main);

//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 2100),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 900),
//     ]).animate(_main);

//     _smokeOverlayOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2300),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 200),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _loginOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2900),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 100),
//     ]).animate(_main);

//     _loginTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(18.0), weight: 2900),
//       TweenSequenceItem(
//         tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 100),
//     ]).animate(_main);

//     _main.forward();
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     final bowlWidth = (screen.width * 0.8).clamp(220.0, 380.0);
//     final bowlHeight = bowlWidth * (280 / 300);
//     final steamHeight = bowlHeight * 1.15;

//     // BITEZ letters condense one after another within the condense window.
//     const letters = ['B', 'I', 'T', 'E', 'Z'];
//     final letterSpanMs = (_condenseEndMs - _condenseStartMs) - 260;
//     final letterStagger = letterSpanMs / (letters.length - 1);

//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF7EF),
//       body: Stack(
//         children: [
//           // ---------------- Splash layer (bowl, steam, wordmark) ----------------
//           IgnorePointer(
//             child: Container(
//               color: const Color(0xFFFBF7EF),
//               width: double.infinity,
//               height: double.infinity,
//               child: Center(
//                 child: SizedBox(
//                   width: bowlWidth,
//                   height: bowlHeight + steamHeight * 0.75,
//                   child: Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       // Steam
//                       Positioned(
//                         top: 0,
//                         child: AnimatedBuilder(
//                           animation: Listenable.merge([_main, _steamLoop]),
//                           builder: (context, _) => SizedBox(
//                             width: bowlWidth,
//                             height: steamHeight,
//                             child: CustomPaint(
//                               painter: SteamPainter(
//                                 phase: _steamLoop.value,
//                                 groupOpacity: _steamGroupOpacity.value,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),

//                       // Bowl
//                       Positioned(
//                         bottom: 0,
//                         child: AnimatedBuilder(
//                           animation: _main,
//                           builder: (context, child) => Opacity(
//                             opacity: _bowlOpacity.value,
//                             child: child,
//                           ),
//                           child: SizedBox(
//                             width: bowlWidth,
//                             height: bowlHeight,
//                             child: const CustomPaint(painter: BowlPainter()),
//                           ),
//                         ),
//                       ),

//                       // BITEZ wordmark, condensing out of the steam
//                       Positioned(
//                         top: steamHeight * 0.06,
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: List.generate(letters.length, (i) {
//                             final startMs = _condenseStartMs + i * letterStagger;
//                             final endMs = startMs + 260;
//                             return _SmokeLetter(
//                               letter: letters[i],
//                               controller: _main,
//                               startFraction: startMs / _totalMs,
//                               endFraction: endMs / _totalMs,
//                             );
//                           }),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // ---------------- Full-screen smoke whiteout ----------------
//           IgnorePointer(
//             child: AnimatedBuilder(
//               animation: _main,
//               builder: (context, _) {
//                 final opacity = _smokeOverlayOpacity.value;
//                 if (opacity <= 0) return const SizedBox.shrink();
//                 return Opacity(
//                   opacity: opacity,
//                   child: Stack(
//                     children: [
//                       Container(color: const Color(0xFFFBF7EF)),
//                       ..._smokeBlobs(screen),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),

//           // ---------------- Login layer ----------------
//           AnimatedBuilder(
//             animation: _main,
//             builder: (context, child) {
//               final opacity = _loginOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.3,
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Transform.translate(
//                     offset: Offset(0, _loginTranslateY.value),
//                     child: child,
//                   ),
//                 ),
//               );
//             },
//             child: const _LoginScreenContent(),
//           ),

//           // Replay button — remove before shipping.
//           Positioned(
//             top: 44,
//             right: 12,
//             child: SafeArea(
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Soft blurred circles for a bit of texture during the whiteout, rather
//   // than a flat color wipe.
//   List<Widget> _smokeBlobs(Size screen) {
//     final specs = [
//       (screen.width * 0.2, screen.height * 0.3, 180.0),
//       (screen.width * 0.75, screen.height * 0.5, 220.0),
//       (screen.width * 0.4, screen.height * 0.75, 200.0),
//     ];
//     return specs.map((s) {
//       return Positioned(
//         left: s.$1 - s.$3 / 2,
//         top: s.$2 - s.$3 / 2,
//         child: ImageFiltered(
//           imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
//           child: Container(
//             width: s.$3,
//             height: s.$3,
//             decoration: const BoxDecoration(
//               color: Color(0xFFE4E0D6),
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//       );
//     }).toList();
//   }
// }

// /// A single letter that blurs into focus from "smoke" — starts fully blurred
// /// and transparent, resolves to sharp and opaque across [startFraction,
// /// endFraction] of the parent controller's run.
// class _SmokeLetter extends StatelessWidget {
//   final String letter;
//   final Animation<double> controller;
//   final double startFraction;
//   final double endFraction;

//   const _SmokeLetter({
//     required this.letter,
//     required this.controller,
//     required this.startFraction,
//     required this.endFraction,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final curved = CurvedAnimation(
//       parent: controller,
//       curve: Interval(
//         startFraction.clamp(0.0, 1.0),
//         endFraction.clamp(0.0, 1.0),
//         curve: Curves.easeOut,
//       ),
//     );
//     return AnimatedBuilder(
//       animation: curved,
//       builder: (context, _) {
//         final t = curved.value;
//         final blur = 18 * (1 - t);
//         return Opacity(
//           opacity: t,
//           child: ImageFiltered(
//             imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
//             child: Text(
//               letter,
//               style: const TextStyle(
//                 fontSize: 34,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 2,
//                 color: Color(0xFF2A4E7C),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class _LoginScreenContent extends StatelessWidget {
//   const _LoginScreenContent();

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               SizedBox(
//                 width: 64,
//                 height: 60,
//                 child: const CustomPaint(painter: BowlPainter()),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 'Welcome back',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 24),
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'name@email.com',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Password',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: hook up to your auth flow (Firebase Auth, etc.)
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2A4E7C),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   child: const Text('Log in'),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               RichText(
//                 text: const TextSpan(
//                   style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                   children: [
//                     TextSpan(text: "Don't have an account? "),
//                     TextSpan(
//                       text: 'Sign up',
//                       style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


//4th one fix
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';
// import '../widgets/smoke_text_formation.dart';

// /// Full intro sequence:
// /// 1. Big bowl + rising steam, full screen.
// /// 2. Bowl fades away, steam keeps rising and "condenses" into the BITEZ
// ///    wordmark (each letter blurs into focus, staggered, like it's
// ///    forming out of the smoke).
// /// 3. A full-screen smoke whiteout sweeps over everything.
// /// 4. The smoke clears to reveal the login screen underneath.
// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   static const int _totalMs = 4200;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _bowlOpacity;
//   late final Animation<double> _steamGroupOpacity;
//   late final Animation<double> _smokeOverlayOpacity;
//   late final Animation<double> _loginOpacity;
//   late final Animation<double> _loginTranslateY;

//   // Condense window (ms) during which the BITEZ smoke particles swirl
//   // into the letterforms.
//   static const double _condenseStartMs = 1700;
//   static const double _condenseEndMs = 2500;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat();

//     _bowlOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 1500),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2300),
//     ]).animate(_main);

//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 2500),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1300),
//     ]).animate(_main);

//     _smokeOverlayOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 3100),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 200),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _loginOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 3800),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _loginTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(18.0), weight: 3800),
//       TweenSequenceItem(
//         tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _main.forward();
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     final bowlWidth = (screen.width * 0.8).clamp(220.0, 380.0);
//     final bowlHeight = bowlWidth * (280 / 300);
//     final steamHeight = bowlHeight * 1.15;

//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF7EF),
//       body: Stack(
//         children: [
//           // ---------------- Splash layer (bowl, steam, wordmark) ----------------
//           IgnorePointer(
//             child: Container(
//               color: const Color(0xFFFBF7EF),
//               width: double.infinity,
//               height: double.infinity,
//               child: Center(
//                 child: SizedBox(
//                   width: bowlWidth,
//                   height: bowlHeight + steamHeight * 0.75,
//                   child: Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       // Steam
//                       Positioned(
//                         top: 0,
//                         child: AnimatedBuilder(
//                           animation: Listenable.merge([_main, _steamLoop]),
//                           builder: (context, _) => SizedBox(
//                             width: bowlWidth,
//                             height: steamHeight,
//                             child: CustomPaint(
//                               painter: SteamPainter(
//                                 phase: _steamLoop.value,
//                                 groupOpacity: _steamGroupOpacity.value,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),

//                       // Bowl
//                       Positioned(
//                         bottom: 0,
//                         child: AnimatedBuilder(
//                           animation: _main,
//                           builder: (context, child) => Opacity(
//                             opacity: _bowlOpacity.value,
//                             child: child,
//                           ),
//                           child: SizedBox(
//                             width: bowlWidth,
//                             height: bowlHeight,
//                             child: const CustomPaint(painter: BowlPainter()),
//                           ),
//                         ),
//                       ),

//                       // BITEZ wordmark — smoke particles rise and converge
//                       // into the actual letterforms.
//                       Positioned(
//                         top: steamHeight * 0.04,
//                         child: SmokeTextFormation(
//                           controller: _main,
//                           startFraction: _condenseStartMs / _totalMs,
//                           endFraction: _condenseEndMs / _totalMs,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // ---------------- Full-screen smoke whiteout ----------------
//           IgnorePointer(
//             child: AnimatedBuilder(
//               animation: _main,
//               builder: (context, _) {
//                 final opacity = _smokeOverlayOpacity.value;
//                 if (opacity <= 0) return const SizedBox.shrink();
//                 return Opacity(
//                   opacity: opacity,
//                   child: Stack(
//                     children: [
//                       Container(color: const Color(0xFFFBF7EF)),
//                       ..._smokeBlobs(screen),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),

//           // ---------------- Login layer ----------------
//           AnimatedBuilder(
//             animation: _main,
//             builder: (context, child) {
//               final opacity = _loginOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.3,
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Transform.translate(
//                     offset: Offset(0, _loginTranslateY.value),
//                     child: child,
//                   ),
//                 ),
//               );
//             },
//             child: const _LoginScreenContent(),
//           ),

//           // Replay button — remove before shipping.
//           Positioned(
//             top: 44,
//             right: 12,
//             child: SafeArea(
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Soft blurred circles for a bit of texture during the whiteout, rather
//   // than a flat color wipe.
//   List<Widget> _smokeBlobs(Size screen) {
//     final specs = [
//       (screen.width * 0.2, screen.height * 0.3, 180.0),
//       (screen.width * 0.75, screen.height * 0.5, 220.0),
//       (screen.width * 0.4, screen.height * 0.75, 200.0),
//     ];
//     return specs.map((s) {
//       return Positioned(
//         left: s.$1 - s.$3 / 2,
//         top: s.$2 - s.$3 / 2,
//         child: ImageFiltered(
//           imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
//           child: Container(
//             width: s.$3,
//             height: s.$3,
//             decoration: const BoxDecoration(
//               color: Color(0xFFE4E0D6),
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//       );
//     }).toList();
//   }
// }

// class _LoginScreenContent extends StatelessWidget {
//   const _LoginScreenContent();

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               SizedBox(
//                 width: 64,
//                 height: 60,
//                 child: const CustomPaint(painter: BowlPainter()),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 'Welcome back',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 24),
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'name@email.com',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Password',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: hook up to your auth flow (Firebase Auth, etc.)
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2A4E7C),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   child: const Text('Log in'),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               RichText(
//                 text: const TextSpan(
//                   style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                   children: [
//                     TextSpan(text: "Don't have an account? "),
//                     TextSpan(
//                       text: 'Sign up',
//                       style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




//4th better 
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';
// import '../widgets/smoke_text_formation.dart';

// /// Full intro sequence:
// /// 1. Big bowl + rising steam, full screen.
// /// 2. Bowl fades away, steam keeps rising and "condenses" into the BITEZ
// ///    wordmark (each letter blurs into focus, staggered, like it's
// ///    forming out of the smoke).
// /// 3. A full-screen smoke whiteout sweeps over everything.
// /// 4. The smoke clears to reveal the login screen underneath.
// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   static const int _totalMs = 5500;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _bowlOpacity;
//   late final Animation<double> _steamGroupOpacity;
//   late final Animation<double> _smokeOverlayOpacity;
//   late final Animation<double> _loginOpacity;
//   late final Animation<double> _loginTranslateY;

//   // Condense window (ms) during which the BITEZ smoke particles swirl
//   // into the letterforms.
//   static const double _condenseStartMs = 2800;
//   static const double _condenseEndMs = 3600;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat();

//     // Bowl now holds for 2.8s (was ~1.5s) before it starts fading.
//     _bowlOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 2800),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 2300),
//     ]).animate(_main);

//     // Steam lingers a little past the bowl, then fades as the letters finish.
//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 3300),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1800),
//     ]).animate(_main);

//     _smokeOverlayOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 3600),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 300),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 600),
//     ]).animate(_main);

//     _loginOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 4500),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 500),
//     ]).animate(_main);

//     _loginTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(18.0), weight: 4500),
//       TweenSequenceItem(
//         tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 500,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 500),
//     ]).animate(_main);

//     // Wait for the first frame to finish laying out before starting the
//     // animation — starting it immediately in initState is the classic cause
//     // of "works after hot reload, missing on cold start": on some devices
//     // the very first frame's size/metrics aren't fully settled yet.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) _main.forward();
//     });
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF7EF),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           final screen = Size(constraints.maxWidth, constraints.maxHeight);
//           final bowlWidth = (screen.width * 0.8).clamp(220.0, 380.0);
//           final bowlHeight = bowlWidth * (280 / 300);
//           final steamHeight = bowlHeight * 1.15;
//           return _buildStack(screen, bowlWidth, bowlHeight, steamHeight);
//         },
//       ),
//     );
//   }

//   Widget _buildStack(Size screen, double bowlWidth, double bowlHeight, double steamHeight) {
//     return Stack(
//         children: [
//           // ---------------- Splash layer (bowl, steam, wordmark) ----------------
//           IgnorePointer(
//             child: Container(
//               color: const Color(0xFFFBF7EF),
//               width: double.infinity,
//               height: double.infinity,
//               child: Center(
//                 child: SizedBox(
//                   width: bowlWidth,
//                   height: bowlHeight + steamHeight * 0.75,
//                   child: Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       // Steam
//                       Positioned(
//                         top: 0,
//                         child: AnimatedBuilder(
//                           animation: Listenable.merge([_main, _steamLoop]),
//                           builder: (context, _) => SizedBox(
//                             width: bowlWidth,
//                             height: steamHeight,
//                             child: CustomPaint(
//                               painter: SteamPainter(
//                                 phase: _steamLoop.value,
//                                 groupOpacity: _steamGroupOpacity.value,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),

//                       // Bowl
//                       Positioned(
//                         bottom: 0,
//                         child: AnimatedBuilder(
//                           animation: _main,
//                           builder: (context, child) => Opacity(
//                             opacity: _bowlOpacity.value,
//                             child: child,
//                           ),
//                           child: SizedBox(
//                             width: bowlWidth,
//                             height: bowlHeight,
//                             child: const CustomPaint(painter: BowlPainter()),
//                           ),
//                         ),
//                       ),

//                       // BITEZ wordmark — smoke particles rise and converge
//                       // into the actual letterforms.
//                       Positioned(
//                         top: steamHeight * 0.04,
//                         child: SmokeTextFormation(
//                           controller: _main,
//                           startFraction: _condenseStartMs / _totalMs,
//                           endFraction: _condenseEndMs / _totalMs,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // ---------------- Full-screen smoke whiteout ----------------
//           IgnorePointer(
//             child: AnimatedBuilder(
//               animation: _main,
//               builder: (context, _) {
//                 final opacity = _smokeOverlayOpacity.value;
//                 if (opacity <= 0) return const SizedBox.shrink();
//                 return Opacity(
//                   opacity: opacity,
//                   child: Stack(
//                     children: [
//                       Container(color: const Color(0xFFFBF7EF)),
//                       ..._smokeBlobs(screen),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),

//           // ---------------- Login layer ----------------
//           AnimatedBuilder(
//             animation: _main,
//             builder: (context, child) {
//               final opacity = _loginOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.3,
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Transform.translate(
//                     offset: Offset(0, _loginTranslateY.value),
//                     child: child,
//                   ),
//                 ),
//               );
//             },
//             child: const _LoginScreenContent(),
//           ),

//           // Replay button — remove before shipping.
//           Positioned(
//             top: 44,
//             right: 12,
//             child: SafeArea(
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ),
//         ],
//       );
//   }

//   // Soft blurred circles for a bit of texture during the whiteout, rather
//   // than a flat color wipe.
//   List<Widget> _smokeBlobs(Size screen) {
//     final specs = [
//       (screen.width * 0.2, screen.height * 0.3, 180.0),
//       (screen.width * 0.75, screen.height * 0.5, 220.0),
//       (screen.width * 0.4, screen.height * 0.75, 200.0),
//     ];
//     return specs.map((s) {
//       return Positioned(
//         left: s.$1 - s.$3 / 2,
//         top: s.$2 - s.$3 / 2,
//         child: ImageFiltered(
//           imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
//           child: Container(
//             width: s.$3,
//             height: s.$3,
//             decoration: const BoxDecoration(
//               color: Color(0xFFE4E0D6),
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//       );
//     }).toList();
//   }
// }

// class _LoginScreenContent extends StatelessWidget {
//   const _LoginScreenContent();

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               SizedBox(
//                 width: 64,
//                 height: 60,
//                 child: const CustomPaint(painter: BowlPainter()),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 'Welcome back',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 24),
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'name@email.com',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Password',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: hook up to your auth flow (Firebase Auth, etc.)
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2A4E7C),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   child: const Text('Log in'),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               RichText(
//                 text: const TextSpan(
//                   style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                   children: [
//                     TextSpan(text: "Don't have an account? "),
//                     TextSpan(
//                       text: 'Sign up',
//                       style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }







//poraaaa but function
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import '../widgets/bowl_painter.dart';
// import '../widgets/steam_painter.dart';
// import '../widgets/smoke_text_formation.dart';
// import 'home_screen.dart';
// import 'signup_screen.dart';

// /// Full intro sequence:
// /// 1. Big bowl + rising steam, full screen.
// /// 2. Bowl fades away, steam keeps rising and "condenses" into the BITEZ
// ///    wordmark (each letter blurs into focus, staggered, like it's
// ///    forming out of the smoke).
// /// 3. A full-screen smoke whiteout sweeps over everything.
// /// 4. The smoke clears to reveal the login screen underneath.
// class LoginIntroScreen extends StatefulWidget {
//   const LoginIntroScreen({super.key});

//   @override
//   State<LoginIntroScreen> createState() => _LoginIntroScreenState();
// }

// class _LoginIntroScreenState extends State<LoginIntroScreen>
//     with TickerProviderStateMixin {
//   static const int _totalMs = 7100;

//   late final AnimationController _main;
//   late final AnimationController _steamLoop;

//   late final Animation<double> _bowlOpacity;
//   late final Animation<double> _steamGroupOpacity;
//   late final Animation<double> _smokeOverlayOpacity;
//   late final Animation<double> _loginOpacity;
//   late final Animation<double> _loginTranslateY;

//   // Condense window (ms) during which the BITEZ smoke particles swirl
//   // into the letterforms.
//   static const double _condenseStartMs = 5000;
//   static const double _condenseEndMs = 5800;

//   @override
//   void initState() {
//     super.initState();

//     _main = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: _totalMs),
//     );

//     _steamLoop = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat();

//     // Bowl now holds fully visible for a full 5 seconds before fading.
//     _bowlOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 5000),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1700),
//     ]).animate(_main);

//     // Steam lingers a little past the bowl, then fades as the letters finish.
//     _steamGroupOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 5400),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 1300),
//     ]).animate(_main);

//     _smokeOverlayOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 5800),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
//         weight: 600,
//       ),
//       TweenSequenceItem(tween: ConstantTween(1.0), weight: 300),
//       TweenSequenceItem(
//         tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _loginOpacity = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(0.0), weight: 6700),
//       TweenSequenceItem(
//         tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     _loginTranslateY = TweenSequence<double>([
//       TweenSequenceItem(tween: ConstantTween(18.0), weight: 6700),
//       TweenSequenceItem(
//         tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 400,
//       ),
//     ]).animate(_main);

//     // Wait for the first frame to finish laying out before starting the
//     // animation — starting it immediately in initState is the classic cause
//     // of "works after hot reload, missing on cold start": on some devices
//     // the very first frame's size/metrics aren't fully settled yet.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) _main.forward();
//     });
//   }

//   void _replay() {
//     _main.reset();
//     _main.forward();
//   }

//   @override
//   void dispose() {
//     _main.dispose();
//     _steamLoop.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF7EF),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           final screen = Size(constraints.maxWidth, constraints.maxHeight);
//           final bowlWidth = (screen.width * 0.86).clamp(230.0, 420.0);
//           final bowlHeight = bowlWidth * (210 / 340);
//           final steamHeight = bowlHeight * 1.3;
//           return _buildStack(screen, bowlWidth, bowlHeight, steamHeight);
//         },
//       ),
//     );
//   }

//   Widget _buildStack(Size screen, double bowlWidth, double bowlHeight, double steamHeight) {
//     return Stack(
//         children: [
//           // ---------------- Splash layer (bowl, steam, wordmark) ----------------
//           IgnorePointer(
//             child: Container(
//               color: const Color(0xFFFBF7EF),
//               width: double.infinity,
//               height: double.infinity,
//               child: Center(
//                 child: SizedBox(
//                   width: bowlWidth,
//                   height: bowlHeight + steamHeight * 0.75,
//                   child: Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       // Steam
//                       Positioned(
//                         top: 0,
//                         child: AnimatedBuilder(
//                           animation: Listenable.merge([_main, _steamLoop]),
//                           builder: (context, _) => SizedBox(
//                             width: bowlWidth,
//                             height: steamHeight,
//                             child: CustomPaint(
//                               painter: SteamPainter(
//                                 phase: _steamLoop.value,
//                                 groupOpacity: _steamGroupOpacity.value,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),

//                       // Bowl
//                       Positioned(
//                         bottom: 0,
//                         child: AnimatedBuilder(
//                           animation: _main,
//                           builder: (context, child) => Opacity(
//                             opacity: _bowlOpacity.value,
//                             child: child,
//                           ),
//                           child: SizedBox(
//                             width: bowlWidth,
//                             height: bowlHeight,
//                             child: const CustomPaint(painter: BowlPainter()),
//                           ),
//                         ),
//                       ),

//                       // BITEZ wordmark — smoke particles rise and converge
//                       // into the actual letterforms.
//                       Positioned(
//                         top: steamHeight * 0.04,
//                         child: SmokeTextFormation(
//                           controller: _main,
//                           startFraction: _condenseStartMs / _totalMs,
//                           endFraction: _condenseEndMs / _totalMs,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // ---------------- Full-screen smoke whiteout ----------------
//           IgnorePointer(
//             child: AnimatedBuilder(
//               animation: _main,
//               builder: (context, _) {
//                 final opacity = _smokeOverlayOpacity.value;
//                 if (opacity <= 0) return const SizedBox.shrink();
//                 return Opacity(
//                   opacity: opacity,
//                   child: Stack(
//                     children: [
//                       Container(color: const Color(0xFFFBF7EF)),
//                       ..._smokeBlobs(screen),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),

//           // ---------------- Login layer ----------------
//           AnimatedBuilder(
//             animation: _main,
//             builder: (context, child) {
//               final opacity = _loginOpacity.value;
//               return IgnorePointer(
//                 ignoring: opacity < 0.3,
//                 child: Opacity(
//                   opacity: opacity,
//                   child: Transform.translate(
//                     offset: Offset(0, _loginTranslateY.value),
//                     child: child,
//                   ),
//                 ),
//               );
//             },
//             child: const _LoginScreenContent(),
//           ),

//           // Replay button — remove before shipping.
//           Positioned(
//             top: 44,
//             right: 12,
//             child: SafeArea(
//               child: IconButton(
//                 onPressed: _replay,
//                 icon: const Icon(Icons.refresh),
//                 tooltip: 'Replay intro',
//               ),
//             ),
//           ),
//         ],
//       );
//   }

//   // Soft blurred circles for a bit of texture during the whiteout, rather
//   // than a flat color wipe.
//   List<Widget> _smokeBlobs(Size screen) {
//     final specs = [
//       (screen.width * 0.2, screen.height * 0.3, 180.0),
//       (screen.width * 0.75, screen.height * 0.5, 220.0),
//       (screen.width * 0.4, screen.height * 0.75, 200.0),
//     ];
//     return specs.map((s) {
//       return Positioned(
//         left: s.$1 - s.$3 / 2,
//         top: s.$2 - s.$3 / 2,
//         child: ImageFiltered(
//           imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
//           child: Container(
//             width: s.$3,
//             height: s.$3,
//             decoration: const BoxDecoration(
//               color: Color(0xFFE4E0D6),
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//       );
//     }).toList();
//   }
// }

// class _LoginScreenContent extends StatelessWidget {
//   const _LoginScreenContent();

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               SizedBox(
//                 width: 74,
//                 height: 46,
//                 child: const CustomPaint(painter: BowlPainter()),
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 'Welcome back',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 24),
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'name@email.com',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Password',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: hook up to your real auth flow (Firebase Auth, etc.)
//                     Navigator.of(context).pushReplacement(
//                       MaterialPageRoute(builder: (context) => const HomeScreen()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2A4E7C),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   child: const Text('Log in'),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               GestureDetector(
//                 onTap: () {
//                   Navigator.of(context).push(
//                     MaterialPageRoute(builder: (context) => const SignupScreen()),
//                   );
//                 },
//                 child: const Text.rich(
//                   TextSpan(
//                     text: "Don't have an account? ",
//                     style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
//                     children: [
//                       TextSpan(
//                         text: 'Sign up',
//                         style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }






import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/bowl_painter.dart';
import '../widgets/steam_painter.dart';
import '../widgets/smoke_text_formation.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

/// Full intro sequence:
/// 1. Big bowl + rising steam, full screen.
/// 2. Bowl fades away, steam keeps rising and "condenses" into the BITEZ
///    wordmark (each letter blurs into focus, staggered, like it's
///    forming out of the smoke).
/// 3. A full-screen smoke whiteout sweeps over everything.
/// 4. The smoke clears to reveal the login screen underneath.
class LoginIntroScreen extends StatefulWidget {
  const LoginIntroScreen({super.key});

  @override
  State<LoginIntroScreen> createState() => _LoginIntroScreenState();
}

class _LoginIntroScreenState extends State<LoginIntroScreen>
    with TickerProviderStateMixin {
  static const int _totalMs = 7100;

  late final AnimationController _main;
  late final AnimationController _steamLoop;

  late final Animation<double> _bowlOpacity;
  late final Animation<double> _steamGroupOpacity;
  late final Animation<double> _smokeOverlayOpacity;
  late final Animation<double> _loginOpacity;
  late final Animation<double> _loginTranslateY;

  // Condense window (ms) during which the BITEZ smoke particles swirl
  // into the letterforms.
  static const double _condenseStartMs = 5000;
  static const double _condenseEndMs = 5800;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    _steamLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Bowl now holds fully visible for a full 5 seconds before fading.
    _bowlOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 5000),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 400,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1700),
    ]).animate(_main);

    // Steam lingers a little past the bowl, then fades as the letters finish.
    _steamGroupOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 5400),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 400,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 1300),
    ]).animate(_main);

    _smokeOverlayOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5800),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 600,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 300),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 400,
      ),
    ]).animate(_main);

    _loginOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 6700),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 400,
      ),
    ]).animate(_main);

    _loginTranslateY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(18.0), weight: 6700),
      TweenSequenceItem(
        tween: Tween(begin: 18.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 400,
      ),
    ]).animate(_main);

    // Wait for the first frame to finish laying out before starting the
    // animation — starting it immediately in initState is the classic cause
    // of "works after hot reload, missing on cold start": on some devices
    // the very first frame's size/metrics aren't fully settled yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _main.forward();
    });
  }

  void _replay() {
    _main.reset();
    _main.forward();
  }

  @override
  void dispose() {
    _main.dispose();
    _steamLoop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7EF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Size(constraints.maxWidth, constraints.maxHeight);
          final heightReference = (screen.width * 0.92).clamp(180.0, 300.0);
          final bowlHeight = heightReference * (250 / 350);
          final bowlWidth = heightReference * 0.8; // narrower sideways, same height
          final steamHeight = bowlHeight * 1.15;
          return _buildStack(screen, bowlWidth, bowlHeight, steamHeight);
        },
      ),
    );
  }

  Widget _buildStack(Size screen, double bowlWidth, double bowlHeight, double steamHeight) {
    return Stack(
        children: [
          // ---------------- Splash layer (bowl, steam, wordmark) ----------------
          IgnorePointer(
            child: Container(
              color: const Color(0xFFFBF7EF),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: SizedBox(
                  width: bowlWidth,
                  height: bowlHeight + steamHeight * 1.1,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Steam
                      Positioned(
                        top: 0,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_main, _steamLoop]),
                          builder: (context, _) => SizedBox(
                            width: bowlWidth,
                            height: steamHeight,
                            child: CustomPaint(
                              painter: SteamPainter(
                                phase: _steamLoop.value,
                                groupOpacity: _steamGroupOpacity.value,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bowl
                      Positioned(
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _main,
                          builder: (context, child) => Opacity(
                            opacity: _bowlOpacity.value,
                            child: child,
                          ),
                          child: SizedBox(
                            width: bowlWidth,
                            height: bowlHeight,
                            child: const CustomPaint(painter: BowlPainter()),
                          ),
                        ),
                      ),

                      // BITEZ wordmark — smoke particles rise and converge
                      // into the actual letterforms.
                      Positioned(
                        top: steamHeight * 0.04,
                        child: SmokeTextFormation(
                          controller: _main,
                          startFraction: _condenseStartMs / _totalMs,
                          endFraction: _condenseEndMs / _totalMs,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ---------------- Full-screen smoke whiteout ----------------
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _main,
              builder: (context, _) {
                final opacity = _smokeOverlayOpacity.value;
                if (opacity <= 0) return const SizedBox.shrink();
                return Opacity(
                  opacity: opacity,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFFFBF7EF)),
                      ..._smokeBlobs(screen),
                    ],
                  ),
                );
              },
            ),
          ),

          // ---------------- Login layer ----------------
          AnimatedBuilder(
            animation: _main,
            builder: (context, child) {
              final opacity = _loginOpacity.value;
              return IgnorePointer(
                ignoring: opacity < 0.3,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, _loginTranslateY.value),
                    child: child,
                  ),
                ),
              );
            },
            child: const _LoginScreenContent(),
          ),

          // Replay button — remove before shipping.
          Positioned(
            top: 44,
            right: 12,
            child: SafeArea(
              child: IconButton(
                onPressed: _replay,
                icon: const Icon(Icons.refresh),
                tooltip: 'Replay intro',
              ),
            ),
          ),
        ],
      );
  }

  // Soft blurred circles for a bit of texture during the whiteout, rather
  // than a flat color wipe.
  List<Widget> _smokeBlobs(Size screen) {
    final specs = [
      (screen.width * 0.2, screen.height * 0.3, 180.0),
      (screen.width * 0.75, screen.height * 0.5, 220.0),
      (screen.width * 0.4, screen.height * 0.75, 200.0),
    ];
    return specs.map((s) {
      return Positioned(
        left: s.$1 - s.$3 / 2,
        top: s.$2 - s.$3 / 2,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: s.$3,
            height: s.$3,
            decoration: const BoxDecoration(
              color: Color(0xFFE4E0D6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _LoginScreenContent extends StatefulWidget {
  const _LoginScreenContent();

  @override
  State<_LoginScreenContent> createState() => _LoginScreenContentState();
}

class _LoginScreenContentState extends State<_LoginScreenContent> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(email, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to server: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 50,
                child: const CustomPaint(painter: BowlPainter()),
              ),
              const SizedBox(height: 10),
              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.blue),
                decoration: InputDecoration(
                  hintText: 'name@email.com',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.blue),
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Color(0xFF185FA5), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A4E7C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Log in'),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
                child: const Text.rich(
                  TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}