import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

/// Kingdom scenes: the drawn world behind the poker table.
///
/// Each scene is authored once in tools/scenes (ordinary canvas code), which
/// records it as a small display list in assets/scenes/<id>.json. This file
/// draws that list. tools/scenes/engine/interp.js is the reference: the two
/// must stay in step, op for op.
///
/// Scene space: height 576, reference width 1344. An 'A' op re-anchors x to
/// the left edge, centre or right edge of the real screen, so corner pieces
/// hug the corners at every aspect ratio.
const double kSceneRefWidth = 1344;
const double kSceneRefHeight = 576;

typedef _SceneOp = void Function(Canvas canvas, double effectiveWidth);

double _anchorDx(String anchor, double effectiveWidth) {
  switch (anchor) {
    case 'L':
      return 0;
    case 'R':
      return effectiveWidth - kSceneRefWidth;
    default:
      return (effectiveWidth - kSceneRefWidth) / 2;
  }
}

double _num(Object? v) => (v as num).toDouble();

/// Parses the scene path text: M/L/Q/C/Z commands, lowercase relative,
/// numbers without exponents ("-.5" and "1.2.5" are valid, as in SVG).
@visibleForTesting
Path parseScenePath(String d) {
  final Path path = Path();
  final int n = d.length;
  int i = 0;
  String cmd = '';
  double cx = 0, cy = 0, sx = 0, sy = 0;

  bool isLetter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  bool isSep(int c) => c == 32 || c == 44 || c == 10 || c == 13 || c == 9;

  double readNum() {
    while (i < n && isSep(d.codeUnitAt(i))) {
      i++;
    }
    bool neg = false;
    if (i < n && (d.codeUnitAt(i) == 45 || d.codeUnitAt(i) == 43)) {
      neg = d.codeUnitAt(i) == 45;
      i++;
    }
    double whole = 0, frac = 0, scale = 1;
    bool dot = false, any = false;
    while (i < n) {
      final int c = d.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        any = true;
        if (dot) {
          scale /= 10;
          frac += (c - 48) * scale;
        } else {
          whole = whole * 10 + (c - 48);
        }
        i++;
      } else if (c == 46 && !dot) {
        dot = true;
        i++;
      } else {
        break;
      }
    }
    if (!any) {
      throw FormatException('Bad number in scene path at $i', d);
    }
    final double v = whole + frac;
    return neg ? -v : v;
  }

  while (i < n) {
    final int ch = d.codeUnitAt(i);
    if (isSep(ch)) {
      i++;
      continue;
    }
    if (isLetter(ch)) {
      cmd = d[i];
      i++;
      if (cmd == 'z' || cmd == 'Z') {
        path.close();
        cx = sx;
        cy = sy;
      }
      continue;
    }
    final bool rel = cmd == cmd.toLowerCase();
    final double ox = rel ? cx : 0, oy = rel ? cy : 0;
    switch (cmd.toLowerCase()) {
      case 'm':
        cx = ox + readNum();
        cy = oy + readNum();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
        cmd = rel ? 'l' : 'L';
        break;
      case 'l':
        cx = ox + readNum();
        cy = oy + readNum();
        path.lineTo(cx, cy);
        break;
      case 'q':
        final double x1 = ox + readNum(), y1 = oy + readNum();
        cx = ox + readNum();
        cy = oy + readNum();
        path.quadraticBezierTo(x1, y1, cx, cy);
        break;
      case 'c':
        final double x1 = ox + readNum(), y1 = oy + readNum();
        final double x2 = ox + readNum(), y2 = oy + readNum();
        cx = ox + readNum();
        cy = oy + readNum();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        break;
      default:
        throw FormatException('Unknown scene path command "$cmd"', d);
    }
  }
  return path;
}

class _ScenePaint {
  _ScenePaint(this.paint, {required this.evenOdd});
  final Paint paint;
  final bool evenOdd;
}

Color _argb(Object? v) => Color(((v as num).toInt()) & 0xFFFFFFFF);

_ScenePaint _parsePaint(Map<String, dynamic> m) {
  final Paint p = Paint()..isAntiAlias = true;
  if (m['k'] == 's') {
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = _num(m['w'])
      ..strokeMiterLimit = 10
      ..strokeCap = switch (m['cap']) {
        'round' => StrokeCap.round,
        'square' => StrokeCap.square,
        _ => StrokeCap.butt,
      }
      ..strokeJoin = switch (m['join']) {
        'round' => StrokeJoin.round,
        'bevel' => StrokeJoin.bevel,
        _ => StrokeJoin.miter,
      };
  }
  final Object? c = m['c'];
  if (c is num) {
    p.color = _argb(c);
  } else if (c is Map) {
    final List<dynamic> st = m['st'] as List<dynamic>;
    final List<Color> colors = <Color>[
      for (final dynamic s in st) _argb((s as List<dynamic>)[1]),
    ];
    final List<double> stops = <double>[
      for (final dynamic s in st)
        _num((s as List<dynamic>)[0]).clamp(0.0, 1.0).toDouble(),
    ];
    if (c['lin'] != null) {
      final List<dynamic> a = c['lin'] as List<dynamic>;
      p.shader = ui.Gradient.linear(
        Offset(_num(a[0]), _num(a[1])),
        Offset(_num(a[2]), _num(a[3])),
        colors,
        stops,
      );
    } else {
      final List<dynamic> a = c['rad'] as List<dynamic>;
      p.shader = ui.Gradient.radial(
        Offset(_num(a[0]), _num(a[1])),
        math.max(0.001, _num(a[2])),
        colors,
        stops,
      );
    }
  }
  final Object? b = m['b'];
  if (b is num && b > 0) {
    p.maskFilter = MaskFilter.blur(BlurStyle.normal, b.toDouble());
  }
  switch (m['m']) {
    case 'plus':
      p.blendMode = BlendMode.plus;
      break;
    case 'screen':
      p.blendMode = BlendMode.screen;
      break;
    case 'multiply':
      p.blendMode = BlendMode.multiply;
      break;
  }
  return _ScenePaint(p, evenOdd: m['eo'] == 1);
}

/// A parsed scene, ready to paint any number of times.
class KingdomSceneData {
  KingdomSceneData._(this.id, this._ops);

  /// Parses a recorded scene. [icons] maps icon names to their 512-unit
  /// paths (assets/scenes/icons.json).
  factory KingdomSceneData.parse(
    String id,
    Map<String, dynamic> json,
    Map<String, Path> icons,
  ) {
    final int version = (json['v'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw FormatException('Unsupported scene version $version in $id');
    }
    final List<Path> paths = <Path>[
      for (final dynamic s in json['paths'] as List<dynamic>)
        parseScenePath(s as String),
    ];
    final List<_ScenePaint> paints = <_ScenePaint>[
      for (final dynamic m in json['paints'] as List<dynamic>)
        _parsePaint(m as Map<String, dynamic>),
    ];
    Path filled(Path p, _ScenePaint sp) {
      if (!sp.evenOdd) return p;
      return Path.from(p)..fillType = PathFillType.evenOdd;
    }

    final List<_SceneOp> ops = <_SceneOp>[];
    for (final dynamic raw in json['ops'] as List<dynamic>) {
      final List<dynamic> op = raw as List<dynamic>;
      switch (op[0] as String) {
        case 'S':
          ops.add((Canvas c, double _) => c.save());
          break;
        case 'X':
          ops.add((Canvas c, double _) => c.restore());
          break;
        case 'T':
          final Float64List m = Float64List.fromList(<double>[
            _num(op[1]), _num(op[2]), 0, 0, //
            _num(op[3]), _num(op[4]), 0, 0, //
            0, 0, 1, 0, //
            _num(op[5]), _num(op[6]), 0, 1,
          ]);
          ops.add((Canvas c, double _) => c.transform(m));
          break;
        case 'A':
          final String a = op[1] as String;
          ops.add((Canvas c, double w) {
            c.restore();
            c.save();
            c.translate(_anchorDx(a, w), 0);
          });
          break;
        case 'R':
          final Rect r = Rect.fromLTWH(
              _num(op[1]), _num(op[2]), _num(op[3]), _num(op[4]));
          final Paint p = paints[(op[5] as num).toInt()].paint;
          ops.add((Canvas c, double _) => c.drawRect(r, p));
          break;
        case 'O':
          final Rect r = Rect.fromCenter(
            center: Offset(_num(op[1]), _num(op[2])),
            width: _num(op[3]).abs() * 2,
            height: _num(op[4]).abs() * 2,
          );
          final Paint p = paints[(op[5] as num).toInt()].paint;
          ops.add((Canvas c, double _) => c.drawOval(r, p));
          break;
        case 'P':
          final _ScenePaint sp = paints[(op[2] as num).toInt()];
          final Path path = filled(paths[(op[1] as num).toInt()], sp);
          ops.add((Canvas c, double _) => c.drawPath(path, sp.paint));
          break;
        case 'I':
          final String name = op[1] as String;
          final Path? icon = icons[name];
          if (icon == null) {
            throw FormatException('Scene $id uses unknown icon $name');
          }
          final _ScenePaint sp = paints[(op[2] as num).toInt()];
          final Path path = filled(icon, sp);
          ops.add((Canvas c, double _) => c.drawPath(path, sp.paint));
          break;
        case 'D':
          final _ScenePaint sp = paints[(op[1] as num).toInt()];
          final List<dynamic> d = op[2] as List<dynamic>;
          final Path path = Path();
          for (int j = 0; j + 2 < d.length; j += 3) {
            final double r = _num(d[j + 2]);
            path.addOval(Rect.fromCircle(
                center: Offset(_num(d[j]), _num(d[j + 1])), radius: r));
          }
          if (sp.evenOdd) path.fillType = PathFillType.evenOdd;
          ops.add((Canvas c, double _) => c.drawPath(path, sp.paint));
          break;
        case 'C':
          final Path clip = Path.from(paths[(op[1] as num).toInt()])
            ..fillType =
                op[2] == 1 ? PathFillType.evenOdd : PathFillType.nonZero;
          ops.add((Canvas c, double _) => c.clipPath(clip));
          break;
        default:
          throw FormatException('Unknown scene op ${op[0]} in $id');
      }
    }
    return KingdomSceneData._(id, ops);
  }

  final String id;
  final List<_SceneOp> _ops;

  /// Paints the scene to fill [size] (any landscape size; the height sets
  /// the scale, the width how much of the panorama shows).
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double k = size.height / kSceneRefHeight;
    final double effectiveWidth = size.width / k;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(k);
    canvas.save();
    canvas.translate(_anchorDx('C', effectiveWidth), 0);
    for (final _SceneOp op in _ops) {
      op(canvas, effectiveWidth);
    }
    canvas.restore();
    canvas.restore();
  }
}

/// Loads and caches scenes and the shared icon set from the asset bundle.
class KingdomSceneLibrary {
  KingdomSceneLibrary._(this._bundle);

  static final KingdomSceneLibrary instance = KingdomSceneLibrary._(rootBundle);

  final AssetBundle _bundle;
  Future<Map<String, Path>>? _icons;
  final Map<String, Future<KingdomSceneData>> _scenes =
      <String, Future<KingdomSceneData>>{};

  static String assetFor(String id) => 'assets/scenes/$id.json';
  static const String iconsAsset = 'assets/scenes/icons.json';

  Future<Map<String, Path>> _loadIcons() async {
    final Map<String, dynamic> raw =
        jsonDecode(await _bundle.loadString(iconsAsset))
            as Map<String, dynamic>;
    final Map<String, dynamic> paths = raw['icons'] as Map<String, dynamic>;
    return <String, Path>{
      for (final MapEntry<String, dynamic> e in paths.entries)
        e.key: parseScenePath(e.value as String),
    };
  }

  Future<KingdomSceneData> load(String id) {
    return _scenes.putIfAbsent(id, () async {
      final Map<String, Path> icons = await (_icons ??= _loadIcons());
      final String text = await _bundle.loadString(assetFor(id));
      return KingdomSceneData.parse(
        id,
        jsonDecode(text) as Map<String, dynamic>,
        icons,
      );
    });
  }

  /// Drops cached scenes (keeps the icons).
  void clear() => _scenes.clear();
}

/// The kingdom's scene behind the table. Paints it once into an image at
/// the screen's resolution (so the table's animations never repaint it),
/// fading in over [fallback] when ready.
class KingdomSceneBackdrop extends StatefulWidget {
  const KingdomSceneBackdrop({
    super.key,
    required this.sceneId,
    this.fallback,
  });

  final String sceneId;

  /// Always painted underneath (keep it cheap); shows until the scene has
  /// faded in, and stays if the scene cannot load.
  final Widget? fallback;

  @override
  State<KingdomSceneBackdrop> createState() => _KingdomSceneBackdropState();
}

class _KingdomSceneBackdropState extends State<KingdomSceneBackdrop> {
  // Large enough for a 1440p tablet; beyond this the scene is upscaled.
  static const double _maxPixels = 4.2e6;

  KingdomSceneData? _data;
  ui.Image? _image;
  Size? _imageFor;
  double? _imageScale;
  bool _rasterising = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KingdomSceneBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sceneId != widget.sceneId) {
      _data = null;
      _imageFor = null;
      _load();
    }
  }

  Future<void> _load() async {
    final int gen = ++_generation;
    try {
      final KingdomSceneData data =
          await KingdomSceneLibrary.instance.load(widget.sceneId);
      if (!mounted || gen != _generation) return;
      setState(() => _data = data);
    } catch (error, stack) {
      debugPrint('Kingdom scene ${widget.sceneId} failed to load: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
      if (mounted && gen == _generation) setState(() => _failed = true);
    }
  }

  void _ensureRaster(Size size, double pixelScale) {
    final KingdomSceneData? data = _data;
    if (data == null || _rasterising || size.isEmpty) return;
    if (_imageFor == size && _imageScale == pixelScale) return;
    _rasterising = true;
    final int gen = _generation;
    double scale = pixelScale;
    final double pixels = size.width * size.height * scale * scale;
    if (pixels > _maxPixels) scale *= math.sqrt(_maxPixels / pixels);
    final int w = math.max(1, (size.width * scale).round());
    final int h = math.max(1, (size.height * scale).round());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(w / size.width, h / size.height);
    data.paint(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    picture.toImage(w, h).then((ui.Image image) {
      picture.dispose();
      _rasterising = false;
      if (!mounted || gen != _generation) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _imageFor = size;
        _imageScale = pixelScale;
      });
    }, onError: (Object error) {
      picture.dispose();
      _rasterising = false;
      debugPrint('Kingdom scene ${widget.sceneId} failed to paint: $error');
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double pixelScale = (GameViewportScale.maybeOf(context) ?? 1.0) *
        MediaQuery.devicePixelRatioOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          if (!_failed && _data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ensureRaster(size, pixelScale);
            });
          }
          final ui.Image? image = _image;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (widget.fallback != null) widget.fallback!,
              if (image != null && !_failed)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Opacity(opacity: t, child: child),
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
