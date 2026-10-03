import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

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
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                isBili
                    ? Icons.play_circle_rounded
                    : (isCustom
                        ? Icons.extension_rounded
                        : Icons.headphones_rounded),
                size: 28,
                color: isCurrent ? AppTheme.accent : AppTheme.textSub,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      source.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
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
              subtitle: Text(
                source.description,
                style: TextStyle(fontSize: 12, color: AppTheme.textSub),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
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
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (isEnabled)
                    FilledButton.tonal(
                      onPressed: () => store.setCurrent(source.id),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('切换', style: TextStyle(fontSize: 13)),
                    ),
                  if (!isBili)
                    Switch(
                      value: isEnabled,
                      onChanged: (v) => store.setEnabled(source.id, v),
                      activeThumbColor: AppTheme.accent,
                    ),
                  if (isCustom)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppTheme.textSub),
                      tooltip: '删除本地源',
                      onPressed: () => _confirmRemove(context, source.id, source.name),
                    ),
                ],
              ),
              onTap: isCurrent || !isEnabled
                  ? null
                  : () => store.setCurrent(source.id),
            ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('加载内置示例 (ting55)'),
                    onPressed: () async {
                      try {
                        final text = await rootBundle
                            .loadString('assets/sources/ting55.json');
                        controller.text = text;
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('加载示例失败: $e')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
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