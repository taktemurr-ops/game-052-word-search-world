import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'search_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-052-word-search-world',
  title: const ['Kelime Avı Dünyası', 'Word Search World', 'Wortsuche Welt', 'Sopa de Letras Mundial', 'Mots Mêlés du Monde'],
  tagline: const ['Harf tablosunda saklı kelimeleri bul!', 'Find the words hidden in the letter grid!', 'Finde die versteckten Wörter!', '¡Encuentra las palabras ocultas!', 'Trouvez les mots cachés !'],
  seedColor: const Color(0xFF2A9D8F),
  icon: Icons.manage_search,
  rules: SearchRules(),
  buildPlay: (ctx) => SearchView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.swipe, ['İlk harften son harfe sürükle.', 'Drag from the first to the last letter.', 'Vom ersten zum letzten Buchstaben ziehen.', 'Arrastra de la primera a la última letra.', 'Glissez de la première à la dernière lettre.']),
    TutorialStep(Icons.north_east, ['Kelimeler çapraz ve ters de olabilir.', 'Words can run diagonally and backwards too.', 'Wörter auch diagonal und rückwärts.', 'También en diagonal y al revés.', 'Aussi en diagonale et à l\'envers.']),
    TutorialStep(Icons.visibility_off, ['Gizli liste bölümlerinde sadece ilk harfler görünür.', 'In hidden-list levels only first letters are shown.', 'Bei verdeckter Liste nur Anfangsbuchstaben.', 'En lista oculta solo se ven las iniciales.', 'Liste cachée : seules les initiales.']),
  ],
);
