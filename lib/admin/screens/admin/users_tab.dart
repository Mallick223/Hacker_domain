import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../theme/admin_theme.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final AdminService _adminService = AdminService();
  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _adminService.fetchAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the backend. Pull down to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: AdminColors.dangerBg,
                    padding: const EdgeInsets.all(10),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFE7938C), fontSize: 12)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Text('Registered tourists', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${_users.length} total', style: const TextStyle(color: AdminColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(
                          child: Text('No registered users yet.', style: TextStyle(color: AdminColors.textMuted)),
                        )
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AdminColors.hairline),
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AdminColors.panel2,
                                child: Text(
                                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AdminColors.brass),
                                ),
                              ),
                              title: Text(u.name, style: const TextStyle(color: AdminColors.textPrimary)),
                              subtitle: Text(
                                '${u.email}\n${u.phone}',
                                style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: u.emergencyContact != null
                                  ? const Icon(Icons.contact_phone_outlined, color: AdminColors.safe, size: 18)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
