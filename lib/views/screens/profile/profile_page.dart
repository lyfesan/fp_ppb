import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/app_user.dart'; // Adjust the path if needed
import 'package:fp_ppb/views/screens/category/manage_categories_screen.dart'; // Import the manage categories screen
import 'package:fp_ppb/services/firestore_service.dart'; // Adjust the path if needed
import 'profile_edit_screen.dart'; // Import the new edit screen

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirestoreService _firestoreService = FirestoreService();
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
      // Handle case where there is no logged-in user
      _userFuture = Future.value(null);
    }
    // Refresh the UI with the new future
    setState(() {});
  }

  Future<void> _signOut() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
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
      // Navigate to the very first screen after logout
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
            color: Colors.grey.withOpacity(0.15),
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
                      fontWeight: FontWeight.bold, fontSize: 18),
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
                color: Theme.of(context).primaryColor),
            onPressed: () async {
              // Navigate to the edit screen and wait for a result
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditScreen(user: user),
                ),
              );

              // If the result is true, it means the profile was updated.
              // Reload the user data to reflect the changes.
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // ** THIS IS THE NEW CODE **
              // Navigate to the ManageCategoriesScreen
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
              // TODO: Navigate to Manage Pocket page
            },
          ),
          const Divider(height: 0, indent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            leading: const Icon(Icons.monetization_on_outlined),
            title: const Text('Currency'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to Currency page
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
