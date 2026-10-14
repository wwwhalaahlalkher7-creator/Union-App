part of 'materials_screen.dart';

class PdfMaterialViewerScreen extends StatefulWidget {
  const PdfMaterialViewerScreen({
    required this.title,
    required this.materialId,
    required this.url,
    required this.accessToken,
    super.key,
  });

  final String title;
  final String materialId;
  final Uri url;
  final String accessToken;

  @override
  State<PdfMaterialViewerScreen> createState() => _PdfMaterialViewerScreenState();
}

class _PdfMaterialViewerScreenState extends State<PdfMaterialViewerScreen> {
  Timer? _progressTimer;
  File? _localPdf;
  int _currentPage = 1;
  int _pageCount = 0;
  int _displayedProgress = 0;
  bool _loadingFile = true;
  Object? _loadError;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadPdfToDisk();
  }

  Future<void> _loadPdfToDisk() async {
    try {
      final directory = await getTemporaryDirectory();
      final safeId = widget.materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${directory.path}/trinex_material_$safeId.pdf');

      // Reuse a previously downloaded copy when it exists. The server remains
      // authoritative; the cache only avoids repeating a large download.
      if (!await file.exists() || await file.length() == 0) {
        final request = http.Request('GET', widget.url)
          ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
          ..headers['Accept'] = 'application/pdf';
        final response = await request.send().timeout(const Duration(minutes: 3));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('PDF download failed (${response.statusCode}).');
        }

        final sink = file.openWrite();
        try {
          await response.stream.pipe(sink);
        } catch (_) {
          await sink.close();
          if (await file.exists()) await file.delete();
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _localPdf = file;
        _loadingFile = false;
      });
      _startProgressTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingFile = false;
      });
    }
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    // The first progress/XP update is intentionally delayed until about one
    // minute of verified time in the material. After that, the current page is
    // periodically reported so the backend can accumulate active time and
    // award XP only for newly reached pages.
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _pageCount <= 0) return;
      _sendPageProgress();
    });
  }

  Future<void> _sendPageProgress() async {
    if (_pageCount <= 0 || _currentPage <= 0) return;
    try {
      final percent = (((_currentPage / _pageCount) * 100).round()).clamp(0, 100).toInt();
      if (mounted && percent > _displayedProgress) {
        setState(() => _displayedProgress = percent);
      }
      final update = await AppDependencies.instance.progress.record(
        materialId: widget.materialId,
        eventType: percent >= 100 ? 'complete' : 'progress',
        progressPercent: percent,
        pageNumber: _currentPage,
        pageCount: _pageCount,
      );
      if (mounted && update.accepted) {
        setState(() {
          _displayedProgress = [
            _displayedProgress,
            update.percent.clamp(0, 100),
          ].reduce((a, b) => a > b ? a : b);
        });
      }
    } catch (_) {
      // Progress is auxiliary; a temporary network failure must never close the PDF.
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _displayedProgress / 100),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
            ),
          ),
        ),
      ),
      body: _loadingFile
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null || _localPdf == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).t('openMaterialFailed'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loadingFile = true;
                              _loadError = null;
                            });
                            _loadPdfToDisk();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(AppLocalizations.of(context).t('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    PdfViewer.file(
                      _localPdf!.path,
                      controller: _pdfController,
                      useProgressiveLoading: true,
                      params: PdfViewerParams(
                        backgroundColor: cs.surfaceContainerHighest,
                        maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
                        verticalCacheExtent: 1.0,
                        onePassRenderingSizeThreshold: 1600,
                        onPageChanged: (pageNumber) {
                          if (pageNumber == null || !_pdfController.isReady) return;
                          final count = _pdfController.pageCount;
                          if (count <= 0) return;
                          if (mounted) {
                            setState(() {
                              _currentPage = pageNumber.clamp(1, count).toInt();
                              _pageCount = count;
                            });
                          }
                          _sendPageProgress();
                        },
                        linkHandlerParams: PdfLinkHandlerParams(
                          onLinkTap: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

}

