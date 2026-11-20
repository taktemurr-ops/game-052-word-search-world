import '../core/level_plan.dart';
import '../core/rng.dart';
import 'word_kit.dart';

/// Word Search: words hidden in a letter grid in straight lines.
class SearchPuzzle {
  final int size;
  final List<String> grid;
  final List<String> words;

  /// start cell index and direction (dr, dc) of every word.
  final List<(int, int, int)> places;
  final String cat;
  const SearchPuzzle(this.size, this.grid, this.words, this.places, this.cat);
}

class SearchLevel {
  final Dual<SearchPuzzle> p;
  final int timeLimit;
  final bool hiddenList;
  const SearchLevel(this.p, this.timeLimit, this.hiddenList);
}

const kDirs = [(0, 1), (1, 0), (1, 1), (-1, 1), (0, -1), (-1, 0), (-1, -1), (1, -1)];

List<(int, int)> searchDirs(int difficulty, bool reverse) {
  final n = difficulty <= 2 ? 2 : (difficulty <= 5 ? 3 : 4);
  final d = kDirs.take(n).toList();
  if (reverse || difficulty >= 8) d.addAll(kDirs.skip(4).take(n));
  return d;
}

SearchPuzzle makeSearch(WordLang lang, SeededRandom r, int difficulty, int theme, bool reverse) {
  final size = (6 + difficulty ~/ 2).clamp(6, 11);
  final count = (4 + difficulty).clamp(4, size + 2);
  final cats = lang.categories;
  final cat = cats[theme % cats.length];
  final pool = <String>[
    for (final e in lang.bankFor(cat))
      if (!e.word.contains(' ') && e.word.length >= 3 && e.word.length <= size) e.word
  ];
  r.shuffle(pool);
  final extra = [for (final w in lang.words) if (w.length >= 4 && w.length <= size) w];
  r.shuffle(extra);
  final candidates = [...pool, ...extra.take(60)];
  final dirs = searchDirs(difficulty, reverse);
  final grid = List.filled(size * size, '');
  final words = <String>[];
  final places = <(int, int, int)>[];
  for (final w in candidates) {
    if (words.length >= count) break;
    if (words.contains(w)) continue;
    for (var t = 0; t < 60; t++) {
      final d = dirs[r.nextInt(dirs.length)];
      final row = r.nextInt(size), col = r.nextInt(size);
      final er = row + d.$1 * (w.length - 1), ec = col + d.$2 * (w.length - 1);
      if (er < 0 || er >= size || ec < 0 || ec >= size) continue;
      var ok = true;
      for (var k = 0; k < w.length && ok; k++) {
        final c = grid[(row + d.$1 * k) * size + col + d.$2 * k];
        if (c != '' && c != w[k]) ok = false;
      }
      if (!ok) continue;
      for (var k = 0; k < w.length; k++) {
        grid[(row + d.$1 * k) * size + col + d.$2 * k] = w[k];
      }
      words.add(w);
      places.add((row * size + col, d.$1, d.$2));
      break;
    }
  }
  for (var i = 0; i < grid.length; i++) {
    if (grid[i] == '') grid[i] = lang.randomLetter(r);
  }
  return SearchPuzzle(size, grid, words, places, cat);
}

SearchLevel generateSearch(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final rev = spec.has('reverse');
  final en = makeSearch(WordLang.of(false), SeededRandom(r.nextUint32()), spec.difficulty, spec.theme + spec.levelId, rev);
  final tr = makeSearch(WordLang.of(true), SeededRandom(r.nextUint32()), spec.difficulty, spec.theme + spec.levelId, rev);
  return SearchLevel(Dual(en, tr), spec.has('timer') ? 60 + en.words.length * 20 : 0, spec.has('hidden_list'));
}

/// Number of times [w] can be read in the grid (all 8 directions).
int occurrences(SearchPuzzle p, String w) {
  var n = 0;
  final s = p.size;
  for (var i = 0; i < s * s; i++) {
    if (p.grid[i] != w[0]) continue;
    for (final d in kDirs) {
      final r0 = i ~/ s, c0 = i % s;
      var k = 0;
      while (k < w.length) {
        final r = r0 + d.$1 * k, c = c0 + d.$2 * k;
        if (r < 0 || r >= s || c < 0 || c >= s || p.grid[r * s + c] != w[k]) break;
        k++;
      }
      if (k == w.length) n++;
    }
  }
  // A palindrome is read twice along the same cells.
  if (w.split('').reversed.join() == w) n = (n + 1) ~/ 2;
  return n;
}

String? checkSearch(SearchPuzzle p) {
  if (p.words.length < 4) return 'few words';
  for (var i = 0; i < p.words.length; i++) {
    final w = p.words[i];
    final (start, dr, dc) = p.places[i];
    for (var k = 0; k < w.length; k++) {
      final r = start ~/ p.size + dr * k, c = start % p.size + dc * k;
      if (p.grid[r * p.size + c] != w[k]) return 'misplaced $w';
    }
    if (occurrences(p, w) != 1) return 'ambiguous $w';
  }
  return null;
}

class SearchGame {
  final SearchPuzzle p;
  final Set<int> found = {};
  final Set<int> hinted = {};
  int mistakes = 0;
  int moves = 0;
  SearchGame(this.p);

  bool get won => found.length == p.words.length;

  List<int> cellsOf(int word) {
    final (start, dr, dc) = p.places[word];
    return [for (var k = 0; k < p.words[word].length; k++) (start ~/ p.size + dr * k) * p.size + start % p.size + dc * k];
  }

  /// Cells on the straight line a..b, or null if not a straight line.
  List<int>? line(int a, int b) {
    final s = p.size;
    final dr = b ~/ s - a ~/ s, dc = b % s - a % s;
    if (!(dr == 0 || dc == 0 || dr.abs() == dc.abs())) return null;
    final n = (dr.abs() > dc.abs() ? dr.abs() : dc.abs()) + 1;
    final sr = dr.sign, sc = dc.sign;
    return [for (var k = 0; k < n; k++) (a ~/ s + sr * k) * s + a % s + sc * k];
  }

  /// Returns the index of the word found by selecting a..b, or -1.
  int select(int a, int b) {
    final cells = line(a, b);
    if (cells == null || cells.length < 2) return -1;
    moves++;
    final text = cells.map((i) => p.grid[i]).join();
    final rev = text.split('').reversed.join();
    for (var i = 0; i < p.words.length; i++) {
      if (found.contains(i)) continue;
      if (p.words[i] == text || p.words[i] == rev) {
        final cw = cellsOf(i);
        final same = cw.length == cells.length &&
            (List.generate(cw.length, (k) => cw[k] == cells[k]).every((x) => x) ||
                List.generate(cw.length, (k) => cw[k] == cells[cells.length - 1 - k]).every((x) => x));
        if (same) {
          found.add(i);
          return i;
        }
      }
    }
    mistakes++;
    return -1;
  }

  /// Highlights the first letter of an unfound word.
  int? hint() {
    for (var i = 0; i < p.words.length; i++) {
      if (!found.contains(i) && !hinted.contains(i)) {
        hinted.add(i);
        return i;
      }
    }
    for (var i = 0; i < p.words.length; i++) {
      if (!found.contains(i)) {
        found.add(i);
        return i;
      }
    }
    return null;
  }

  String serialize() => [found.join(','), hinted.join(','), '$mistakes', '$moves'].join('|');

  factory SearchGame.restore(SearchPuzzle p, String s) {
    final g = SearchGame(p);
    final parts = s.split('|');
    if (parts.length < 4) return g;
    g.found.addAll(splitList(parts[0]).map(int.parse).where((i) => i < p.words.length));
    g.hinted.addAll(splitList(parts[1]).map(int.parse));
    g.mistakes = int.tryParse(parts[2]) ?? 0;
    g.moves = int.tryParse(parts[3]) ?? 0;
    return g;
  }
}
