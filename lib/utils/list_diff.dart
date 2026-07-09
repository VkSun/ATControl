/// true, если [a] и [b] содержат разные элементы (порядок не важен).
bool listsDiffer(List<String> a, List<String> b) {
  final setA = Set<String>.from(a);
  final setB = Set<String>.from(b);
  return setA.difference(setB).isNotEmpty || setB.difference(setA).isNotEmpty;
}

/// 3-way merge для set-подобных списков (например Driver.vehicleIds):
/// применяет разницу между [current] и [original] («что поменял
/// пользователь в этой сессии редактирования») поверх [fresh] («что сейчас
/// на сервере»), а не поверх [original] («что было при открытии формы»).
///
/// Нужно, когда поле мог независимо изменить кто-то другой, пока форма
/// была открыта: наивная перезапись значением [current] тихо стёрла бы
/// чужую правку, а diff против устаревшего [original] потерял бы её же.
List<String> mergeListDiff({
  required List<String> original,
  required List<String> current,
  required List<String> fresh,
}) {
  final originalSet = Set<String>.from(original);
  final currentSet = Set<String>.from(current);
  final added = currentSet.difference(originalSet);
  final removed = originalSet.difference(currentSet);
  return ({...fresh, ...added}..removeAll(removed)).toList();
}
