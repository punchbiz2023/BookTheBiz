import 'package:flutter/material.dart';

class PrimaryDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile_picture.png'),
                ),
                SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: Text(
                    'John Doe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _createDrawerItem(
                  icon: Icons.home,
                  text: 'Home',
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _createDrawerItem(
                  icon: Icons.settings,
                  text: 'Settings',
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/settings');
                  },
                ),
                _createDrawerItem(
                  icon: Icons.logout,
                  text: 'Logout',
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createDrawerItem(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onTap: onTap,
    );
  }
}
