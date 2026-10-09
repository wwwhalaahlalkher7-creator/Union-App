import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:record/record.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../data/repositories/eino_repository.dart';
import '../../core/di/app_dependencies.dart';
import 'eino_face.dart';
import 'services/eino_local_model_service.dart';
import 'eino_widgets.dart';

class EinoScreen extends StatefulWidget {
  const EinoScreen({super.key, this.source = 'home'});
  final String source;

  @override
  State<EinoScreen> createState() => _EinoScreenState();
}

class _EinoScreenState extends State<EinoScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _localStore = EinoLocalModelStore();
  final _localEngine = EinoLocalEngine();
  EinoLocalModel? _loadedLocalModel;
  late EinoRepository _repository;
  bool _ready = false;
  bool _sending = false;
  bool _recording = false;
  bool _uploading = false;
  bool _readerActive = false;
  bool _readerPaused = false;
  EinoCapabilities? _capabilities;
  bool _loadingCapabilities = false;
  final List<EinoMessage> _messages = [];
  final List<EinoConversation> _history = [];
  String? _conversationId;

  EinoMood get _mood => _recording || _sending || _uploading
      ? EinoMood.thinking
      : _messages.any((m) => m.isError)
          ? EinoMood.concerned
          : _messages.any((m) => !m.user && !m.isError)
              ? EinoMood.happy
              : EinoMood.idle;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _repository = AppDependencies.instance.eino;
    if (mounted) setState(() => _ready = true);
    await _showEinoDataNoticeIfNeeded();
    await Future.wait([_loadCapabilities(), _loadHistory()]);
  }

  Future<void> _showEinoDataNoticeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('eino_data_notice_seen_v1') == true || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تنبيه الخصوصية وتحسين Eino'),
          content: const Text(
            'لتحليل أداء Eino وتطويره وتحسين المزودات، نستخدم بعض البيانات التشغيلية عند استخدامه، مثل نوع الطلب، المزود والنموذج المستخدمين، زمن الاستجابة، حالة النجاح أو الخطأ، واستهلاك وحدات الاستخدام.\n\nلا يتم وضع نصوص محادثاتك أو أرقام الطلاب أو عناوين IP أو محتوى ملفاتك داخل لوحة مراقبة Eino، وسجل المراقبة التشغيلي محدود المدة.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('فهمت، متابعة'),
            ),
          ],
        ),
      ),
    );
    await prefs.setBool('eino_data_notice_seen_v1', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _player.dispose();
    _localEngine.dispose();
    super.dispose();
  }

  String _sourceLabel(AppLocalizations l10n) {
    switch (widget.source) {
      case 'materials': return l10n.t('sourceMaterials');
      case 'schedule': return l10n.t('sourceSchedule');
      case 'progress': return l10n.t('sourceProgress');
      case 'xp': return l10n.t('sourceXp');
      case 'badges': return l10n.t('sourceBadges');
      case 'student': return l10n.t('sourceStudent');
      default: return l10n.t('sourceHome');
    }
  }


  // Create a short, topic-oriented title from the first user question rather than
  // storing the whole first message verbatim. Assistant replies never influence it.
  String _conversationTitle(String question) {
    var value = einoPlainText(question).replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value.replaceFirst(RegExp(r'^(?:من فضلك\s+|لو سمحت\s+|ممكن\s+|هل يمكنك\s+|أريد منك\s+|عايزك\s+|اشرح لي\s+|اشرح\s+|حل لي\s+|حل\s+|ما هو\s+|ما هي\s+|كيف يمكنني\s+)', caseSensitive: false), '');
    value = value.replaceAll(RegExp(r'[؟?!。，،؛:]+$'), '').trim();
    if (value.isEmpty) value = einoPlainText(question).trim();
    final words = value.split(RegExp(r'\s+'));
    if (words.length > 7) value = '${words.take(7).join(' ')}…';
    if (value.length > 52) value = '${value.substring(0, 49).trimRight()}…';
    return value.isEmpty ? 'محادثة جديدة' : value;
  }

  Future<void> _send() async {
    if (!_ready || _sending || _uploading) return;
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    if (_conversationId == null && await AppDependencies.instance.authStorage.isLoggedIn) {
      try {
        _conversationId = await _repository.createConversation(title: _conversationTitle(prompt));
        await _loadHistory();
      } catch (_) {
        // The chat endpoint can still create the conversation server-side.
      }
    }
    setState(() {
      _messages.add(EinoMessage(true, prompt));
      _sending = true;
    });
    _scrollToBottom();
    await _requestAnswer(prompt);
  }

  Future<void> _loadHistory() async {
    try {
      if (!await AppDependencies.instance.authStorage.isLoggedIn) return;
      final chats = await _repository.conversations(limit: 30);
      if (mounted) setState(() { _history..clear()..addAll(chats); });
    } catch (_) {}
  }

  Future<void> _openConversation(EinoConversation conversation) async {
    if (_sending || _uploading) return;
    try {
      final detail = await _repository.conversation(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversationId = conversation.id;
        _messages..clear()..addAll(detail.messages.map((m) => EinoMessage(m.user, m.content)));
      });
      Navigator.of(context).pop();
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'))));
    }
  }

  Future<void> _retry(String prompt) async {
    if (!_ready || _sending || prompt.trim().isEmpty) return;
    setState(() {
      final index = _messages.lastIndexWhere((m) => m.isError && m.retryPrompt == prompt);
      if (index >= 0) _messages.removeAt(index);
      _sending = true;
    });
    await _requestAnswer(prompt);
  }

  Future<void> _requestAnswer(String prompt) async {
    try {
      final l10n = AppLocalizations.of(context);
      final history = _messages.length > 10 ? _messages.sublist(_messages.length - 10) : List<EinoMessage>.from(_messages);
      final historyText = history.where((m) => !m.isError && m.text != prompt).map((m) => '${m.user ? 'المستخدم' : 'إينو'}: ${m.text}').join('\n');
      final contextPayload = ['صفحة المستخدم الحالية: ${_sourceLabel(l10n)}.', if (_conversationId == null && historyText.isNotEmpty) 'سياق المحادثة السابق:\n$historyText'].join('\n');
      try {
        final response = await _repository.chat(prompt: prompt, context: contextPayload, conversationId: _conversationId);
        _conversationId ??= response.conversationId;
        if (mounted) {
          setState(() => _messages.add(EinoMessage(false, response.message, sourceTitle: response.sources.isNotEmpty ? response.sources.first.title : null)));
          await _loadHistory();
        }
      } catch (onlineError) {
        final local = _loadedLocalModel;
        if (local != null && _localEngine.isLoaded) {
          try {
            final chunks = <String>[];
            await for (final chunk in _localEngine.generateChat(
              systemPrompt: 'أنت Eino، مساعد TRINEX المحلي. أجب بالعربية بوضوح، ولا تدّعِ الوصول إلى بيانات الإنترنت أو بيانات التطبيق ما لم تُعطَ لك في السياق.\n$contextPayload',
              prompt: prompt,
            )) {
              chunks.add(chunk);
            }
            final answer = chunks.join().trim();
            if (mounted) setState(() => _messages.add(EinoMessage(false, answer.isEmpty ? ErrorMessage.from(context, onlineError, fallbackKey: 'einoGenericError') : answer)));
          } catch (localError) {
            if (mounted) setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, localError, fallbackKey: 'einoGenericError'), isError: true, retryPrompt: prompt)));
          }
        } else if (mounted) {
          setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, onlineError, fallbackKey: 'einoGenericError'), isError: true, retryPrompt: prompt)));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'), isError: true, retryPrompt: prompt)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _pickMedia() async {
    if (_sending || _uploading) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('توليد صورة'), subtitle: const Text('أنشئ صورة جديدة من وصفك'), onTap: () => Navigator.pop(context, 'generate')),
          ListTile(leading: const Icon(Icons.image_outlined), title: Text(l10n.t('einoAttachImage')), subtitle: Text(l10n.t('einoVisionSubtitle')), onTap: () => Navigator.pop(context, 'image')),
          ListTile(leading: const Icon(Icons.description_outlined), title: Text(l10n.t('einoAttachDocument')), subtitle: Text(l10n.t('einoDocumentSubtitle')), onTap: () => Navigator.pop(context, 'document')),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'generate') {
      await _generateImage();
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true, type: choice == 'image' ? FileType.image : FileType.custom, allowedExtensions: choice == 'document' ? ['pdf', 'docx', 'txt', 'md', 'csv', 'xlsx', 'pptx'] : null);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('einoFileTooLarge'))),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      final name = file.name;
      if (_conversationId == null && await AppDependencies.instance.authStorage.isLoggedIn) {
        _conversationId = await _repository.createConversation(title: name);
        await _loadHistory();
      }
      if (choice == 'image') {
        final prompt = await _askImagePrompt();
        if (!mounted || prompt == null) return;
        final mime = _mime(name);
        final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        final text = await _repository.imageAnalysis(
          imageDataUrl: dataUrl,
          prompt: prompt,
          conversationId: _conversationId,
          attachmentName: name,
        );
        if (mounted) {
          setState(() {
            _messages.add(EinoMessage(true, '🖼️ $name\n$prompt'));
            _messages.add(EinoMessage(false, text));
          });
        }
        if (_conversationId != null) await _loadHistory();
      } else {
        final text = await _repository.fileAnalysis(
          bytes: bytes,
          filename: name,
          contentType: _mime(name),
          conversationId: _conversationId,
          prompt: 'حلل هذا الملف بدقة، استخرج أهم المعلومات منه، ثم قدم ملخصًا واضحًا ومنظمًا بالعربية. إذا كان الملف أكاديميًا، ركز على المفاهيم والقوانين والنقاط المهمة للمذاكرة ولا تضف معلومات غير موجودة فيه.',
        );
        if (mounted) {
          setState(() {
            _messages.add(EinoMessage(true, '📄 $name'));
            _messages.add(EinoMessage(false, text));
          });
        }
        if (_conversationId != null) await _loadHistory();
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'), isError: true)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _generateImage() async {
    final prompt = await _askImageGenerationPrompt();
    if (!mounted || prompt == null || prompt.trim().isEmpty) return;
    if (_conversationId == null && await AppDependencies.instance.authStorage.isLoggedIn) {
      _conversationId = await _repository.createConversation(title: 'توليد صورة: ${prompt.length > 55 ? '${prompt.substring(0, 55)}…' : prompt}');
      await _loadHistory();
    }
    setState(() => _uploading = true);
    try {
      final result = await _repository.generateImage(prompt: prompt);
      if (!mounted) return;
      setState(() {
        _messages.add(EinoMessage(true, '🎨 $prompt'));
        _messages.add(EinoMessage(false, 'تم إنشاء الصورة بناءً على وصفك.', imageBase64: result.base64, imageContentType: result.contentType));
      });
      if (_conversationId != null) {
        await _repository.appendConversationMessage(conversationId: _conversationId!, user: true, content: '🎨 $prompt');
        await _repository.appendConversationMessage(conversationId: _conversationId!, user: false, content: 'تم إنشاء صورة بواسطة Eino.');
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'), isError: true, retryPrompt: prompt)));
    } finally {
      if (mounted) setState(() => _uploading = false);
      _scrollToBottom();
    }
  }

  Future<String?> _askImageGenerationPrompt() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('توليد صورة'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'اكتب وصف الصورة التي تريدها…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('توليد')),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _askImagePrompt() async {
    final controller = TextEditingController(text: 'حلل هذه الصورة بدقة، واقرأ النصوص والمخططات والعناصر المهمة فيها. إذا كانت أكاديمية فاشرح ما يظهر فيها دون اختلاق معلومات.');
    final prompt = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ماذا تريد من Eino أن تفعل بالصورة؟'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 7,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'مثال: اشرح السؤال الموجود في الصورة خطوة بخطوة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('تحليل')),
        ],
      ),
    );
    controller.dispose();
    if (prompt == null || prompt.trim().isEmpty) return null;
    return prompt.trim();
  }

  String _mime(String name) {
    switch (name.toLowerCase().split('.').last) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'pdf': return 'application/pdf';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      case 'm4a': return 'audio/mp4';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _toggleRecording() async {
    if (_sending || _uploading) return;
    if (_recording) {
      final locale = Localizations.localeOf(context).languageCode;
      final path = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
      if (path == null) return;
      setState(() => _uploading = true);
      try {
        final file = File(path);
        final language = const {'ar', 'en', 'fr'}.contains(locale) ? locale : 'ar';
        final text = await _repository.stt(bytes: await file.readAsBytes(), filename: 'eino_recording.m4a', contentType: 'audio/mp4', language: language);
        if (text.trim().isNotEmpty) {
          _controller.text = text.trim();
          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        }
      } catch (e) {
        if (mounted) setState(() => _messages.add(EinoMessage(false, ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'), isError: true)));
      } finally {
        if (mounted) setState(() => _uploading = false);
        try { await File(path).delete(); } catch (_) {}
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('einoMicPermission'))));
      return;
    }
    final path = '${Directory.systemTemp.path}/eino_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _copyMessage(EinoMessage message) async {
    if (message.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: einoPlainText(message.text)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).t('copied'))),
    );
  }

  Future<void> _speak(EinoMessage message) async {
    if (message.user || message.text.trim().isEmpty) return;
    try {
      await _player.stop();
      if (mounted) setState(() { _readerActive = true; _readerPaused = false; });
      for (final chunk in _ttsChunks(einoPlainText(message.text, forSpeech: true))) {
        if (!mounted) return;
        final audio = await _repository.tts(text: chunk);
        if (audio == null) continue;
        // Subscribe before starting playback so short clips cannot finish before
        // the completion listener is attached.
        final completed = _player.onPlayerComplete.first;
        if (audio.base64 != null && audio.base64!.isNotEmpty) {
          await _player.play(BytesSource(base64Decode(audio.base64!)));
        } else if (audio.url != null && audio.url!.isNotEmpty) {
          await _player.play(UrlSource(audio.url!));
        } else {
          continue;
        }
        await completed;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'))));
    } finally {
      if (mounted) setState(() { _readerActive = false; _readerPaused = false; });
    }
  }

  Future<void> _toggleReaderPlayback() async {
    if (!_readerActive) return;
    if (_readerPaused) {
      await _player.resume();
      if (mounted) setState(() => _readerPaused = false);
    } else {
      await _player.pause();
      if (mounted) setState(() => _readerPaused = true);
    }
  }

  List<String> _ttsChunks(String value) {
    final clean = value
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[*_#`>]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return const [];
    final chunks = <String>[];
    var remaining = clean;
    while (remaining.length > 190) {
      var cut = remaining.lastIndexOf(RegExp(r'[.!?؟،؛]'), 190);
      if (cut < 100) cut = remaining.lastIndexOf(' ', 190);
      if (cut < 1) cut = 190;
      chunks.add(remaining.substring(0, cut + (remaining[cut] == ' ' ? 0 : 1)).trim());
      remaining = remaining.substring(cut + 1).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  void _newChat({bool closeDrawer = false}) {
    if (_sending || _uploading) return;
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
    if (closeDrawer && mounted) Navigator.of(context).pop();
  }


  Future<void> _loadCapabilities() async {
    if (!_ready || _loadingCapabilities) return;
    setState(() => _loadingCapabilities = true);
    try {
      final capabilities = await _repository.capabilities();
      if (mounted) setState(() => _capabilities = capabilities);
    } catch (_) {
      if (mounted) setState(() => _capabilities = null);
    } finally {
      if (mounted) setState(() => _loadingCapabilities = false);
    }
  }

  Future<void> _showModelManager() async {
    if (!_ready) return;
    final l10n = AppLocalizations.of(context);
    List<EinoLocalModel> models;
    try {
      models = await _repository.models();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'))));
      return;
    }
    if (!mounted) return;
    final store = EinoLocalModelStore();
    final downloader = EinoLocalModelDownloader(store);
    final installed = <String>{...(await store.installedIds())};
    GpuInfo? hardware;
    if (!kIsWeb && Platform.isAndroid) {
      try { hardware = await _localEngine.detectHardware(); } catch (_) {}
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(builder: (context, setSheetState) {
          Future<void> handleModel(EinoLocalModel model) async {
            final messenger = ScaffoldMessenger.of(context);
            final url = model.downloadUrl;
            if (url == null || url.trim().isEmpty) {
              messenger.showSnackBar(SnackBar(content: Text(l10n.t('einoModelSourcePending'))));
              return;
            }
            if (hardware != null && hardware.freeRamBytes > 0 && hardware.freeRamBytes < model.recommendedRamGb * 1024 * 1024 * 1024) {
              messenger.showSnackBar(SnackBar(content: Text(l10n.t('einoModelRamWarning'))));
              return;
            }
            try {
              if (installed.contains(model.id)) {
                final valid = await _localStore.verifyIntegrity(model);
                if (!valid) {
                  await _localStore.remove(model);
                  installed.remove(model.id);
                  setSheetState(() {});
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(l10n.t('einoModelIntegrityFailed'))),
                  );
                  return;
                }
                final file = await _localStore.fileFor(model);
                await _localEngine.load(model, file);
                _loadedLocalModel = model;
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(l10n.t('einoModelLoaded'))),
                );
                return;
              }
              final progressNotifier = ValueNotifier<double>(0);
              final dialogFuture = showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.t('einoModelDownloading')),
                  content: ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (context, progress, child) => Column(mainAxisSize: MainAxisSize.min, children: [
                      LinearProgressIndicator(value: progress == 0 ? null : progress),
                      const SizedBox(height: 12),
                      Text('${(progress * 100).toStringAsFixed(0)}%'),
                    ]),
                  ),
                ),
              );
              try {
                final file = await downloader.download(model, url: url, sha256: model.sha256, onProgress: (value) {
                  progressNotifier.value = value.progress.clamp(0, 1);
                });
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                await dialogFuture;
                progressNotifier.dispose();
                installed.add(model.id);
                setSheetState(() {});
                await _localEngine.load(model, file);
                _loadedLocalModel = model;
                if (mounted) setState(() {});
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(l10n.t('einoModelLoaded'))));
              } catch (e) {
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                await dialogFuture.catchError((_) {});
                progressNotifier.dispose();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(ErrorMessage.from(this.context, e, fallbackKey: 'einoGenericError'))),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(ErrorMessage.from(this.context, e, fallbackKey: 'einoGenericError'))),
                );
              }
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14.72, 3.68, 14.72, 18.4),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l10n.t('einoModelsTitle'), style: const TextStyle(fontSize: 20.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(l10n.t('einoModelsSubtitle'), style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(11.04), decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .7), borderRadius: BorderRadius.circular(14.4)), child: Row(children: [
                  Icon(Icons.offline_bolt_rounded, color: cs.primary), const SizedBox(width: 10),
                  Expanded(child: Text(hardware == null ? l10n.t('einoModelAndroidOnly') : '${l10n.t('einoModelHardwareReady')} • ${hardware.gpuName}')),
                ])),
                const SizedBox(height: 12),
                Flexible(child: ListView.separated(shrinkWrap: true, itemCount: models.length, separatorBuilder: (context, index) => const SizedBox(height: 8), itemBuilder: (_, index) {
                  final model = models[index];
                  final isInstalled = installed.contains(model.id);
                  return Container(padding: const EdgeInsets.all(11.04), decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)), borderRadius: BorderRadius.circular(16.2)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const CircleAvatar(child: Icon(Icons.memory_rounded)), const SizedBox(width: 10), Expanded(child: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(model.quantization, style: TextStyle(fontSize: 10.1, color: cs.onSurfaceVariant))]),
                    const SizedBox(height: 8),
                    Text('${model.approximateSizeGb.toStringAsFixed(1)} GB  •  ${l10n.t('einoRam')} ${model.recommendedRamGb} GB  •  ${model.format}'),
                    const SizedBox(height: 6), Text(model.capabilities.join(' • '), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: () => handleModel(model), icon: Icon(isInstalled ? Icons.play_arrow_rounded : Icons.download_outlined), label: Text(isInstalled ? l10n.t('einoModelUse') : l10n.t('einoModelDownload')))),
                    if (_loadedLocalModel?.id == model.id) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await _localEngine.benchmark();
                            if (!mounted) return;
                            final text = l10n.t('einoModelBenchmarkResult')
                                .replaceAll('{speed}', result.tokensPerSecond.toStringAsFixed(1))
                                .replaceAll('{first}', result.firstTokenMs.toString());
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(text)));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(this.context, e, fallbackKey: 'einoGenericError'))));
                          }
                        },
                        icon: const Icon(Icons.speed_rounded),
                        label: Text(l10n.t('einoModelBenchmark')),
                      ),
                    ],
                  ]));
                })),
              ]),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      drawer: _drawer(cs, l10n),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu_rounded), tooltip: l10n.t('einoHistory'), onPressed: () => Scaffold.of(context).openDrawer())),
        titleSpacing: 4,
        title: Row(children: [EinoFace(size: 32, mood: _mood), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.t('einoTitle'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(_capabilities?.online == true ? l10n.t('einoOnlineReady') : l10n.t('einoOfflineMode'), style: TextStyle(fontSize: 10.1, color: _capabilities?.online == true ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w700))])]),
        actions: [IconButton(tooltip: l10n.t('newChat'), onPressed: _messages.isEmpty || _sending || _uploading ? null : _newChat, icon: const Icon(Icons.edit_square)), const SizedBox(width: 4)],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty ? _welcome(cs, l10n) : ListView.builder(controller: _scroll, padding: const EdgeInsetsDirectional.fromSTEB(12.88, 11.04, 12.88, 22.08), itemCount: _messages.length + (_sending || _uploading ? 1 : 0), itemBuilder: (_, i) {
          if (i == _messages.length) return _typingBubble(cs, uploading: _uploading);
          final message = _messages[i];
          return EinoAnimatedEntry(key: ValueKey('${message.text}-$i'), child: _bubble(context, message));
        })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(9.2, 3.68, 9.2, 9.2), child: _composer(cs, l10n))),
      ]),
    );
  }

  Widget _drawer(ColorScheme cs, AppLocalizations l10n) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16.56, 16.56, 16.56, 11.04),
              child: Row(
                children: [
                  const EinoFace(size: 48, mood: EinoMood.happy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.t('einoHistory'),
                      style: const TextStyle(
                        fontSize: 18.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.04),
              child: FilledButton.icon(
                onPressed: () => _newChat(closeDrawer: true),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.t('newChat')),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.offline_bolt_rounded),
              title: Text(l10n.t('einoModelsTitle')),
              subtitle: Text(l10n.t('einoModelDownload')),
              onTap: () { Navigator.of(context).pop(); _showModelManager(); },
            ),
            const Divider(height: 1),
            const SizedBox(height: 6),
            if (_history.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.t('einoNoHistory'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 7.36),
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    title: Text(
                      _history[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openConversation(_history[i]),
                    trailing: IconButton(
                      tooltip: l10n.t('delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        try {
                          await _repository.deleteConversation(_history[i].id);
                          if (!mounted) return;
                          setState(() {
                            if (_conversationId == _history[i].id) { _conversationId = null; _messages.clear(); }
                            _history.removeAt(i);
                          });
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'einoGenericError'))));
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ColorScheme cs, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16.56, 20.24, 16.56, 18.4),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(14.72),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: .45),
              shape: BoxShape.circle,
            ),
            child: EinoFace(size: 116, mood: _mood),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.t('einoGreeting'),
            style: const TextStyle(fontSize: 25.8, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.t('withYou', {'section': _sourceLabel(l10n)}),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t('einoWelcome'),
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, EinoMessage m) {
    final cs = Theme.of(context).colorScheme;

    if (m.isError) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsetsDirectional.fromSTEB(12.88, 11.96, 11.04, 8.28),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomLeft: const Radius.circular(5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EinoFace(size: 34, mood: EinoMood.error),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      m.text,
                      style: TextStyle(color: cs.onErrorContainer, height: 1.45),
                    ),
                  ),
                ],
              ),
              if (m.retryPrompt != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _sending ? null : () => _retry(m.retryPrompt!),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(AppLocalizations.of(context).t('einoRetry')),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: m.user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: m.user
            ? const EdgeInsets.symmetric(horizontal: 13.8, vertical: 11.04)
            : const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: m.user
            ? BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: const Radius.circular(5),
                ),
              )
            : const BoxDecoration(),
        child: m.user
            ? Text(
                m.text,
                style: TextStyle(color: cs.onPrimary, height: 1.5),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EinoFace(size: 31, mood: EinoMood.happy),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.imageBase64 != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(base64Decode(m.imageBase64!), fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 8),
                            ],
                            EinoMathText(
                              m.text,
                              style: const TextStyle(height: 1.55),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (m.sourceTitle != null && m.sourceTitle!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 40, top: 6, bottom: 2),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public_outlined, size: 15, color: cs.primary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'المصدر: ${m.sourceTitle}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: cs.primary, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: AppLocalizations.of(context).t('copy'),
                        onPressed: () => _copyMessage(m),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                      IconButton(
                        onPressed: () => _speak(m),
                        tooltip: AppLocalizations.of(context).t('einoListen'),
                        icon: const Icon(Icons.volume_up_outlined, size: 19),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _typingBubble(ColorScheme cs, {required bool uploading}) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14.72, vertical: 12.88),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: const Radius.circular(5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EinoFace(size: 30, mood: EinoMood.thinking),
            const SizedBox(width: 9),
            uploading
                ? Text(
                    AppLocalizations.of(context).t('einoProcessing'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                : EinoTypingDots(color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _composer(ColorScheme cs, AppLocalizations l10n) {
    final hasText = _controller.text.trim().isNotEmpty;
    final busy = _sending || _uploading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_readerActive)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Icon(Icons.volume_up_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Eino تقرأ الإجابة…', maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(tooltip: _readerPaused ? 'متابعة القراءة' : 'إيقاف مؤقت', onPressed: _toggleReaderPlayback, icon: Icon(_readerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)),
            ]),
          ),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .45)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l10n.t('einoAttach'),
                onPressed: busy ? null : _pickMedia,
                icon: const Icon(Icons.add_rounded, size: 27),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) { if (!busy && hasText) _send(); },
                  decoration: InputDecoration(
                    hintText: l10n.t('einoHint'),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
                  ),
                ),
              ),
              if (!hasText && !busy)
                IconButton(
                  tooltip: _recording ? l10n.t('einoStopRecording') : l10n.t('einoVoice'),
                  onPressed: _toggleRecording,
                  color: _recording ? cs.error : null,
                  icon: Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_none_rounded, size: 25),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 3, bottom: 2),
                  child: IconButton.filled(
                    tooltip: busy ? 'جاري التفكير' : l10n.t('send'),
                    onPressed: busy || !hasText ? null : _send,
                    style: IconButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                    icon: busy
                        ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.2))
                        : const Icon(Icons.arrow_upward_rounded, size: 23),
                  ),
                ),
            ],
          ),
        ),
        if (_recording)
          Padding(padding: const EdgeInsets.only(top: 5), child: Text('جارٍ الاستماع… اضغط الميكروفون لإنهاء التسجيل وتحويله إلى نص', style: TextStyle(fontSize: 12, color: cs.primary))),
        if (_uploading)
          Padding(padding: const EdgeInsets.only(top: 5), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8)), const SizedBox(width: 8), Text('جارٍ تحويل الصوت إلى نص…', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))])),
      ],
    );
  }
}
