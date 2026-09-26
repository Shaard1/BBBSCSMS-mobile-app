import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared by startup and profile loading to avoid a second, unrelated loader.
class AppLaunchView extends StatelessWidget {
  const AppLaunchView({super.key, this.errorMessage, this.onRetry});

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'lib/assets/bancao-connect-mark.svg',
                      width: 88,
                      height: 88,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: 20),
                    Text('BancaoConnect',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.publicSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: Color(0xFF006CBF),
                        )),
                    const SizedBox(height: 8),
                    const Text('Your community, connected.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 36),
                    Image.asset('lib/assets/barangay-seal.png',
                        width: 76,
                        height: 76,
                        semanticLabel: 'Barangay Bancao-Bancao seal'),
                    const SizedBox(height: 8),
                    const Text('BARANGAY BANCAO-BANCAO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 36),
                    if (errorMessage == null) ...[
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: reduceMotion
                            ? const Icon(Icons.hourglass_empty_rounded,
                                size: 22, color: Color(0xFF006CBF))
                            : const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text('Getting things ready…',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 13)),
                      ),
                    ] else ...[
                      Semantics(
                          liveRegion: true,
                          child:
                              Text(errorMessage!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
