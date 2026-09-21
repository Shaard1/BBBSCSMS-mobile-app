import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /* ---------------- VARIABLES ---------------- */

  final supabase = Supabase.instance.client;
  List reports = [];
  bool isLoading = true;

  /* ---------------- INIT STATE ---------------- */

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  /* ---------------- FETCH REPORTS ---------------- */

  Future<void> fetchReports() async {
    try {
      final response = await supabase
          .from('reports')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        reports = response;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  /* ---------------- UPDATE STATUS ---------------- */

  Future<void> updateStatus(String id, String status) async {
    try {
      await supabase.from('reports').update({'status': status}).eq('id', id);
      await fetchReports();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update report status.')),
      );
    }
  }

  /* ---------------- UI BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /* ---------------- DESCRIPTION ---------------- */

                        Text(
                          report['description'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        /* ---------------- IMAGE ---------------- */

                        if (report['image_url'] != null)
                          Image.network(report['image_url']),
                        const SizedBox(height: 8),

                        /* ---------------- STATUS ---------------- */

                        Text("Status: ${report['status']}"),
                        const SizedBox(height: 8),

                        /* ---------------- ACTION BUTTONS ---------------- */

                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  updateStatus(report['id'], 'in_process'),
                              child: const Text("In Process"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () =>
                                  updateStatus(report['id'], 'completed'),
                              child: const Text("Completed"),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
