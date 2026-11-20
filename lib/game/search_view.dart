import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';
import 'rules.dart';
import 'search_engine.dart';
import 'word_kit.dart';
import 'word_ui.dart';

class SearchView extends StatefulWidget {
  final PlayContext ctx;
  const SearchView({super.key, required this.ctx});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with RoundClock {
  late SearchLevel level;
  late SearchGame game;
  int? _a;
  int? _b;
  int _hints = 0;
  int _solved = 0;
  int _words = 0;
  bool _ended = false;
  int? _hinted;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<SearchLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? SearchGame.restore(level.p.of(_tr), snap) : SearchGame(level.p.of(_tr));
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    startClock(
        initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
        limit: ctx.spec.mode == GameModeId.timeAttack ? 150 : level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() =>
      ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _solved});

  int _cellAt(Offset o, double side) {
    final n = game.p.size;
    final c = side / n;
    final x = (o.dx / c).floor().clamp(0, n - 1);
    final y = (o.dy / c).floor().clamp(0, n - 1);
    return y * n + x;
  }

  void _finishSelection() {
    final a = _a, b = _b;
    setState(() {
      _a = null;
      _b = null;
    });
    if (a == null || b == null || a == b || _ended) return;
    final w = game.select(a, b);
    ctx.sfx(w >= 0 ? Sfx.place : Sfx.error);
    if (w >= 0) _words++;
    setState(() {});
    _persist();
    _checkWin();
  }

  void _checkWin() {
    if (!game.won) return;
    if (_chain) {
      _solved++;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _solved]));
      setState(() {
        level = SearchRules().build(next).puzzle;
        game = SearchGame(level.p.of(_tr));
      });
      _persist();
      return;
    }
    _end(true);
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.mistakes <= 1 && _hints == 0 ? 3 : (game.mistakes <= 4 ? 2 : 1);
    if (_chain) stars = _solved >= 3 ? 3 : (_solved >= 1 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _solved * 1000 : (won ? (4000 - seconds * 3 - game.mistakes * 100).clamp(100, 9000) : 0),
      stars: won ? stars : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      gameStats: {
        'words_found': _words,
        'diagonal_words': [for (var i = 0; i < game.p.words.length; i++) if (game.found.contains(i) && game.p.places[i].$2 != 0 && game.p.places[i].$3 != 0) i].length,
        'grids_cleared': won ? 1 : 0,
      },
    ));
  }

  Future<void> _hint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hinted = game.hint());
    _persist();
    _checkWin();
  }

  Future<void> _booster() async {
    if (!await ctx.requestBooster()) return;
    // Reveal a whole word.
    setState(() {
      for (var i = 0; i < game.p.words.length; i++) {
        if (!game.found.contains(i)) {
          game.found.add(i);
          break;
        }
      }
    });
    _persist();
    _checkWin();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = game.p;
    final lang = WordLang.of(_tr);
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.category, lang.catName(p.cat)),
          (Icons.check_circle, '${game.found.length}/${p.words.length}'),
          if (_chain) (Icons.emoji_events, '$_solved'),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = math.min(c.maxWidth, c.maxHeight) - 12;
            return Center(
              child: GestureDetector(
                onPanStart: (d) => setState(() {
                  _a = _cellAt(d.localPosition, side);
                  _b = _a;
                }),
                onPanUpdate: (d) => setState(() => _b = _cellAt(d.localPosition, side)),
                onPanEnd: (_) => _finishSelection(),
                onTapUp: (d) {
                  final cell = _cellAt(d.localPosition, side);
                  if (_a == null) {
                    setState(() => _a = cell);
                    ctx.sfx(Sfx.tap);
                  } else {
                    _b = cell;
                    _finishSelection();
                  }
                },
                child: Semantics(
                  label: 'word search grid',
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _SearchPainter(game, _a == null ? null : (game.line(_a!, _b ?? _a!) ?? [_a!]),
                        _hinted, cs.primary, ctx.pieceColors),
                  ),
                ),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < p.words.length; i++)
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: game.found.contains(i) ? cs.primaryContainer : null,
                label: Text(
                  level.hiddenList && !game.found.contains(i) ? '${p.words[i][0]}${'·' * (p.words[i].length - 1)}' : p.words[i],
                  style: TextStyle(decoration: game.found.contains(i) ? TextDecoration.lineThrough : null),
                ),
              ),
          ]),
        ),
        BoosterBar(buttons: [
          BoosterButton(Icons.auto_fix_high, tx(ctx, 'Reveal word', 'Kelime aç'), _booster),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}

class _SearchPainter extends CustomPainter {
  final SearchGame g;
  final List<int>? sel;
  final int? hinted;
  final Color accent;
  final List<Color> colors;
  _SearchPainter(this.g, this.sel, this.hinted, this.accent, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final n = g.p.size;
    final c = size.width / n;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), Paint()..color = Colors.white);
    Offset center(int i) => Offset((i % n + 0.5) * c, (i ~/ n + 0.5) * c);
    void band(List<int> cells, Color col) {
      canvas.drawLine(center(cells.first), center(cells.last),
          Paint()
            ..color = col
            ..strokeWidth = c * 0.72
            ..strokeCap = StrokeCap.round);
    }

    var k = 0;
    for (final w in g.found) {
      band(g.cellsOf(w), (colors.isEmpty ? accent : colors[k++ % colors.length]).withValues(alpha: 0.35));
    }
    if (sel != null && sel!.isNotEmpty) band(sel!, accent.withValues(alpha: 0.45));
    if (hinted != null && !g.found.contains(hinted)) {
      canvas.drawCircle(center(g.cellsOf(hinted!).first), c * 0.42,
          Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    for (var i = 0; i < n * n; i++) {
      paintText(canvas, g.p.grid[i], center(i), c * 0.55, Colors.black87);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
