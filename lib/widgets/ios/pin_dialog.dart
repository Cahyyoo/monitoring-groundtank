import 'package:flutter/cupertino.dart';

/// Asks for the admin PIN. Resolves to what was typed, or null when
/// cancelled. Checking it is the caller's job, against the server.
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showCupertinoDialog<String>(
    context: context,
    builder: (_) => _PinDialog(title: title, message: message),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text;
    if (pin.isEmpty) return;
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Column(
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _controller,
            placeholder: 'PIN admin',
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('Buka kunci'),
        ),
      ],
    );
  }
}
