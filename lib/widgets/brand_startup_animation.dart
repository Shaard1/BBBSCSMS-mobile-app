import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_motion_geometry.dart';

/// Plays the approved brand motion once; initialization runs in parallel.
class BrandStartupAnimation extends StatefulWidget {
  const BrandStartupAnimation({
    super.key,
    required this.onCompleted,
    this.firstFrameReady,
  });

  static const duration = Duration(milliseconds: 1800);
  final VoidCallback onCompleted;

  /// Platform rendering barrier; injectable because widget tests have no engine.
  final Future<void>? firstFrameReady;

  @override
  State<BrandStartupAnimation> createState() => _BrandStartupAnimationState();
}

class _BrandStartupAnimationState extends State<BrandStartupAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final _BrandMotionPainter _painter;
  late final Widget _canvas;
  bool _waitingForFrame = false;
  bool _frameReady = false;
  bool _reduceMotion = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: BrandStartupAnimation.duration,
    )..addStatusListener(_onStatus);
    _painter = _BrandMotionPainter(_controller);
    _canvas = RepaintBoundary(
      child: CustomPaint(
        painter: _painter,
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (!_waitingForFrame) {
      _waitingForFrame = true;
      _playAfterFirstFrame();
    }
  }

  Future<void> _playAfterFirstFrame() async {
    // A slow Android/debug first frame can outlast the entire intro. Do not
    // spend its animation time behind the native launch screen.
    await (widget.firstFrameReady ??
        WidgetsBinding.instance.waitUntilFirstFrameRasterized);
    if (!mounted) return;
    _painter.preparePaths();
    _frameReady = true;
    _resumeIfVisible();
  }

  void _resumeIfVisible() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!_frameReady ||
        _reduceMotion ||
        _controller.isCompleted ||
        _controller.isAnimating ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    _controller.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeIfVisible();
    } else if (_controller.isAnimating) {
      _controller.stop(canceled: false);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'BancaoConnect. Starting the app.',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            child: _canvas,
            builder: (context, canvas) {
              final ms = _controller.value * 1800;
              final opening = ms < 400;
              final wordProgress = _ease((ms - 1380) / 220);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      opening ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      opening ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: opening ? _brandBlue : _background,
                  systemNavigationBarIconBrightness:
                      opening ? Brightness.light : Brightness.dark,
                ),
                child: Scaffold(
                  backgroundColor: _brandBlue,
                  body: LayoutBuilder(builder: (context, constraints) {
                    final layout = _MotionLayout(constraints.biggest);
                    return Stack(fit: StackFit.expand, children: [
                      canvas!,
                      Positioned(
                        left: layout.origin.dx + 40 * layout.scale,
                        top: layout.origin.dy + 425 * layout.scale,
                        width: 360 * layout.scale,
                        height: 38 * layout.scale,
                        child: Offstage(
                          offstage: wordProgress <= 0,
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(
                                  0, 13 * (1 - wordProgress) * layout.scale),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('BancaoConnect',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontFamily: 'PublicSansBrand',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 29,
                                      color: Color(0xFF00559C),
                                    )),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]);
                  }),
                ),
              );
            },
          ),
        ),
      );
}

const _brandBlue = Color(0xFF006BB6);
const _brandTeal = Color(0xFF66D9CE);
const _background = Color(0xFFF8FAFC);
const _center = Offset(161, 156);

double _ease(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _mix(double a, double b, double t) => a + (b - a) * t;

double _spring(double progress) {
  final t = progress.clamp(0.0, 1.0);
  return t >= 1 ? 1 : 1 - math.exp(-7 * t) * math.cos(10 * t) * (1 - t);
}

/// Hermite interpolation carries velocity through the staged movement.
double _keyed(double time, List<(double, double)> keys) {
  if (time <= keys.first.$1) return keys.first.$2;
  if (time >= keys.last.$1) return keys.last.$2;
  var i = 0;
  while (keys[i + 1].$1 < time) {
    i++;
  }
  final a = keys[i], b = keys[i + 1];
  final previous = keys[math.max(0, i - 1)];
  final next = keys[math.min(keys.length - 1, i + 2)];
  final duration = b.$1 - a.$1;
  final t = (time - a.$1) / duration;
  final m0 = (b.$2 - previous.$2) / (b.$1 - previous.$1);
  final m1 = (next.$2 - a.$2) / (next.$1 - a.$1);
  return (2 * t * t * t - 3 * t * t + 1) * a.$2 +
      (t * t * t - 2 * t * t + t) * m0 * duration +
      (-2 * t * t * t + 3 * t * t) * b.$2 +
      (t * t * t - t * t) * m1 * duration;
}

class _MotionLayout {
  _MotionLayout(Size size)
      : scale = math.min(math.min(size.width / 440, size.height / 550), 1.3) {
    origin =
        Offset((size.width - 440 * scale) / 2, (size.height - 550 * scale) / 2);
  }

  final double scale;
  late final Offset origin;
}

class _BrandMotionPainter extends CustomPainter {
  _BrandMotionPainter(this.animation)
      : _bodies = brandMotionShapes.map((s) => _quadraticPath(s.body)).toList(),
        _heads = brandMotionShapes.map((s) => _quadraticPath(s.head)).toList(),
        _xs = Float64List(brandMotionShapes.first.arc.length ~/ 2),
        _ys = Float64List(brandMotionShapes.first.arc.length ~/ 2),
        super(repaint: animation);

  final Animation<double> animation;
  final List<Path> _bodies, _heads;
  final Float64List _xs, _ys;
  final Path _morph = Path();
  final Paint _paint = Paint()..isAntiAlias = true;

  void preparePaths() {
    // Exercise the morph/head drawing branches before starting the clock.
    // This is particularly useful on the first JIT/debug launch. Recording
    // commands needs no raster image, extra animation, or retained picture.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final ms in [480.0, 900.0, 1500.0]) {
      _paintFrame(canvas, const Size(440, 550), ms);
    }
    recorder.endRecording().dispose();
  }

  static Path _quadraticPath(List<double> data) {
    final path = Path()..moveTo(data[0], data[1]);
    for (var i = 2; i < data.length; i += 4) {
      path.quadraticBezierTo(data[i], data[i + 1], data[i + 2], data[i + 3]);
    }
    return path..close();
  }

  void _rotate(Canvas canvas, double degrees) {
    canvas.translate(_center.dx, _center.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-_center.dx, -_center.dy);
  }

  Path _body(
      BrandMotionShape shape, double flow, double expansion, double formation) {
    if (formation > .999) return _bodies[brandMotionShapes.indexOf(shape)];
    for (var i = 0; i < _xs.length; i++) {
      final j = i * 2;
      var x = _mix(shape.circle[j], shape.arc[j], flow);
      var y = _mix(shape.circle[j + 1], shape.arc[j + 1], flow);
      x = shape.cx + (x - shape.cx) * expansion;
      y = shape.cy + (y - shape.cy) * expansion;
      _xs[i] = _mix(x, shape.outline[j], formation);
      _ys[i] = _mix(y, shape.outline[j + 1], formation);
    }
    _morph.reset();
    _morph.moveTo(_xs[0], _ys[0]);
    final count = _xs.length;
    for (var i = 0; i < count; i++) {
      final a = (i + count - 1) % count, c = (i + 1) % count;
      final d = (i + 2) % count;
      _morph.cubicTo(
        _xs[i] + (_xs[c] - _xs[a]) / 6,
        _ys[i] + (_ys[c] - _ys[a]) / 6,
        _xs[c] - (_xs[d] - _xs[i]) / 6,
        _ys[c] - (_ys[d] - _ys[i]) / 6,
        _xs[c],
        _ys[c],
      );
    }
    return _morph..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrame(canvas, size, animation.value * 1800);
  }

  void _paintFrame(Canvas canvas, Size size, double ms) {
    if (size.isEmpty) return;
    if (ms <= 100) {
      canvas.drawColor(_brandBlue, BlendMode.src);
      return;
    }
    canvas.drawColor(_background, BlendMode.src);
    final layout = _MotionLayout(size);
    final cover = math.max(1.0, size.longestSide / (550 * layout.scale));
    final rotation = _keyed(ms, const [
      (0, -410),
      (140, -427),
      (480, -160),
      (800, -28),
      (1080, 7),
      (1260, -1.7),
      (1480, 0),
      (1800, 0),
    ]);
    final dx = _keyed(ms, const [
      (0, 0),
      (220, -11),
      (570, 8),
      (970, -2),
      (1320, 0),
      (1800, 0),
    ]);
    final dy = _keyed(ms, const [
      (0, 0),
      (220, 5),
      (570, -8),
      (970, 2),
      (1320, 0),
      (1800, 0),
    ]);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(layout.origin.dx + (75 + dx) * layout.scale,
        layout.origin.dy + (110 + dy) * layout.scale);
    canvas.scale(.9 * layout.scale);
    _rotate(canvas, rotation);
    final hole = 57 * _ease((ms - 420) / 220) * (1 - _ease((ms - 710) / 260));
    if (hole > 0) {
      final opening = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(const Rect.fromLTWH(-4000, -4000, 8000, 8000))
        ..addOval(Rect.fromCircle(center: _center, radius: hole));
      canvas.clipPath(opening);
    }
    for (var index = 0; index < brandMotionShapes.length; index++) {
      final shape = brandMotionShapes[index];
      final local = ms - const [0, 42, 90][index];
      final flow = _ease((local - 160) / 380);
      final formation = _ease((local - 510) / 510);
      final expansion =
          1 + 6.8 * cover * math.pow(1 - _ease((local - 85) / 545), 2.1);
      final lead = _keyed(local, _leadKeys[index]);
      final separation = _keyed(local, const [
        (0, 0),
        (460, 0),
        (710, 14),
        (940, -3),
        (1130, 1),
        (1370, 0),
        (1800, 0),
      ]);
      final angle = const [-math.pi / 2, 5 * math.pi / 6, math.pi / 6][index];
      final stretch = _keyed(local, const [
        (0, 0),
        (330, .075),
        (610, -.025),
        (820, .018),
        (1100, 0),
        (1800, 0),
      ]);
      canvas.save();
      _rotate(canvas, lead);
      canvas.translate(
          math.cos(angle) * separation, math.sin(angle) * separation);
      canvas.translate(shape.cx, shape.cy);
      canvas.scale(1 + stretch, 1 - stretch * .55);
      canvas.translate(-shape.cx, -shape.cy);
      _paint.color = index == 2
          ? Color.lerp(_brandBlue, _brandTeal, _ease((local - 670) / 380))!
          : _brandBlue;
      canvas.drawPath(_body(shape, flow, expansion, formation), _paint);
      final headProgress = ((local - 730) / 395).clamp(0.0, 1.0);
      if (headProgress > 0) {
        final scale = _spring(headProgress);
        final lag = 11 * math.sin(math.pi * headProgress) * (1 - headProgress);
        canvas.save();
        canvas.translate(shape.headX, shape.headY);
        canvas.rotate(-lag * math.pi / 180);
        canvas.scale(scale, 1 + (scale - 1) * .65);
        canvas.translate(-shape.headX, -shape.headY);
        canvas.drawPath(_heads[index], _paint);
        canvas.restore();
      }
      canvas.restore();
    }
    final fillRadius = 145 * (1 - _ease((ms - 430) / 190));
    if (fillRadius > 0) {
      _paint.color = _brandBlue;
      canvas.drawCircle(_center, fillRadius, _paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMotionPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

const _leadKeys = <List<(double, double)>>[
  [(0, 0), (330, 8), (660, 13), (940, -3), (1210, .5), (1450, 0), (1800, 0)],
  [(0, 0), (330, -7), (660, -8), (940, 2), (1210, -.4), (1450, 0), (1800, 0)],
  [(0, 0), (330, 13), (660, 18), (940, -4), (1210, .7), (1450, 0), (1800, 0)],
];
