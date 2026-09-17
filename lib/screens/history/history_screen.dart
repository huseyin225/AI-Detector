import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/history_service.dart';
import '../../core/constants/app_strings.dart';
import '../../services/settings_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Geçmişi Temizle'),
                  content: const Text('Tüm geçmiş kayıtlarını silmek istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<HistoryService>().clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<HistoryService, SettingsService>(
        builder: (context, historyService, settings, child) {
          final history = historyService.history;
          
          if (history.isEmpty) {
            return const Center(
              child: Text('Henüz geçmiş kaydı bulunmuyor.'),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              return Dismissible(
                key: Key(entry.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => historyService.deleteEntry(entry.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text(
                      DateFormat('dd MMM yyyy, HH:mm:ss').format(entry.timestamp),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${entry.detections.length} nesne algılandı'),
                    children: entry.detections.map((det) {
                      String label = settings.useTurkishLabels 
                          ? AppStrings.getTranslation(det.label) 
                          : det.label;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.center_focus_weak),
                        title: Text(label),
                        trailing: Text('${(det.confidence * 100).toStringAsFixed(1)}%'),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
