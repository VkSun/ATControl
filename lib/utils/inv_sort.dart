/// Сравнение инвентарных номеров: числовые — по значению
/// (1000 < 1059 < 100011), нечисловые — в конец, между собой по алфавиту.
/// inv_number в базе — текст, поэтому серверный order() даёт
/// лексикографический порядок; сортируем на клиенте.
int compareInvNumbers(String a, String b) {
  final na = int.tryParse(a);
  final nb = int.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  if (na != null) return -1;
  if (nb != null) return 1;
  return a.compareTo(b);
}
