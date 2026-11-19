import 'package:PiliPlus/utils/storage.dart';
import 'package:material_ui/material_ui.dart';

class InlineKeywordEditor extends StatefulWidget {
  const InlineKeywordEditor({
    super.key,
    required this.title,
    required this.storageKey,
    required this.onChanged,
  });
  final String title, storageKey;
  final ValueChanged<RegExp> onChanged;
  @override
  State<InlineKeywordEditor> createState() => _InlineKeywordEditorState();
}

class _InlineKeywordEditorState extends State<InlineKeywordEditor> {
  late final controller = TextEditingController(
    text: GStorage.setting.get(widget.storageKey, defaultValue: ''),
  );
  String? error;
  bool saved = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => setState(() => saved = false),
          decoration: InputDecoration(
            isDense: true,
            hintText: '多个词用 | 分隔',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              try {
                final pattern = RegExp(controller.text, caseSensitive: false);
                await GStorage.setting.put(widget.storageKey, controller.text);
                widget.onChanged(pattern);
                setState(() {
                  error = null;
                  saved = true;
                });
              } catch (_) {
                setState(() => error = '词条格式有误，请检查');
              }
            },
            child: Text(saved ? '已保存' : '保存'),
          ),
        ),
      ],
    ),
  );
}
