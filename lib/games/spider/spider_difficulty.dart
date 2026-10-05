/// The classic Spider levels: the number of suits among the 104 cards.
///
/// Pure Dart without imports: the generator tool runs it outside Flutter.
enum SpiderDifficulty {
  easy(1),
  medium(2),
  hard(4);

  const SpiderDifficulty(this.suitCount);

  /// 1 (eight decks of spades), 2 (spades and hearts) or 4.
  final int suitCount;

  /// The variant of the records: `suits1`, `suits2` or `suits4`.
  String get variant => 'suits$suitCount';
}
