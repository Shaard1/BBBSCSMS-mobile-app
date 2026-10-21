import 'package:flutter/material.dart';

/// Confirms submission only; staff review and release remain separate steps.
class DocumentSubmittedDialog extends StatelessWidget {
  const DocumentSubmittedDialog(
      {super.key, required this.documentTitle, required this.onViewRequests});
  final String documentTitle;
  final VoidCallback onViewRequests;

  Widget _step(IconData icon, String title, String description) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: const Color(0xFF00549C))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Color(0xFF17324D))),
                const SizedBox(height: 4),
                Text(description,
                    style:
                        const TextStyle(color: Color(0xFF526274), height: 1.4)),
              ])),
        ]),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                        child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE9F6EE),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                size: 36, color: Color(0xFF237547)))),
                    const SizedBox(height: 16),
                    const Text('Request submitted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17324D))),
                    const SizedBox(height: 8),
                    const Text('Your request has been sent to the barangay.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF526274), height: 1.4)),
                    const SizedBox(height: 20),
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FB),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DOCUMENT REQUEST',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: Color(0xFF526274))),
                              const SizedBox(height: 6),
                              Text(documentTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Color(0xFF17324D))),
                              const SizedBox(height: 8),
                              const Text('Awaiting staff review',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF725000))),
                            ])),
                    const SizedBox(height: 16),
                    const Text('What happens next',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF17324D))),
                    _step(Icons.fact_check_outlined, 'Staff review',
                        'Staff will check your documents and any required authorization.'),
                    _step(Icons.location_on_outlined, 'Payment and pickup',
                        'Check Activity for updates and office instructions. Any applicable payment and document collection happen at the barangay office.'),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: onViewRequests,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00549C),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('View my requests',
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 10),
                    const Text('Submission does not mean approval.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF526274))),
                  ]),
            )),
      );
}

