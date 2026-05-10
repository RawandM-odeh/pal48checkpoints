import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/notification_repository.dart';

class SendNotificationTab extends StatefulWidget {
  const SendNotificationTab({super.key});

  @override
  State<SendNotificationTab> createState() => _SendNotificationTabState();
}

class _SendNotificationTabState extends State<SendNotificationTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<NotificationRepository>().saveNotificationDocument(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الإشعار — سيظهر للمستخدمين في تبويب الإشعارات داخل التطبيق',
          ),
        ),
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'حفظ إشعار للمستخدمين',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                'يُحفظ في السحابة ويُعرَض داخل التطبيق فقط (بدون إشعار نظام للهاتف).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'العنوان مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                textAlign: TextAlign.right,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نص الإشعار',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'النص مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الإشعار'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
