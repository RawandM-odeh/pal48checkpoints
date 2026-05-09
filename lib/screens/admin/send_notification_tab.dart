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
  bool _sending = false;

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
    setState(() => _sending = true);
    try {
      await context.read<NotificationRepository>().sendBroadcastToAllUsers(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار')),
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
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
                'إرسال إشعار لجميع المستخدمين',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
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
                  labelText: 'النص',
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
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send),
                label:
                    Text(_sending ? 'جاري الإرسال...' : 'إرسال للجميع'),
              ),
              const SizedBox(height: 12),
              Text(
                'يجب أن تكون دالة sendBroadcastNotification مفعّلة في Cloud Functions وأن حساب المشرف موجود في Firebase.',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
