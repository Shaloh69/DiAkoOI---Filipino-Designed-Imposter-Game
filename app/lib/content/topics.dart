import 'package:diakooi/engine/engine.dart';

/// The twelve launch topics (01-DESIGN.md §13a).
///
/// **Philippine-authored, and that is the point** — not a translated global
/// word list (02-CONTENT-PH.md). The ids here are the ids the word bank and the
/// §13b presets use; changing one silently empties a topic.
abstract final class TopicCatalogue {
  static const topics = <Topic>[
    Topic(
      id: 'aktor',
      nameEn: 'Actors',
      nameFil: 'Aktor at Aktres',
      description: 'PH film and TV actors, past and present.',
    ),
    Topic(
      id: 'kpop',
      nameEn: 'K-Pop',
      nameFil: 'K-Pop',
      description: 'Groups, members, songs.',
    ),
    Topic(
      id: 'pagkain',
      nameEn: 'Food',
      nameFil: 'Pagkain',
      description: 'Dishes, street food, kakanin, merienda.',
    ),
    Topic(
      id: 'opm',
      nameEn: 'OPM',
      nameFil: 'OPM',
      description: 'Original Pilipino Music — artists, bands, songs.',
    ),
    Topic(
      id: 'teleserye',
      nameEn: 'TV and Film',
      nameFil: 'Teleserye at Pelikula',
      description: 'Shows, films, iconic lines.',
    ),
    Topic(
      id: 'lugar',
      nameEn: 'Places',
      nameFil: 'Lugar sa Pilipinas',
      description: 'Cities, islands, landmarks, provinces.',
    ),
    Topic(
      id: 'basketball',
      nameEn: 'Basketball',
      nameFil: 'PBA at Basketball',
      description: 'Teams, players, the sport as lived here.',
    ),
    Topic(
      id: 'buhaypinoy',
      nameEn: 'Everyday Life',
      nameFil: 'Buhay Pinoy',
      description: 'Jeepney, sari-sari, tricycle, fiesta, palengke.',
    ),
    Topic(
      id: 'brands',
      nameEn: 'Brands',
      nameFil: 'Sikat na Brands',
      description: 'Jollibee, Chowking, local household names.',
    ),
    Topic(
      id: 'internet',
      nameEn: 'Internet',
      nameFil: 'Viral at TikTok PH',
      description: 'PH internet culture, memes, creators.',
    ),
    Topic(
      id: 'anime',
      nameEn: 'Anime and Games',
      nameFil: 'Anime at Games',
      description: 'Titles popular with PH players.',
    ),
    Topic(
      id: 'kasaysayan',
      nameEn: 'History',
      nameFil: 'Kasaysayan',
      description: 'Historical figures and events.',
    ),
  ];

  static Topic? byId(String id) {
    for (final topic in topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  /// The display name for a topic id, falling back to the id itself so an
  /// unknown topic is visible rather than blank.
  static String nameFor(String id) => byId(id)?.nameFil ?? id;
}
