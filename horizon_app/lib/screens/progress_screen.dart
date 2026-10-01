import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../services/pocketbase_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _pbService = PocketBaseService();
  List<RecordModel> _reports = [];
  bool _isLoading = true;
  DateTime? selectedFilterDate;
  String? selectedFilterEmail;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  String getUserDisplayName(RecordModel report) {
    String displayName = "Unknown User";
    try {
      if (report.expand.containsKey('user_id') && report.expand['user_id']!.isNotEmpty) {
        final userRecord = report.expand['user_id']![0];
        
        // 1. Prioritize email
        displayName = userRecord.getStringValue('email');
        
        // 2. Fallbacks if email is hidden by PocketBase privacy
        if (displayName.isEmpty) displayName = userRecord.getStringValue('username');
        if (displayName.isEmpty) displayName = userRecord.getStringValue('name');
        if (displayName.isEmpty) displayName = 'User ID: ${userRecord.id}';
      }
    } catch (e) {
      // Use default 'Unknown User'
    }
    return displayName;
  }

  List<RecordModel> get _filteredReports {
    var filtered = _reports;

    // Filter by date if selected
    if (selectedFilterDate != null) {
      filtered = filtered.where((report) {
        try {
          final created = DateTime.parse(report.data['created']).toLocal();
          return created.year == selectedFilterDate!.year &&
              created.month == selectedFilterDate!.month &&
              created.day == selectedFilterDate!.day;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Filter by user display name if selected
    if (selectedFilterEmail != null && selectedFilterEmail != 'All Users') {
      filtered = filtered.where((report) {
        return getUserDisplayName(report) == selectedFilterEmail;
      }).toList();
    }

    return filtered;
  }

  Set<String> get _uniqueUsers {
    final users = <String>{};
    for (var report in _reports) {
      final displayName = getUserDisplayName(report);
      if (displayName != "Unknown User") {
        users.add(displayName);
      }
    }
    return users;
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // The server's list rule returns only the member's own reports (admins see all)
      final records = await _pbService.client
          .collection('progress_reports')
          .getFullList(
            sort: '-created',
            expand: 'user_id',
          );

      if (mounted) {
        setState(() {
          _reports = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: ${e.toString()}'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  void _showSubmitReportSheet() {
    final tasksController = TextEditingController();
    final submitId = PocketBaseService.newId(); // one record per form, even if submitted twice
    final blockersController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Submit Daily Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tasksController,
                  decoration: const InputDecoration(
                    labelText: 'Tasks Completed Today',
                    hintText: 'What did you accomplish?',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: blockersController,
                  decoration: const InputDecoration(
                    labelText: 'Current Blockers',
                    hintText: 'Any issues or blockers? (Optional)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SubmitButton(
                  onPressed: () async {
                    if (tasksController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter tasks completed'),
                        ),
                      );
                      return;
                    }

                    try {
                      final userId = _pbService.currentUser?.id;
                      if (userId == null) {
                        throw Exception('User not authenticated');
                      }

                      await PocketBaseService.createOnce(_pbService.client.collection('progress_reports'), submitId, {
                          'user_id': userId,
                          'tasks_completed': tasksController.text.trim(),
                          'current_blockers': blockersController.text.trim(),
                        },
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Progress report submitted'),
                          ),
                        );
                        _fetchReports();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit: ${e.toString()}'),
                            backgroundColor: C.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      await _pbService.client.collection('progress_reports').delete(reportId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted'),
          ),
        );
        _fetchReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  void _confirmDelete(String reportId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: const Text('Are you sure you want to delete this progress report?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteReport(reportId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime).toLocal();
      return DateFormat('MMM d, y • h:mm a').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pbService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _reports.isEmpty
              ? Center(
                  child: Text(
                    'No progress reports yet',
                    style: TextStyle(fontSize: 18, color: C.muted),
                  ),
                )
              : Column(
                  children: [
                    if (isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(context).cardColor,
                        child: Row(
                          children: [
                            // Date filter
                            IconButton(
                              icon: Icon(
                                selectedFilterDate != null
                                    ? Icons.event
                                    : Icons.event_outlined,
                                color: selectedFilterDate != null
                                    ? C.accent
                                    : C.line,
                              ),
                              tooltip: 'Filter by date',
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedFilterDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedFilterDate = picked;
                                  });
                                }
                              },
                            ),
                            if (selectedFilterDate != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedFilterDate = null;
                                  });
                                },
                                child: Text(
                                  DateFormat('MMM d, y').format(selectedFilterDate!),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Email filter dropdown
                            Expanded(
                              child: DropdownButton<String>(
                                value: selectedFilterEmail,
                                hint: const Text('All Users'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: 'All Users',
                                    child: Text('All Users'),
                                  ),
                                  ..._uniqueUsers.map((user) {
                                    return DropdownMenuItem<String>(
                                      value: user,
                                      child: Text(
                                        user,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (String? value) {
                                  setState(() {
                                    selectedFilterEmail = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                      final tasksCompleted = report.data['tasks_completed'] ?? '';
                      final currentBlockers = report.data['current_blockers'] ?? '';
                      final created = report.data['created'];
                      final displayName = getUserDisplayName(report);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(created),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: C.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      tooltip: 'Delete',
                                      color: C.danger,
                                      onPressed: () => _confirmDelete(report.id),
                                    ),
                                ],
                              ),
                              const Divider(height: 24),
                              const Text(
                                'Tasks Completed:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tasksCompleted,
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (currentBlockers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Blockers:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: C.danger,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentBlockers,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: C.danger,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSubmitReportSheet,
        tooltip: 'Submit Progress',
        child: const Icon(Icons.add),
      ),
    );
  }
}
