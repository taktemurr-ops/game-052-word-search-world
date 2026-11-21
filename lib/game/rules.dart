import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'search_engine.dart';

class SearchRules extends GameRules<SearchLevel> {
  @override
  String get gameId => 'game-052-word-search-world';

  @override
  List<String> get optionalMechanics => const ['hidden_list', 'reverse', 'timer'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('words_found', 'Bulunan kelime', 'Words found', scale: 100),
        GameStat('diagonal_words', 'Çapraz kelime', 'Diagonal words', scale: 30),
        GameStat('grids_cleared', 'Biten tablo', 'Grids cleared', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'words_found', [10, 25, 50]),
        MissionTemplate('m2', 'diagonal_words', [1, 3, 5], coinReward: 80),
      ];

  @override
  SearchLevel generate(LevelSpec spec) => generateSearch(spec);

  @override
  Validation validate(SearchLevel l, LevelSpec spec) {
    final e = checkSearch(l.p.en) ?? checkSearch(l.p.tr);
    return e == null ? Validation.ok(l.p.en.words.length) : Validation.fail(e);
  }
}

GameRules createRules() => SearchRules();
