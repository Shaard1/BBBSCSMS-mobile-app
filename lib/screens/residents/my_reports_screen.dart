import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_status_message.dart';
import '../../widgets/top_toast.dart';

/// This screen shows ONLY the reports
/// submitted by the currently logged-in resident.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  /* ---------------- VARIABLES ---------------- */

  final supabase = Supabase.instance.client;
  List reports = [];
  bool isLoading = true;
  bool _loadFailed = false;

  /* ---------------- INIT STATE ---------------- */

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  /* ---------------- FETCH REPORTS ---------------- */

  /// Fetch reports from Supabase
  /// Only fetch reports where user_id matches current logged-in user
  Future<void> fetchReports() async {
    final user = supabase.auth.currentUser;

    // If no user is logged in, stop execution
    if (user == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('reports')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _loadFailed = false;
        reports = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> deleteReport(String reportId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete report?"),
          content: const Text("Are you sure you want to remove this report?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await supabase
          .from('reports')
          .delete()
          .eq('id', reportId)
          .eq('user_id', user.id);

      if (!mounted) return;
      await fetchReports();
    } catch (_) {
      if (mounted) {
        TopToast.show(
            context, 'The report could not be deleted. Please try again.');
      }
    }
  }

  String _normalizedStatusLabel(String? value) {
    final status = (value ?? '').toLowerCase().trim();
    if (status == 'in_progress' || status == 'in progress') {
      return 'In Progress';
    }
    if (status == 'resolved' || status == 'completed') {
      return 'Resolved';
    }
    return 'Pending';
  }

  Color _statusColor(String label) {
    if (label == 'Resolved') return Colors.green;
    if (label == 'In Progress') return Colors.orange;
    return Colors.red;
  }

  /* ---------------- UI BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
      ),

      /* ---------------- BODY ---------------- */

      body: isLoading

          /* ---------------- LOADING STATE ---------------- */
          ? const Center(child: CircularProgressIndicator())

          /* ---------------- EMPTY STATE ---------------- */
          : RefreshIndicator(
              onRefresh: fetchReports,
              child: reports.isEmpty || _loadFailed
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                          AppStatusMessage(
                            message: _loadFailed
                                ? 'Reports could not be loaded.'
                                : 'No reports yet. Your submitted reports will appear here.',
                            icon: _loadFailed
                                ? Icons.cloud_off_rounded
                                : Icons.inbox_outlined,
                            onRetry: _loadFailed ? fetchReports : null,
                          ),
                        ])
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];

                        final description =
                            report['description'] ?? 'No Description';

                        final status = _normalizedStatusLabel(
                          report['status']?.toString(),
                        );
                        final reportId = report['id']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: ListTile(
                            trailing: reportId.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: "Delete report",
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => deleteReport(reportId),
                                  ),
                            /* ---------------- DESCRIPTION ---------------- */
                            title: Text(description),

                            /* ---------------- STATUS SECTION ---------------- */
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  "Status: $status",
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
