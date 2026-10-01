import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/source/source_store.dart';
import '../core/theme/app_theme.dart';

class SourceManagerPage extends StatelessWidget {
  const SourceManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SourceStore>();
    final sources = store.all;
    final currentId = store.currentId;

    return Scaffold(
      appBar: AppBar(title: const Text('书源管理')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sources.length,
        itemBuilder: (context, i) {
          final source = sources[i];
          final isCurrent = source.id == currentId;
          final isEnabled = store.isEnabled(source.id);
          final isBili = source.id == 'bili';

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
                    : Icons.headphones_rounded,
                size: 28,
                color: isCurrent ? AppTheme.accent : AppTheme.textSub,
              ),
              title: Text(
                source.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.textMain,
                ),
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
}