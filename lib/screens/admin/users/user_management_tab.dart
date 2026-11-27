import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../models/user_model.dart';
import 'admin_user_detail_screen.dart';
import 'admin_user_form_screen.dart';

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
  String _selectedRoleLabel = 'All Users';
  String _sortId = 'newest';
  int _page = 1;
  int _pageSize = 10;

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

  Future<void> _openAddUser() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminUserFormScreen()),
    );
    if (changed == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _openEditUser(UserModel user) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: user)),
    );
    if (changed == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    if (user.userId == widget.currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account while logged in.'),
          backgroundColor: AppTheme.warningColor,
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
            backgroundColor: AppTheme.successColor,
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
    final sortOptions = [
      KosMateSortOption<UserModel>(
        id: 'newest',
        label: 'Newest',
        comparator: (a, b) => b.userId.compareTo(a.userId),
      ),
      KosMateSortOption<UserModel>(
        id: 'name_asc',
        label: 'Name (A–Z)',
        comparator: (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      ),
      KosMateSortOption<UserModel>(
        id: 'name_desc',
        label: 'Name (Z–A)',
        comparator: (a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      ),
      KosMateSortOption<UserModel>(
        id: 'role',
        label: 'Role',
        comparator: (a, b) => a.role.name.compareTo(b.role.name),
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Users Directory',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foregroundColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              KosMateHeaderActionButton(
                icon: Icons.person_add_outlined,
                label: 'Add User',
                onPressed: _openAddUser,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: KosMateSearchField(
            controller: _searchController,
            hintText: 'Search by name, email, or phone...',
            onChanged: (_) {
              _page = 1;
              _loadUsers();
            },
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadUsers(),
            child: FutureBuilder<List<UserModel>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rawUsers = List<UserModel>.from(snapshot.data ?? []);
                final selectedSort = sortOptions.firstWhere(
                  (s) => s.id == _sortId,
                  orElse: () => sortOptions.first,
                );
                rawUsers.sort(selectedSort.comparator);
                final paged = paginateList(rawUsers, _page, _pageSize);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: KosMateFilterSortBar<UserModel>(
                        filterOptions: const [
                          'All Users',
                          'Tenants',
                          'Owners',
                          'Admins',
                        ],
                        selectedFilter: _selectedRoleLabel,
                        onFilterChanged: (val) {
                          setState(() {
                            _selectedRoleLabel = val;
                            _page = 1;
                            if (val == 'Tenants') {
                              _selectedRoleFilter = UserRole.tenant;
                            } else if (val == 'Owners') {
                              _selectedRoleFilter = UserRole.owner;
                            } else if (val == 'Admins') {
                              _selectedRoleFilter = UserRole.admin;
                            } else {
                              _selectedRoleFilter = null;
                            }
                            _loadUsers();
                          });
                        },
                        sortOptions: sortOptions,
                        selectedSortId: _sortId,
                        onSortChanged: (val) => setState(() {
                          _sortId = val;
                          _page = 1;
                        }),
                        totalCount: rawUsers.length,
                        itemLabel: rawUsers.length == 1 ? 'user' : 'users',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: rawUsers.isEmpty
                          ? const KosMateEmptyState(
                              icon: Icons.people_outline,
                              title: 'No users found',
                              subtitle:
                                  'Try adjusting your search terms or filter.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              itemCount: paged.pageItems.length,
                              itemBuilder: (context, idx) {
                                final u = paged.pageItems[idx];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: AppTheme.borderLight,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminUserDetailScreen(
                                            user: u,
                                            currentUser: widget.currentUser,
                                          ),
                                        ),
                                      );
                                      if (mounted) _loadUsers();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppTheme
                                                .primaryColor
                                                .withValues(alpha: 0.12),
                                            backgroundImage:
                                                (u.avatarUrl != null &&
                                                    u.avatarUrl!.isNotEmpty)
                                                ? NetworkImage(u.avatarUrl!)
                                                : null,
                                            child:
                                                (u.avatarUrl == null ||
                                                    u.avatarUrl!.isEmpty)
                                                ? Text(
                                                    u.name.isNotEmpty
                                                        ? u.name[0]
                                                              .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        u.name,
                                                        style: const TextStyle(
                                                          fontFamily: 'Roboto',
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppTheme
                                                              .foregroundColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (u.phone.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    u.phone,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.textSubtle,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: AppTheme.textMuted,
                                            size: 20,
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: AppTheme.textMuted,
                                            ),
                                            onSelected: (action) {
                                              if (action == 'edit') {
                                                _openEditUser(u);
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
                                                      color: AppTheme
                                                          .destructiveColor,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete User',
                                                      style: TextStyle(
                                                        color: AppTheme
                                                            .destructiveColor,
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
                                  ),
                                );
                              },
                            ),
                    ),
                    if (rawUsers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: KosMatePaginationBar(
                          currentPage: paged.safePage,
                          totalPages: paged.totalPages,
                          totalItems: rawUsers.length,
                          startIndex: paged.startIndex,
                          endIndex: paged.endIndex,
                          pageSize: _pageSize,
                          onPageChanged: (p) => setState(() => _page = p),
                          onPageSizeChanged: (s) => setState(() {
                            _pageSize = s;
                            _page = 1;
                          }),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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
        fg = AppTheme.warningColor;
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
