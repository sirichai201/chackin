import 'package:flutter/material.dart';

import '../screen_lecturer/history_lecturer.dart';
import '../screen_lecturer/User_lecturer.dart';
import '../screen_login_user_all/login.dart';

import 'profile_lecturer.dart';

class DrawerbarLecturer extends StatelessWidget {
  const DrawerbarLecturer({super.key});

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      // width: MediaQuery.of(context).size.width * 0.7,
      margin:
          const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 8.0, right: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color.fromARGB(255, 26, 107, 173)),
            child: Center(
              child: Text(
                'เมนู',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            title: 'วิชาสอน',
            icon: Icons.book,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserLecturer()),
            ),
          ),
          _buildDrawerItem(
            title: 'โปรไฟล์',
            icon: Icons.manage_accounts,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => profile_lecturer(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            title: 'ประวัติการเข้าเรียน',
            icon: Icons.history,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => History()),
            ),
          ),
          _buildDrawerItem(
            title: 'ออกจากระบบ',
            icon: Icons.exit_to_app,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Login()),
            ),
          ),
        ],
      ),
    );
  }
}
