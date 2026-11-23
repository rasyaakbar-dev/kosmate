import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/user_model.dart';
import 'user_form_dialog.dart';

class UserManagementTab extends StatefulWidget {
  final UserModel currentUser;

  const UserManagementTab({super.key, required this.currentUser});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final _userService = sl.user;
  final _searchController = TextEditingController();

  late Future<List<UserModel>> _usersFuture;
  UserRole? _selectedRoleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    setState(() {
      _usersFuture = _userService.getAllUsers(
        roleFilter: _selectedRoleFilter,
        searchQuery: _searchController.text.trim(),
      );
    });
  }

  Future<void> _openAddUserDialog() async {
    final changed = await UserFormDialog.show(context);
    if (changed == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _openEditUserDialog(UserModel user) async {
    final changed = await UserFormDialog.show(context, user: user);
    if (changed == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    if (user.userId == widget.currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account while logged in.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete user "${user.name}" (${user.email})?\n\n'
          'All associated records and data for this user will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _userService.deleteUser(user.userId);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header: Title & Add User Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Users Directory',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foregroundColor,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _openAddUserDialog,
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _loadUsers(),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone...',
              hintStyle: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textMuted,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _loadUsers();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Role Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              _buildFilterChip('All Users', null),
              const SizedBox(width: 8),
              _buildFilterChip('Tenants', UserRole.tenant),
              const SizedBox(width: 8),
              _buildFilterChip('Kos Owners', UserRole.owner),
              const SizedBox(width: 8),
              _buildFilterChip('Admins', UserRole.admin),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Users List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadUsers(),
            child: FutureBuilder<List<UserModel>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const KosMateEmptyState(
                    icon: Icons.people_outline,
                    title: 'No users found',
                    subtitle: 'Try adjusting your search terms or filter.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, idx) {
                    final u = users[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.borderLight),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          u.name,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.foregroundColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildRoleBadge(u.role),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    u.email,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (u.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      u.phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSubtle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppTheme.textMuted,
                              ),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _openEditUserDialog(u);
                                } else if (action == 'delete') {
                                  _confirmDeleteUser(u);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppTheme.textDark,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Edit User / Role'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppTheme.destructiveColor,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete User',
                                        style: TextStyle(
                                          color: AppTheme.destructiveColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, UserRole? role) {
    final isSelected = _selectedRoleFilter == role;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedRoleFilter = role);
        _loadUsers();
      },
      selectedColor: AppTheme.accentColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.accentColor : AppTheme.textDark,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accentColor : AppTheme.borderMedium,
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color bg;
    Color fg;
    String label;

    switch (role) {
      case UserRole.admin:
        bg = AppTheme.destructiveLight;
        fg = AppTheme.destructiveColor;
        label = 'ADMIN';
        break;
      case UserRole.owner:
        bg = AppTheme.warningLight;
        fg = Colors.orange[900]!;
        label = 'OWNER';
        break;
      case UserRole.tenant:
        bg = AppTheme.primaryLight;
        fg = AppTheme.primaryColor;
        label = 'TENANT';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
