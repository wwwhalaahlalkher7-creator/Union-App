import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/widgets/animated_download_button.dart';

void main() {
  testWidgets('download action reports progress and invokes the callback', (tester) async {
    var phase = DownloadActionPhase.idle;
    var downloadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => AnimatedDownloadButton(
                phase: phase,
                progress: 0.45,
                downloadLabel: 'Download',
                viewLabel: 'View',
                successLabel: 'Done',
                retryLabel: 'Retry',
                tooltip: 'Download sheet',
                onDownload: () {
                  downloadCalls++;
                  setState(() => phase = DownloadActionPhase.downloading);
                },
                onView: () {},
                onSuccessAnimationComplete: () =>
                    setState(() => phase = DownloadActionPhase.view),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();

    expect(downloadCalls, 1);
    expect(find.text('45%'), findsOneWidget);
  });

  testWidgets('success state morphs into the local view action', (tester) async {
    var phase = DownloadActionPhase.success;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => AnimatedDownloadButton(
                phase: phase,
                progress: null,
                downloadLabel: 'Download',
                viewLabel: 'View',
                successLabel: 'Done',
                retryLabel: 'Retry',
                tooltip: 'Download sheet',
                onDownload: () {},
                onView: () {},
                onSuccessAnimationComplete: () =>
                    setState(() => phase = DownloadActionPhase.view),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 930));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });
}
