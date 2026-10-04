import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/source/book_source.dart';
import '../core/source/source_store.dart';
import '../core/theme/app_theme.dart';

class SourceManagerPage extends StatefulWidget {
  const SourceManagerPage({super.key});

  @override
  State<SourceManagerPage> createState() => _SourceManagerPageState();
}

class _SourceManagerPageState extends State<SourceManagerPage> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<SourceStore>();
    final sources = store.all;
    final currentId = store.currentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '导入本地源',
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sources.length,
        itemBuilder: (context, i) {
          final source = sources[i];
          final isCurrent = source.id == currentId;
          final isEnabled = store.isEnabled(source.id);
          final isBili = source.id == 'bili';
          final isCustom = store.isCustom(source.id);

          return _SourceCard(
            source: source,
            isCurrent: isCurrent,
            isEnabled: isEnabled,
            isBili: isBili,
            isCustom: isCustom,
            onTap: isCurrent || !isEnabled
                ? null
                : () => store.setCurrent(source.id),
            onToggle: !isBili ? (v) => store.setEnabled(source.id, v) : null,
            onSwitch: (!isCurrent && isEnabled)
                ? () => store.setCurrent(source.id)
                : null,
            onDelete: isCustom
                ? () => _confirmRemove(context, source.id, source.name)
                : null,
          );
        },
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('导入本地源'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _ImportActionButton(
                      icon: Icons.bolt_rounded,
                      label: '内置示例 (pingshu365)',
                      onPressed: () async {
                        try {
                          final text = await rootBundle
                              .loadString('assets/sources/pingshu365.json');
                          controller.text = text;
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('加载示例失败: $e')),
                          );
                        }
                      },
                    ),
                    _ImportActionButton(
                      icon: Icons.folder_open_rounded,
                      label: '从文件导入',
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                          withData: true,
                        );
                        final bytes = result?.files.single.bytes;
                        if (bytes == null || !ctx.mounted) return;
                        try {
                          controller.text = utf8.decode(bytes);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('读取文件失败: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 12,
                  minLines: 6,
                  decoration: const InputDecoration(
                    hintText: '粘贴书源 JSON 配置\n（单个对象或数组）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final wrapped = text.startsWith('[') ? text : '[$text]';
                final ok = await context.read<SourceStore>().importFromJsonString(wrapped);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '导入成功' : '导入失败（ID 为空或已存在）'),
                  ),
                );
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除本地源'),
        content: Text('确定删除「$name」？该源将从列表移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () async {
              await context.read<SourceStore>().removeCustom(id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ImportActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ImportActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppTheme.accent),
      label: Text(
        label,
        style: TextStyle(fontSize: 13, color: AppTheme.accent),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: AppTheme.accent.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final BookSource source;
  final bool isCurrent;
  final bool isEnabled;
  final bool isBili;
  final bool isCustom;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onSwitch;
  final VoidCallback? onDelete;

  const _SourceCard({
    required this.source,
    required this.isCurrent,
    required this.isEnabled,
    required this.isBili,
    required this.isCustom,
    this.onTap,
    this.onToggle,
    this.onSwitch,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppTheme.accent : AppTheme.divider,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isBili
                    ? Icons.play_circle_rounded
                    : (isCustom
                        ? Icons.extension_rounded
                        : Icons.headphones_rounded),
                size: 28,
                color: isCurrent ? AppTheme.accent : AppTheme.textSub,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                        if (isCustom)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.toneCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '本地',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.toneCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSub,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (onSwitch != null)
                    FilledButton.tonal(
                      onPressed: onSwitch,
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('切换', style: TextStyle(fontSize: 12)),
                    )
                  else
                    const SizedBox(height: 30),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onToggle != null)
                        Switch(
                          value: isEnabled,
                          onChanged: onToggle,
                          activeThumbColor: AppTheme.accent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: AppTheme.textSub),
                          tooltip: '删除本地源',
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
