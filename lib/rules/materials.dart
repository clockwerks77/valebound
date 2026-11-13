import 'enums.dart';

/// Which material the next Hero-track completion drops.
///
/// DESIGN §5.3 names the materials but not how they are chosen. The simplest
/// deterministic rule is a fixed rotation by the number of Hero-track quests
/// completed so far: Timber, Stone, Star Shards, repeat (DECISIONS.md D-08).
MaterialKind materialForCompletion(int heroTrackCompletionsSoFar) {
  const order = MaterialKind.values;
  final i = heroTrackCompletionsSoFar < 0 ? 0 : heroTrackCompletionsSoFar;
  return order[i % order.length];
}
