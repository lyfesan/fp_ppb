import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/models/app_user.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:fp_ppb/views/screens/account/manage_account_screen.dart';
import 'package:fp_ppb/views/screens/category/manage_categories_screen.dart';
import 'package:fp_ppb/services/firestore_service.dart';
import 'package:fp_ppb/views/screens/profile/currency_selection_screen.dart';
import 'package:get/get.dart';
import '../navigation_menu.dart';
import 'profile_edit_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirestoreService _firestoreService = FirestoreService();
  // Get instance of the currency service
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;
  late Future<AppUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _userFuture = _firestoreService.getAppUser(firebaseUser.uid);
    } else {
      _userFuture = Future.value(null);
    }
    setState(() {});
  }

  Future<void> _signOut() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      final navController = Get.find<NavigationController>();
      navController.resetIndex();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('User not found.'));
          }

          final user = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildProfileDisplay(user, context),
                const SizedBox(height: 20),
                _buildSettingsMenu(context),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: _signOut,
                    child: const Text('Sign Out', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileDisplay(AppUser user, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(30),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: (user.photo != null && user.photo!.isNotEmpty)
                ? NetworkImage(user.photo!)
                : null,
            child: (user.photo == null || user.photo!.isEmpty)
                ? const Icon(Icons.person, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Theme.of(context).primaryColor
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditScreen(user: user),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageCategoriesScreen(),
                ),
              );
            },
          ),
          const Divider(height: 0, indent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Manage Pocket/Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const ManageAccountsScreen(),
                  )
              );
            },
          ),
          const Divider(height: 0, indent: 16),
          ValueListenableBuilder<Currency>(
            valueListenable: _currencyService.activeCurrencyNotifier,
            builder: (context, activeCurrency, child) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                leading: const Icon(Icons.monetization_on_outlined),
                title: const Text('Currency'),
                // Display the active currency code and an icon
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activeCurrency.code,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  // Navigate to the new selection screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CurrencySelectionScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(height: 0, indent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationIcon: const Image(image: AssetImage('assets/icons/logo_app.png'), width: 80),
                applicationName: 'MoneySense',
                applicationVersion: '1.0.0',
                applicationLegalese: '©2025 MoneySense Team',
                children: <Widget>[
                  const SizedBox(height: 10),
                  const Text('This application helps you manage your daily finances efficiently.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
