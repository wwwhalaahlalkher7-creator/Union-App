part of 'materials_screen.dart';

class PdfMaterialViewerScreen extends StatefulWidget {
  const PdfMaterialViewerScreen({
    required this.title,
    required this.materialId,
    required this.url,
    required this.accessToken,
    this.localFile,
    this.trackProgress = true,
    super.key,
  });

  final String title;
  final String materialId;
  final Uri? url;
  final String accessToken;
  final File? localFile;
  final bool trackProgress;

  @override
  State<PdfMaterialViewerScreen> createState() => _PdfMaterialViewerScreenState();
}

class _PdfMaterialViewerScreenState extends State<PdfMaterialViewerScreen> {
  Timer? _progressTimer;
  File? _localPdf;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _loadingFile = true;
  int _savedPageToRestore = 1;
  String? _lastPagePreferenceKey;
  bool _pageRestored = false;
  bool _progressSessionOpened = false;
  Object? _loadError;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadPdfToDisk();
  }

  Future<void> _loadPdfToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await AppDependencies.instance.authStorage.profile;
      final ownerKey = (profile?['studentId'] ?? profile?['studentNumber'] ?? 'guest')
          .toString()
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final safeMaterialId = widget.materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      _lastPagePreferenceKey = 'trinex_material_last_page_${ownerKey}_$safeMaterialId';
      _savedPageToRestore = prefs.getInt(_lastPagePreferenceKey!) ?? 1;
      File file;
      final providedLocalFile = widget.localFile;
      if (providedLocalFile != null &&
          await providedLocalFile.exists() &&
          await providedLocalFile.length() > 0) {
        file = providedLocalFile;
      } else {
        final url = widget.url;
        if (url == null) throw Exception('النسخة المحلية غير متاحة. أعد تنزيل الملف عند الاتصال بالإنترنت.');
        final directory = await getTemporaryDirectory();
        final safeId = widget.materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        file = File('${directory.path}/trinex_material_$safeId.pdf');

        // Reuse a previously downloaded copy when it exists. The server remains
        // authoritative; the cache only avoids repeating a large download.
        if (!await file.exists() || await file.length() == 0) {
          final request = http.Request('GET', url)
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
      }

      if (!mounted) return;
      setState(() {
        _localPdf = file;
        _loadingFile = false;
      });
      if (widget.trackProgress) _startProgressTracking();
      unawaited(_restoreLastPage());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingFile = false;
      });
    }
  }

  Future<void> _restoreLastPage() async {
    try {
      final savedPage = _savedPageToRestore;
      if (savedPage <= 1) {
        _pageRestored = true;
        return;
      }
      for (var attempt = 0; attempt < 40; attempt++) {
        if (!mounted) return;
        if (_pdfController.isReady && _pdfController.pageCount > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted || !_pdfController.isReady || _pdfController.pageCount <= 0) return;
      final target = savedPage.clamp(1, _pdfController.pageCount).toInt();
      _pdfController.goToPage(pageNumber: target);
      _pageRestored = true;
    } catch (_) {
      // Page restoration is best-effort; it must never prevent opening the PDF.
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
    if (!widget.trackProgress ||
        _pageCount <= 0 ||
        _currentPage <= 0 ||
        widget.url == null ||
        widget.accessToken.isEmpty) {
      return;
    }
    try {
      // Opening a downloaded file offline may not have created the server-side
      // progress row. Retry the open event once connectivity returns before
      // sending page/XP progress, which requires that row to exist.
      if (!_progressSessionOpened) {
        await AppDependencies.instance.progress.record(
          materialId: widget.materialId,
          eventType: 'open',
        );
        _progressSessionOpened = true;
        return;
      }
      final percent = (((_currentPage / _pageCount) * 100).round()).clamp(0, 100).toInt();
      await AppDependencies.instance.progress.record(
        materialId: widget.materialId,
        eventType: percent >= 100 ? 'complete' : 'progress',
        progressPercent: percent,
        pageNumber: _currentPage,
        pageCount: _pageCount,
      );
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
        bottom: widget.trackProgress
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _pageCount > 0
                      ? (_currentPage / _pageCount).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 4,
                ),
              )
            : null,
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
                          if (!_pageRestored && _savedPageToRestore > 1 && pageNumber == 1) return;
                          _pageRestored = true;
                          final nextPage = pageNumber.clamp(1, count).toInt();
                          if (mounted) {
                            setState(() {
                              _currentPage = nextPage;
                              _pageCount = count;
                            });
                          }
                          final preferenceKey = _lastPagePreferenceKey;
                          if (preferenceKey != null) {
                            unawaited(SharedPreferences.getInstance().then<void>((prefs) async {
                              await prefs.setInt(preferenceKey, nextPage);
                            }));
                          }
                          if (widget.trackProgress) _sendPageProgress();
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

