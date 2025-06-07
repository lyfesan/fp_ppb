class Category {
  final String id;
  final String name;
  final String? incomeId;
  final String? expenseId;

  // Constructor
  Category({
    required this.id,
    required this.name,
    this.incomeId,
    this.expenseId,
  });
}
