import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/account.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/services/firestore_service.dart';
import 'package:fp_ppb/views/screens/account/add_account_screen.dart';
import 'package:fp_ppb/views/screens/account/account_screen.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  void _fetchUserId() {
    final user = FirebaseAuthService.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    } else {
      print("User not logged in.");
      Navigator.of(context).pop();
    }
  }

  Future<void> _showEditAccountDialog(AccountModel account) async {
    final TextEditingController nameController = TextEditingController(text: account.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Account Name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Account name cannot be empty';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
            ),
          ],
        );
      },
    );

    if (shouldUpdate == true && _userId != null) {
      try {
        await _firestoreService.updateFinanceAccount(
          _userId!,
          account.id,
          nameController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update account: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(AccountModel account) async {
    if (_userId == null) return;

    final bool canDelete = await _firestoreService.canAccountBeDeleted(
      _userId!,
      account.id,
    );

    String message;
    if (canDelete) {
      message = 'Are you sure you want to delete "${account.name}"? This action cannot be undone.';
    } else {
      message = 'Cannot delete "${account.name}" because there are transactions associated with it. Please delete related transactions first.';
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(canDelete ? 'Confirm Delete' : 'Deletion Blocked'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            if (canDelete)
              TextButton(
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
          ],
        );
      },
    );

    if (confirmDelete == true && _userId != null && canDelete) {
      try {
        await _firestoreService.deleteFinanceAccount(_userId!, account.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Accounts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Accounts'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
      ),
      body: StreamBuilder(
        stream: _firestoreService.getFinanceAccountStream(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No accounts found. Add a new one!'));
          }

          final accounts = snapshot.data!.docs.map((doc) => AccountModel.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1.0),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), // Adjusted padding
                  title: Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditAccountDialog(account),
                        tooltip: 'Edit Account',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteConfirmationDialog(account),
                        tooltip: 'Delete Account',
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to AccountScreen, passing the selected account
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountScreen(account: account),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAccountScreen(),
            ),
          );
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account added successfully!')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
