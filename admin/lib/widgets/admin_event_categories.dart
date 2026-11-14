import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/admin_repository.dart';

class AdminEventCategories extends StatefulWidget {
  const AdminEventCategories({
    super.key,
    required this.repo,
    required this.eventId,
    required this.canWrite,
  });

  final AdminRepository repo;
  final String eventId;
  final bool canWrite;

  @override
  State<AdminEventCategories> createState() => _AdminEventCategoriesState();
}

class _AdminEventCategoriesState extends State<AdminEventCategories> {
  final _search = TextEditingController();
  Map<String, String> _categories = {};
  List<String> _saved = [], _selected = [];
  String? _revision, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool save = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.repo.eventCategories(
        widget.eventId,
        categoryIds: save ? _selected : null,
        revision: save ? _revision : null,
      );
      if (!mounted) return;
      setState(() {
        _revision = data['revision'] as String;
        _categories = {
          for (final row in data['categories'] as List)
            row['id'] as String: row['name'] as String,
        };
        _saved = List<String>.from(data['linked_ids'] as List);
        _selected = [..._saved];
      });
      if (save) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PostgrestException && error.code == '40001'
            ? 'These links changed. Reload to get the latest selection.'
            : 'Could not ${save ? 'save' : 'load'} linked categories.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _move(int from, int to) {
    setState(() => _selected.insert(to, _selected.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final changed = _selected.join(',') != _saved.join(',');
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Linked categories'),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?) ...[
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Reload'),
                ),
              ],
              if (_revision != null) ...[
                if (_selected.isEmpty) const Text('No categories linked.'),
                for (final (index, id) in _selected.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text('${index + 1}'),
                    title: Text(_categories[id] ?? id),
                    trailing: widget.canWrite
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Move up',
                                onPressed: _busy || index == 0
                                    ? null
                                    : () => _move(index, index - 1),
                                icon: const Icon(Icons.keyboard_arrow_up),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                onPressed:
                                    _busy || index == _selected.length - 1
                                    ? null
                                    : () => _move(index, index + 1),
                                icon: const Icon(Icons.keyboard_arrow_down),
                              ),
                              IconButton(
                                tooltip: 'Remove link',
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          setState(() => _selected.remove(id)),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          )
                        : null,
                  ),
                if (widget.canWrite) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Find parent categories',
                    ),
                  ),
                  for (final entry in _categories.entries)
                    if (!_selected.contains(entry.key) &&
                        entry.value.toLowerCase().contains(query))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        trailing: IconButton(
                          tooltip: 'Link category',
                          onPressed: _busy || _selected.length >= 200
                              ? null
                              : () => setState(() => _selected.add(entry.key)),
                          icon: const Icon(Icons.add_link),
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(widget.canWrite ? 'Cancel' : 'Close'),
          ),
          if (widget.canWrite)
            FilledButton(
              onPressed: !_busy && changed ? () => _load(save: true) : null,
              child: const Text('Save links'),
            ),
        ],
      ),
    );
  }
}
