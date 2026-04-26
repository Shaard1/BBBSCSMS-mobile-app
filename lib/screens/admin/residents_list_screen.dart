import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_resident_screen.dart';

class ResidentsListScreen extends StatefulWidget {
  const ResidentsListScreen({super.key});

  @override
  State<ResidentsListScreen> createState() => _ResidentsListScreenState();
}

class _ResidentsListScreenState extends State<ResidentsListScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> residents = [];
  bool isLoading = true;
  String? userRole;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  /* ---------------- INITIAL LOAD ---------------- */

  Future<void> initializeData() async {
    await fetchUserRole();
    await fetchResidents();
  }

  /* ---------------- FETCH USER ROLE ---------------- */

  Future<void> fetchUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        userRole = data['role'];
      });
    } catch (e) {
      debugPrint("ROLE ERROR: $e");
    }
  }

  /* ---------------- FETCH RESIDENTS ---------------- */

  Future<void> fetchResidents() async {
    try {
      final data = await supabase
          .from('residents')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        residents = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading residents: $e')));
    }
  }

  /* ---------------- DELETE ---------------- */

  Future<void> deleteResident(String id) async {
    if (userRole != 'admin') return;

    try {
      await supabase.from('residents').delete().eq('id', id);

      setState(() {
        residents.removeWhere((resident) => resident['id'] == id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  /* ---------------- UPDATE STATUS ---------------- */

  Future<void> updateStatus(String id, String newStatus) async {
    if (userRole != 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can approve/reject')),
      );
      return;
    }

    try {
      await supabase.from('residents').update({
        'status': newStatus,
        'approved_by': supabase.auth.currentUser?.id,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      setState(() {
        final index = residents.indexWhere((r) => r['id'] == id);
        if (index != -1) {
          residents[index]['status'] = newStatus;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Permission denied or error: $e')));
    }
  }

  /* ---------------- STATUS BADGE ---------------- */

  Widget buildStatusBadge(String status) {
    Color color;

    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Residents'),
        centerTitle: true,
        actions: [
          if (userRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  userRole!.toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : residents.isEmpty
              ? const Center(child: Text('No residents found.'))
              : RefreshIndicator(
                  onRefresh: fetchResidents,
                  child: ListView.builder(
                    itemCount: residents.length,
                    itemBuilder: (context, index) {
                      final resident = residents[index];
                      final status = resident['status'] ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            resident['full_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Address: ${resident['address'] ?? ''}"),
                              Text(
                                  "Contact: ${resident['contact_number'] ?? ''}"),
                              const SizedBox(height: 6),
                              buildStatusBadge(status),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'approve') {
                                updateStatus(resident['id'], 'approved');
                              } else if (value == 'reject') {
                                updateStatus(resident['id'], 'rejected');
                              } else if (value == 'delete') {
                                deleteResident(resident['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              if (status == 'pending' && userRole == 'admin')
                                const PopupMenuItem(
                                  value: 'approve',
                                  child: Text('Approve'),
                                ),
                              if (status == 'pending' && userRole == 'admin')
                                const PopupMenuItem(
                                  value: 'reject',
                                  child: Text('Reject'),
                                ),
                              if (userRole == 'admin')
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final newResident = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddResidentScreen()),
          );

          if (newResident != null) {
            setState(() {
              residents.insert(0, newResident);
            });
          }
        },
      ),
    );
  }
}
