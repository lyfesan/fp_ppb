class Expense{
  final String id;
  final String name;
  final DateTime date;
  final String amount;
  final String categoryId;
  final String userId;

  // Constructor
  Expense({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.categoryId,
    required this.userId,
  });
}