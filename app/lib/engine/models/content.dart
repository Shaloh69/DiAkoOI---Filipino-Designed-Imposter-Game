import 'package:diakooi/engine/models/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'content.freezed.dart';
part 'content.g.dart';

/// A topic (§11, §13a). All twelve launch topics are Philippine-authored —
/// that is the product's moat, not a localisation detail.
@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required String id,
    required String nameEn,
    required String nameFil,
    @Default('') String description,
    String? iconRef,
    @Default(0) int defaultWeightPercent,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}

/// The three authored clue tiers for one word (§14).
///
/// Nothing here is algorithmically derived: derivation collapses at the table
/// and produces wildly uneven difficulty with no way to tune it.
@freezed
abstract class ClueSet with _$ClueSet {
  const factory ClueSet({
    required String tight,
    required String standard,
    required String loose,
  }) = _ClueSet;

  const ClueSet._();

  factory ClueSet.fromJson(Map<String, dynamic> json) =>
      _$ClueSetFromJson(json);

  String forTier(ClueTier tier) => switch (tier) {
    ClueTier.tight => tight,
    ClueTier.standard => standard,
    ClueTier.loose => loose,
  };
}

/// One word and its authored clues (§11).
@freezed
abstract class WordBankEntry with _$WordBankEntry {
  const factory WordBankEntry({
    required String topicId,
    required String word,
    required ClueSet clues,
    @Default(3) int difficultyRating,
    @Default(ContentRegion.national) ContentRegion region,
  }) = _WordBankEntry;

  factory WordBankEntry.fromJson(Map<String, dynamic> json) =>
      _$WordBankEntryFromJson(json);
}

/// A Vibe Pack (§11, §15).
///
/// The engine only needs identity and licence metadata; the theme itself is
/// Phase 3's and deliberately not modelled here, so `lib/engine/` never grows
/// a dependency on anything visual.
@freezed
abstract class VibePack with _$VibePack {
  const factory VibePack({
    required String id,
    required String displayName,
    required String trackFile,
    required String artistName,
    required String licenceType,
    required String licenceUrl,
    required String attributionText,
  }) = _VibePack;

  factory VibePack.fromJson(Map<String, dynamic> json) =>
      _$VibePackFromJson(json);
}
