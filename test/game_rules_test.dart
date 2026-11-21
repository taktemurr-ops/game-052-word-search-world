import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:game_052_word_search_world/game/rules.dart';
import 'package:game_052_word_search_world/game/search_engine.dart';

void main() {
  final rules = SearchRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('every word is hidden exactly once, both languages', () {
    for (final n in [1, 9, 77, 640, 5000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      for (final tr in [false, true]) {
        final p = l.p.of(tr);
        expect(checkSearch(p), isNull, reason: 'level $n tr=$tr');
        expect(p.grid.length, p.size * p.size);
      }
    }
  });

  test('grids grow with difficulty', () {
    expect(rules.build(planner.spec(4990)).puzzle.p.en.size, greaterThan(rules.build(planner.spec(1)).puzzle.p.en.size));
  });

  test('selecting a word forwards or backwards finds it; wrong lines count as mistakes', () {
    final p = rules.build(planner.spec(30)).puzzle.p.en;
    final g = SearchGame(p);
    final cells = g.cellsOf(0);
    expect(g.select(cells.last, cells.first), 0);
    expect(g.found, contains(0));
    expect(g.select(0, 0), -1);
    for (var i = 0; i < p.words.length; i++) {
      final c = g.cellsOf(i);
      g.select(c.first, c.last);
    }
    expect(g.won, isTrue);
  });

  test('hints and resume', () {
    final p = rules.build(planner.spec(4)).puzzle.p.tr;
    final g = SearchGame(p);
    expect(g.hint(), 0);
    var guard = 0;
    while (!g.won && guard++ < 100) {
      g.hint();
    }
    expect(g.won, isTrue);
    expect(SearchGame.restore(p, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..60 valid', () {
    for (var n = 1; n <= 60; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
