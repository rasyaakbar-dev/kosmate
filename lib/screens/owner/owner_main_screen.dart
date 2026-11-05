import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../models/house_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';
import '../../services/auth_service.dart';
import '../../services/house_service.dart';
import '../../services/room_service.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../services/complaint_service.dart';

class OwnerMainScreen extends StatefulWidget {
  final UserModel user;

  const OwnerMainScreen({super.key, required this.user});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _OwnerPropertiesTab(user: widget.user),
      _OwnerBookingsTab(user: widget.user),
      _OwnerPaymentsTab(user: widget.user),
      _OwnerComplaintsTab(user: widget.user),
      _OwnerProfileTab(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Properties',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: PROPERTIES (HOUSES & ROOMS)
// -----------------------------------------------------------------------------
class _OwnerPropertiesTab extends StatefulWidget {
  final UserModel user;
  const _OwnerPropertiesTab({required this.user});

  @override
  State<_OwnerPropertiesTab> createState() => _OwnerPropertiesTabState();
}

class _OwnerPropertiesTabState extends State<_OwnerPropertiesTab> {
  final _houseService = HouseService();
  final _roomService = RoomService();

  late Future<List<HouseModel>> _housesFuture;

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  void _loadHouses() {
    setState(() {
      _housesFuture = _houseService.getHousesByOwner(widget.user.userId);
    });
  }

  void _showAddHouseDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Boarding House'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'House Name',
                  hintText: 'e.g. Kos Melati Indah',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'e.g. Jl. Telekomunikasi No. 1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) return;
              try {
                await _houseService.createHouse(
                  HouseModel(
                    houseId: 0,
                    ownerId: widget.user.userId,
                    houseName: nameCtrl.text.trim(),
                    houseAddress: addressCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadHouses();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save House'),
          ),
        ],
      ),
    );
  }

  void _showAddRoomDialog(int houseId) {
    final numberCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Standard');
    final priceCtrl = TextEditingController(text: '1000000');
    final facilitiesCtrl = TextEditingController(text: 'AC, WiFi, Kasur, Kamar Mandi Dalam');
    RoomStatus selectedStatus = RoomStatus.available;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Room to House'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Room Number (e.g. 101)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Room Type (e.g. Deluxe/Single)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Price (IDR)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facilitiesCtrl,
                  decoration: const InputDecoration(labelText: 'Facilities'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: RoomStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.displayName));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                if (numberCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _roomService.createRoom(
                    RoomModel(
                      roomId: 0,
                      houseId: houseId,
                      roomNumber: numberCtrl.text.trim(),
                      roomType: typeCtrl.text.trim(),
                      price: price,
                      facilities: facilitiesCtrl.text.trim(),
                      status: selectedStatus,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save Room'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_outlined),
            tooltip: 'Add House',
            onPressed: _showAddHouseDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadHouses(),
        child: FutureBuilder<List<HouseModel>>(
          future: _housesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final houses = snapshot.data ?? [];
            if (houses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.house_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No boarding houses listed yet.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Boarding House'),
                      onPressed: _showAddHouseDialog,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: houses.length,
              itemBuilder: (context, index) {
                final house = houses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              house.houseName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1E3A8A)),
                              tooltip: 'Add Room',
                              onPressed: () => _showAddRoomDialog(house.houseId),
                            ),
                          ],
                        ),
                        Text(house.houseAddress, style: TextStyle(color: Colors.grey[600])),
                        const Divider(height: 20),
                        // Rooms list under this house
                        FutureBuilder<List<RoomModel>>(
                          future: _roomService.getRooms(houseId: house.houseId),
                          builder: (context, roomSnap) {
                            if (roomSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(child: LinearProgressIndicator()),
                              );
                            }
                            final rooms = roomSnap.data ?? [];
                            if (rooms.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No rooms added yet. Tap (+) to add rooms.'),
                              );
                            }

                            return Column(
                              children: rooms.map((r) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Room ${r.roomNumber} (${r.roomType})'),
                                  subtitle: Text(Formatters.formatCurrency(r.price)),
                                  trailing: DropdownButton<RoomStatus>(
                                    value: r.status,
                                    underline: const SizedBox(),
                                    items: RoomStatus.values.map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text(s.displayName),
                                      );
                                    }).toList(),
                                    onChanged: (newStatus) async {
                                      if (newStatus != null) {
                                        await _roomService.updateRoomStatus(r.roomId, newStatus);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
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
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: INCOMING BOOKING REQUESTS
// -----------------------------------------------------------------------------
class _OwnerBookingsTab extends StatefulWidget {
  final UserModel user;
  const _OwnerBookingsTab({required this.user});

  @override
  State<_OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}

class _OwnerBookingsTabState extends State<_OwnerBookingsTab> {
  final _bookingService = BookingService();
  late Future<List<BookingModel>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    setState(() {
      _bookingsFuture = _bookingService.getBookingsForOwner(widget.user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Booking Requests')),
      body: RefreshIndicator(
        onRefresh: () async => _loadBookings(),
        child: FutureBuilder<List<BookingModel>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('No booking requests found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final b = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Room ${b.room?.roomNumber ?? b.roomId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Chip(label: Text(b.status.displayName)),
                          ],
                        ),
                        Text('Tenant: ${b.user?.name ?? "User #${b.userId}"} (${b.user?.phone ?? "-"})'),
                        Text('Move-in Date: ${Formatters.formatDate(b.requestDate)}'),
                        if (b.notes != null) Text('Notes: ${b.notes}'),
                        if (b.status == BookingStatus.pending) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  await _bookingService.updateBookingStatus(
                                    bookingId: b.bookingId,
                                    status: BookingStatus.rejected,
                                  );
                                  _loadBookings();
                                },
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await _bookingService.updateBookingStatus(
                                    bookingId: b.bookingId,
                                    status: BookingStatus.approved,
                                    roomId: b.roomId,
                                  );
                                  _loadBookings();
                                },
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: BILLING & PAYMENTS
// -----------------------------------------------------------------------------
class _OwnerPaymentsTab extends StatefulWidget {
  final UserModel user;
  const _OwnerPaymentsTab({required this.user});

  @override
  State<_OwnerPaymentsTab> createState() => _OwnerPaymentsTabState();
}

class _OwnerPaymentsTabState extends State<_OwnerPaymentsTab> {
  final _paymentService = PaymentService();
  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = _paymentService.getPaymentsForOwner(widget.user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Billing & Invoices')),
      body: RefreshIndicator(
        onRefresh: () async => _loadPayments(),
        child: FutureBuilder<List<PaymentModel>>(
          future: _paymentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('No payment invoices registered.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final p = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Formatters.formatCurrency(p.amount),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            Chip(label: Text(p.status.displayName)),
                          ],
                        ),
                        Text('Tenant: ${p.user?.name ?? "User #${p.userId}"}'),
                        Text('Room: ${p.room?.roomNumber ?? p.roomId} • Due: ${Formatters.formatDate(p.dueDate)}'),
                        if (p.receiptUrl != null) ...[
                          const SizedBox(height: 8),
                          Text('Receipt: ${p.receiptUrl}', style: const TextStyle(color: Colors.blue)),
                        ],
                        if (p.status == PaymentStatus.pending) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Confirm as Paid'),
                              onPressed: () async {
                                await _paymentService.updatePaymentStatus(
                                  paymentId: p.paymentId,
                                  status: PaymentStatus.paid,
                                );
                                _loadPayments();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: COMPLAINTS MANAGEMENT
// -----------------------------------------------------------------------------
class _OwnerComplaintsTab extends StatefulWidget {
  final UserModel user;
  const _OwnerComplaintsTab({required this.user});

  @override
  State<_OwnerComplaintsTab> createState() => _OwnerComplaintsTabState();
}

class _OwnerComplaintsTabState extends State<_OwnerComplaintsTab> {
  final _complaintService = ComplaintService();
  late Future<List<ComplaintModel>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  void _loadComplaints() {
    setState(() {
      _complaintsFuture = _complaintService.getComplaintsForOwner(widget.user.userId);
    });
  }

  void _showRespondDialog(ComplaintModel complaint) {
    final responseCtrl = TextEditingController(text: complaint.response ?? '');
    ComplaintStatus status = complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.inProgress
        : complaint.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Respond to: ${complaint.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ComplaintStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ComplaintStatus.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: responseCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Response to Tenant',
                  hintText: 'e.g. Technician scheduled for tomorrow...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.respondToComplaint(
                    complaintId: complaint.complaintId,
                    responseText: responseCtrl.text,
                    status: status,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _loadComplaints();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save Response'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Complaints')),
      body: RefreshIndicator(
        onRefresh: () async => _loadComplaints(),
        child: FutureBuilder<List<ComplaintModel>>(
          future: _complaintsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('No complaints submitted by tenants.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final c = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              c.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Chip(label: Text(c.status.displayName)),
                          ],
                        ),
                        Text('By: ${c.user?.name ?? "User #${c.userId}"} • Priority: ${c.priority.displayName}'),
                        const SizedBox(height: 6),
                        Text(c.description),
                        if (c.response != null) ...[
                          const SizedBox(height: 6),
                          Text('My Response: ${c.response}', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.reply, size: 18),
                            label: const Text('Respond / Update'),
                            onPressed: () => _showRespondDialog(c),
                          ),
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
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 5: OWNER PROFILE
// -----------------------------------------------------------------------------
class _OwnerProfileTab extends StatelessWidget {
  final UserModel user;
  const _OwnerProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF1E3A8A),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'O',
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 6),
            const Chip(label: Text('Role: OWNER')),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone Number'),
              subtitle: Text(user.phone),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              onPressed: () async {
                await AuthService().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
