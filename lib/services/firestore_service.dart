import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:fp_ppb/models/category.dart';
import 'package:fp_ppb/core/constants/predefined_data.dart';
import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/income.dart';

class FirestoreService {
  List<Map<String, String>> initIncomeCategories = PredefinedData.incomeCategories;
  List<Map<String, String>> initExpenseCategories = PredefinedData.expenseCategories;
  List<String> initFinanceAccount = PredefinedData.financeAccount;
  final CollectionReference<Map<String, dynamic>> usersCollection =
  FirebaseFirestore.instance.collection('users');

  final CollectionReference<Map<String, dynamic>> categories = FirebaseFirestore
      .instance
      .collection('Category');

  final CollectionReference<Map<String, dynamic>> expenses = FirebaseFirestore
      .instance
      .collection('expenses');

  final CollectionReference<Map<String, dynamic>> income = FirebaseFirestore
      .instance
      .collection('incomes');

  /// Adds a new AppUser to Firestore.
  /// The document ID will be the Firebase Auth User's UID.
  Future<void> createAppUser({
    required fb_auth.User firebaseUser,
    required String name,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      AppUser newUser = AppUser(
        id: firebaseUser.uid,
        name: name,
        email: firebaseUser.email!,
        photo: photoUrl ?? firebaseUser.photoURL,
        createdAt: now,
        updatedAt: now,
      );

      await usersCollection.doc(firebaseUser.uid).set(newUser.toJson());

      for(String item in initFinanceAccount) {
        addFinanceAccount(newUser.id, item);
      }

      for (final category in initIncomeCategories) {
        await addCategoryIncome(
          newUser.id,
          category['name'] ?? '',
          category['icon'] ?? '',
        );
      }

      for (final category in initExpenseCategories) {
        await addCategoryExpense(
          newUser.id,
          category['name'] ?? '',
          category['icon'] ?? '',
        );
      }

      if (kDebugMode) {
        print('AppUser created in Firestore with ID: ${firebaseUser.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating AppUser in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Read App User
  Future<AppUser?> getAppUser(String uid) async {
    try {
      final docSnapshot = await usersCollection.doc(uid).get();

      if (docSnapshot.exists) {
        // Use the factory constructor to create an AppUser instance
        return AppUser.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting AppUser: $e');
      }
      return null;
    }
  }

  Future<bool> isEmailAlreadyInUse(String email, String currentUserId) async {
    try {
      final querySnapshot = await usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final docId = querySnapshot.docs.first.id;
      return docId != currentUserId;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking email: $e');
      }
      return true;
    }
  }

  /// Update App User
  Future<void> updateAppUser(String uid, Map<String, dynamic> data) async {
    try {
      // Automatically add the 'updatedAt' field on every update
      final updateData = {...data, 'updatedAt': Timestamp.now()};

      await usersCollection.doc(uid).update(updateData);
      if (kDebugMode) {
        print('AppUser updated for ID: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating AppUser: $e');
      }
      rethrow;
    }
  }

  /// Delete App User
  Future<void> deleteAppUser(String uid) async {
    try {
      await usersCollection.doc(uid).delete();
      if (kDebugMode) {
        print('AppUser document deleted from Firestore for ID: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting AppUser from Firestore: $e');
      }
      rethrow;
    }
  }

  Future<String> addFinanceAccount(String userId, String name) async {
    final accountRef = await usersCollection
        .doc(userId)
        .collection('account')
        .add({'name': name, 'updatedAt': Timestamp.now()});

    return accountRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getFinanceAccountStream(
      String userId) {
    return usersCollection
        .doc(userId)
        .collection('account')
        .orderBy('name')
        .snapshots();
  }
  Future<void> updateFinanceAccount(
      String userId,
      String docId,
      String updatedName,
      ) {
    return usersCollection
        .doc(userId)
        .collection('account')
        .doc(docId)
        .update({'name': updatedName, 'updatedAt': Timestamp.now()});
  }

  Future<bool> canAccountBeDeleted(String userId, String docId) async {

    List<dynamic> constraintList =
    await checkFinanceAccountConstraints(userId, docId);

    return constraintList.isEmpty;
  }

  Future<List<dynamic>> checkFinanceAccountConstraints(
      String userId,
      String docID,
      ) async {
    final expensesQuery =
    await expenses.where('accountId', isEqualTo: docID).get();

    final incomeQuery =
    await income.where('accountId', isEqualTo: docID).get();

    List<dynamic> constraintList = [];
    for (var doc in expensesQuery.docs) {
      try {
        constraintList.add(Expense.fromFirestore(doc));
      } catch (e) {
        print('Error creating Expense object: $e');
      }
    }

    for (var doc in incomeQuery.docs) {
      try {
        constraintList.add(Income.fromFirestore(doc));
      } catch (e) {
        print('Error creating Income object: $e');
      }
    }

    return constraintList;
  }

  Future<void> deleteFinanceAccount(String userId, String docID) {
    return usersCollection
        .doc(userId)
        .collection('account')
        .doc(docID)
        .delete();
  }

  Future<String> addCategoryExpense(String userId, String name, String icon) async {
    final docRef = await usersCollection
        .doc(userId)
        .collection('ExpenseCategory')
        .add({'name': name, 'icon': icon, 'timestamp': Timestamp.now()});

    return docRef.id; // return the newly created doc's ID
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoriesExpenseStream(
      String userId,
      ) {
    return usersCollection
        .doc(userId)
        .collection('ExpenseCategory')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateCategoryExpense(
      String userId,
      String docID,
      String newName,
      String icon
      ) {
    return usersCollection
        .doc(userId)
        .collection('ExpenseCategory')
        .doc(docID)
        .update({'name': newName, 'icon': icon, 'timestamp': Timestamp.now()});
  }

  Future<List<Expense>> checkCategoryExpense(
      String userId,
      String docID,
      ) async {
    // Check if there are any expenses associated with this category
    final expensesQuery =
    await FirebaseFirestore.instance
        .collection('expenses')
        .where('categoryId', isEqualTo: docID)
        .get();

    List<Expense> expensesList = [];
    for (var doc in expensesQuery.docs) {
      try {
        expensesList.add(Expense.fromFirestore(doc));
      } catch (e) {
        print('Error creating Expense object: $e');
      }
    }

    return expensesList;
  }

  Future<List<Expense>> checkCategoryIncome(String userId, String docID) async {
    // Check if there are any expenses associated with this category
    final expensesQuery =
    await FirebaseFirestore.instance
        .collection('incomes')
        .where('categoryId', isEqualTo: docID)
        .get();

    List<Expense> expensesList = [];
    for (var doc in expensesQuery.docs) {
      try {
        expensesList.add(Expense.fromFirestore(doc));
      } catch (e) {
        print('Error creating Income object: $e');
      }
    }

    return expensesList;
  }

  Future<void> deleteCategoryExpense(String userId, String docID) async {
    await usersCollection
        .doc(userId)
        .collection('ExpenseCategory')
        .doc(docID)
        .delete();
  }

  Future<String> addCategoryIncome(String userId, String name, String icon) async {
    final docRef = await usersCollection
        .doc(userId)
        .collection('IncomeCategory')
        .add({'name': name, 'icon': icon, 'timestamp': Timestamp.now()});

    return docRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoriesIncomeStream(
      String userId,
      ) {
    return usersCollection
        .doc(userId)
        .collection('IncomeCategory')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateCategoryIncome(
      String userId,
      String docID,
      String newName,
      String icon
      ) {
    return usersCollection
        .doc(userId)
        .collection('IncomeCategory')
        .doc(docID)
        .update({'name': newName, 'icon': icon, 'timestamp': Timestamp.now()});
  }

  Future<void> deleteCategoryIncome(String userId, String docID) {
    return usersCollection
        .doc(userId)
        .collection('IncomeCategory')
        .doc(docID)
        .delete();
  }

  Future<CategoryModel?> getExpenseCategoryById(
      String userId,
      String categoryId,
      ) async {
    try {
      final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('ExpenseCategory')
          .doc(categoryId)
          .get();

      if (doc.exists) {
        print("Category found: ${doc.data()}");
        return CategoryModel.fromFirestore(doc);
      }
    } catch (e) {
      print("Error getting category by ID: $e");
      return null;
    }
    return null;
  }

  Future<CategoryModel?> getIncomeCategoryById(
      String userId,
      String categoryId,
      ) async {
    try {
      final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('IncomeCategory')
          .doc(categoryId)
          .get();

      if (doc.exists) {
        print("Category found: ${doc.data()}");
        return CategoryModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Error getting category by ID: $e");
      return null;
    }
  }

  // Add a new expense
  Future<void> addExpense({
    required Expense expense,
    required fb_auth.User user,
  }) async {
    try {
      await expenses.add({...expense.toMap(), 'userId': user.uid});

      if (kDebugMode) {
        print("Expense added for user ${user.uid}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error adding expense: $e");
      }
      rethrow;
    }
  }

  Stream<List<Expense>> getExpenses({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return expenses
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList(),
    );
  }

  Stream<List<Expense>> getExpensesByAccount({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String accountId,
  }) {
    return expenses
        .where('userId', isEqualTo: userId)
        .where('accountId', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList(),
    );
  }

  Future<void> updateExpense({required Expense expense}) async {
    final docRef = FirebaseFirestore.instance
        .collection('expenses')
        .doc(expense.id);

    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) throw Exception("Expense not found.");

    final existingUserId = docSnapshot.data()?['userId'];
    if (existingUserId != expense.userId) {
      throw Exception("Unauthorized access to expense.");
    }

    await docRef.update(expense.toMap());
  }

  Future<void> deleteExpense({
    required String expenseId,
    required String userId,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('expenses')
        .doc(expenseId);

    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) throw Exception("Expense not found.");

    if (docSnapshot.data()?['userId'] != userId) {
      throw Exception("Unauthorized to delete this expense.");
    }

    await docRef.delete();
  }

  // Add income
  Future<void> addIncome({
    required Income incomeData,
    required fb_auth.User user,
  }) async {
    try {
      await income.add({...incomeData.toMap(), 'userId': user.uid});
      if (kDebugMode) print("Income added for user ${user.uid}");
    } catch (e) {
      if (kDebugMode) print("Error adding income: $e");
      rethrow;
    }
  }

  Stream<List<Income>> getIncome({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return income
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => Income.fromFirestore(doc)).toList(),
    );
  }

  Stream<List<Income>> getIncomeByAccount({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String accountId,
  }) {
    return income
        .where('userId', isEqualTo: userId)
        .where('accountId', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => Income.fromFirestore(doc)).toList(),
    );
  }

  // Update income
  Future<void> updateIncome({required Income incomeData}) async {
    final docRef = income.doc(incomeData.id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) throw Exception("Income not found.");

    final existingUserId = docSnapshot.data()?['userId'];
    if (existingUserId != incomeData.userId) {
      throw Exception("Unauthorized access to income.");
    }

    await docRef.update(incomeData.toMap());
  }

  // Delete income
  Future<void> deleteIncome({
    required String incomeId,
    required String userId,
  }) async {
    final docRef = income.doc(incomeId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) throw Exception("Income not found.");
    if (docSnapshot.data()?['userId'] != userId) {
      throw Exception("Unauthorized to delete this income.");
    }

    await docRef.delete();
  }

  Stream<List<Map<String, dynamic>>> getExpensesByCategory({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return expenses
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        Expense expense = Expense.fromFirestore(doc);
        if (categoryTotals.containsKey(expense.categoryId)) {
          categoryTotals[expense.categoryId!] =
              categoryTotals[expense.categoryId!]! + expense.amount;
        } else {
          categoryTotals[expense.categoryId!] = expense.amount;
        }
      }

      List<Map<String, dynamic>> result =
      categoryTotals.entries
          .map(
            (entry) => {'categoryId': entry.key, 'total': entry.value},
      )
          .toList();

      result.sort((a, b) => b['total'].compareTo(a['total']));

      return result;
    });
  }

  Stream<List<Map<String, dynamic>>> getExpensesByCategoryAndAccount({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String accountId,
  }) {
    return expenses
        .where('userId', isEqualTo: userId)
        .where('accountId', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        Expense expense = Expense.fromFirestore(doc);
        if (categoryTotals.containsKey(expense.categoryId)) {
          categoryTotals[expense.categoryId!] =
              categoryTotals[expense.categoryId!]! + expense.amount;
        } else {
          categoryTotals[expense.categoryId!] = expense.amount;
        }
      }

      List<Map<String, dynamic>> result =
      categoryTotals.entries
          .map(
            (entry) => {'categoryId': entry.key, 'total': entry.value},
      )
          .toList();

      result.sort((a, b) => b['total'].compareTo(a['total']));

      return result;
    });
  }

  Stream<List<Map<String, dynamic>>> getIncomesByCategory({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return income
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        Income income = Income.fromFirestore(doc);
        if (categoryTotals.containsKey(income.categoryId)) {
          categoryTotals[income.categoryId!] =
              categoryTotals[income.categoryId!]! + income.amount;
        } else {
          categoryTotals[income.categoryId!] = income.amount;
        }
      }

      List<Map<String, dynamic>> result =
      categoryTotals.entries
          .map(
            (entry) => {'categoryId': entry.key, 'total': entry.value},
      )
          .toList();

      result.sort((a, b) => b['total'].compareTo(a['total']));

      return result;
    });
  }

  Stream<List<Map<String, dynamic>>> getIncomesByCategoryAndAccount({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String accountId,
  }) {
    return income
        .where('userId', isEqualTo: userId)
        .where('accountId', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      Map<String, double> categoryTotals = {};
      for (var doc in snapshot.docs) {
        Income income = Income.fromFirestore(doc);
        if (categoryTotals.containsKey(income.categoryId)) {
          categoryTotals[income.categoryId!] =
              categoryTotals[income.categoryId!]! + income.amount;
        } else {
          categoryTotals[income.categoryId!] = income.amount;
        }
      }

      List<Map<String, dynamic>> result =
      categoryTotals.entries
          .map(
            (entry) => {'categoryId': entry.key, 'total': entry.value},
      )
          .toList();

      result.sort((a, b) => b['total'].compareTo(a['total']));

      return result;
    });
  }
}
