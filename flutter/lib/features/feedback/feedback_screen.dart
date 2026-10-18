import 'package:flutter/material.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  String _category = 'suggestion';
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    try {
      await AppDependencies.instance.feedback.submit(
        category: _category,
        title: _titleController.text,
        details: _detailsController.text,
        screen: 'تطبيق TRINEX للطلاب',
      );
      if (!mounted) return;
      _titleController.clear();
      _detailsController.clear();
      setState(() => _category = 'suggestion');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال المقترح أو البلاغ للإدارة بنجاح. شكرًا لمساعدتنا في تحسين TRINEX.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الإرسال. تحقق من الاتصال ثم أعد المحاولة.\n$error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(14, 18, 14, 30), children: [
        Text('المقترحات والبلاغات', textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.feedback_outlined, size: 34),
          const SizedBox(height: 8),
          const Text('شاركنا اقتراحك أو أبلغ عن مشكلة', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('سيصل البلاغ إلى لوحة الإدارة، ويمكنك فتح هذه الصفحة من قائمة الخدمات أو بهز الهاتف.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        const SizedBox(height: 12),
        Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'نوع الرسالة'),
            items: const [
              DropdownMenuItem(value: 'suggestion', child: Text('مقترح أو تحسين')),
              DropdownMenuItem(value: 'bug', child: Text('مشكلة تقنية')),
              DropdownMenuItem(value: 'content', child: Text('مشكلة في مادة أو محتوى')),
              DropdownMenuItem(value: 'other', child: Text('أخرى')),
            ],
            onChanged: _sending ? null : (value) { if (value != null) setState(() => _category = value); },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'عنوان مختصر', hintText: 'مثال: زر التنزيل لا يعمل'),
            validator: (value) => (value ?? '').trim().length < 3 ? 'أدخل عنوانًا واضحًا.' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _detailsController,
            minLines: 5,
            maxLines: 9,
            maxLength: 3000,
            decoration: const InputDecoration(labelText: 'التفاصيل', hintText: 'اشرح الفكرة أو خطوات ظهور المشكلة.'),
            validator: (value) => (value ?? '').trim().length < 10 ? 'اكتب تفاصيل لا تقل عن 10 أحرف.' : null,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال إلى الإدارة'),
          ),
        ])),
      ]);
  }
}
