import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// AI / chatbot landing (équivalent AdminAIPage web).
class AdminAIPage extends StatefulWidget {
  const AdminAIPage({super.key});

  @override
  State<AdminAIPage> createState() => _AdminAIPageState();
}

class _AdminAIPageState extends State<AdminAIPage> {
  final AdminRepository _repo = AdminRepository();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(title: 'IA', description: 'Questions du chatbot landing, prédictions et conseils SaaS'),
          const SizedBox(height: 24),
          FutureBuilder(
            future: _repo.listCompanies(),
            builder: (context, snap) {
              if (!snap.hasData) return AdminCard(padding: const EdgeInsets.all(24), child: const Center(child: CircularProgressIndicator()));
              final companies = snap.data!;
              final enabledCount = companies.where((c) => c.aiPredictionsEnabled).length;
              return AdminCard(
                padding: const EdgeInsets.all(20),
                child: Text('$enabledCount entreprise(s) avec prédictions IA activées sur ${companies.length}.'),
              );
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<AdminCompany>>(
            future: _repo.listCompanies(),
            builder: (context, snap) {
              if (!snap.hasData) return AdminCard(padding: const EdgeInsets.all(24), child: const Center(child: CircularProgressIndicator()));
              final companies = snap.data!;
              return AdminCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [DataColumn(label: Text('Entreprise')), DataColumn(label: Text('Prédictions IA')), DataColumn(label: Text('Action'))],
                    rows: companies.map((c) => DataRow(
                      cells: [
                        DataCell(Text(c.name)),
                        DataCell(Text(c.aiPredictionsEnabled ? 'Activées' : 'Désactivées', style: TextStyle(color: c.aiPredictionsEnabled ? Colors.green : Colors.grey))),
                        DataCell(IconButton(
                          icon: Icon(c.aiPredictionsEnabled ? Icons.power_off : Icons.power_settings_new, size: 20),
                          tooltip: c.aiPredictionsEnabled ? 'Désactiver' : 'Activer',
                          onPressed: () => _toggleAI(c.id, !c.aiPredictionsEnabled),
                        )),
                      ],
                    )).toList(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Questions du chatbot (landing)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _repo.listLandingChatMessages(limit: 500),
            builder: (context, snap) {
              if (!snap.hasData) return AdminCard(padding: const EdgeInsets.all(24), child: const Center(child: CircularProgressIndicator()));
              final msgs = snap.data!;
              final userCount = msgs.where((m) => m['role'] == 'user').length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$userCount question(s) posée(s) par les visiteurs.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 8),
                  AdminCard(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Session')), DataColumn(label: Text('Rôle')), DataColumn(label: Text('Message'))],
                            rows: msgs.map((m) {
                              final created = m['created_at'] as String?;
                              String dateStr = '—';
                              if (created != null) {
                                try {
                                  dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(created));
                                } catch (_) {}
                              }
                              final role = m['role'] as String? ?? '—';
                              final content = m['content'] as String? ?? '';
                              return DataRow(cells: [
                                DataCell(Text(dateStr)),
                                DataCell(Text((m['session_id'] as String? ?? '').length > 8 ? (m['session_id'] as String).substring(0, 8) : (m['session_id'] as String? ?? '—'))),
                                DataCell(Text(role == 'user' ? 'Visiteur' : 'Assistant', style: TextStyle(color: role == 'user' ? Colors.orange : Colors.grey))),
                                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: Text(content.length > 200 ? '${content.substring(0, 200)}…' : content, maxLines: 2, overflow: TextOverflow.ellipsis))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Prédictions & gain SaaS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AdminCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Génère un rapport à partir des questions des visiteurs (nécessite clé API DeepSeek configurée côté web).', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Générer le rapport'),
                    onPressed: () => AppToast.info(context, 'Génération rapport : utilisez l\'app web (config DeepSeek).'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAI(String id, bool enabled) async {
    try {
      await _repo.updateCompany(id, aiPredictionsEnabled: enabled);
      if (mounted) {
        setState(() {});
        AppToast.success(context, 'Prédictions IA mises à jour');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }
}
