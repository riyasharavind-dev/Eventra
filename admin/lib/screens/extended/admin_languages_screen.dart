import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/admin_language.dart';
import '../../repositories/admin_language_repository.dart';
import '../../services/app_live_data.dart';

class AdminLanguagesScreen extends StatefulWidget {
  const AdminLanguagesScreen({
    super.key,
    required this.canWrite,
    required this.canPublish,
    this.repository,
  });
  final bool canWrite, canPublish;
  final AdminLanguageRepository? repository;
  @override
  State<AdminLanguagesScreen> createState() => _AdminLanguagesScreenState();
}

class _AdminLanguagesScreenState extends State<AdminLanguagesScreen>
    with LiveDataState<AdminLanguagesScreen> {
  late final repo = widget.repository ?? AdminLanguageRepository();
  final search = TextEditingController();
  Timer? _debounce;
  List<AdminLanguage> languages = [];
  List<String> modules = [];
  List<TranslationEntry> words = [];
  String? code;
  String module = '';
  bool missing = false, loading = true, busy = false, editing = false;
  String? error;
  int total = 0, offset = 0, revision = 0, generation = 0;
  AdminLanguage? get language =>
      languages.where((v) => v.code == code).firstOrNull;
  @override
  Set<String> get liveDatasets => {
    'admin:app_languages',
    'admin:app_translation_keys',
    'admin:app_translation_drafts',
    'admin:app_language_releases',
  };
  @override
  bool get liveCanRefresh => !editing && !busy;
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String readable(Object value) {
    final text = value.toString();
    if (text.contains('40001')) {
      return 'Someone changed this draft. Reload before saving; copy your translation before closing the editor.';
    }
    return text
        .replaceFirst('PostgrestException(message: ', '')
        .split(', code:')
        .first;
  }

  Future<void> load() async {
    final request = ++generation;
    if (mounted) {
      setState(() {
        if (!liveRefreshing) loading = true;
        error = null;
      });
    }
    try {
      final data = await repo.workspace();
      final list = (data['languages'] as List)
          .map(
            (e) => AdminLanguage.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final selected = list.any((e) => e.code == code)
          ? code
          : (list.where((e) => e.code != 'en').firstOrNull ?? list.firstOrNull)
                ?.code;
      final page = selected == null
          ? null
          : await repo.entries(
              selected,
              search: search.text.trim(),
              module: module,
              missing: missing,
              offset: offset,
            );
      if (!mounted || request != generation) return;
      setState(() {
        languages = list;
        modules = List<String>.from(data['modules'] as List);
        code = selected;
        words = page == null
            ? []
            : (page['rows'] as List)
                  .map(
                    (e) => TranslationEntry.fromMap(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList();
        total = (page?['total'] as num?)?.toInt() ?? 0;
        revision = (page?['revision'] as num?)?.toInt() ?? 0;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = readable(e);
          loading = false;
        });
      }
    }
  }

  Future<void> mutation(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(readable(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> metadata({bool create = false}) async {
    final current = language;
    if (!create && current == null) return;
    final key = TextEditingController(text: create ? '' : current!.code),
        name = TextEditingController(text: create ? '' : current!.name),
        native = TextEditingController(text: create ? '' : current!.nativeName);
    var direction = create ? 'ltr' : current!.direction,
        enabled = create ? false : current!.enabled;
    final form = GlobalKey<FormState>();
    String? failure;
    var saving = false;
    editing = true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(create ? 'Add language' : 'Language settings'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: key,
                      enabled: create && !saving,
                      decoration: const InputDecoration(
                        labelText: 'Language code',
                        helperText: 'BCP-47, for example hi, te, fr or pt-BR',
                      ),
                      validator: (v) =>
                          RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Enter a valid language code',
                    ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'English language name',
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: native,
                      decoration: const InputDecoration(
                        labelText: 'Native language name',
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: direction,
                      decoration: const InputDecoration(
                        labelText: 'Text direction',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ltr',
                          child: Text('Left to right'),
                        ),
                        DropdownMenuItem(
                          value: 'rtl',
                          child: Text('Right to left'),
                        ),
                      ],
                      onChanged: saving ? null : (v) => direction = v ?? 'ltr',
                    ),
                    if (!create)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available in vendor app'),
                        subtitle: const Text(
                          'Publish a pack before enabling. Disabling does not erase installed offline packs.',
                        ),
                        value: enabled,
                        onChanged:
                            widget.canPublish && !saving && key.text != 'en'
                            ? (v) => setDialog(() => enabled = v)
                            : null,
                      ),
                    if (create)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Starts disabled. Translate, validate, publish, then enable.',
                        ),
                      ),
                    if (failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          failure!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialog(() => saving = true);
                      try {
                        if (create) {
                          await repo.create(
                            key.text.trim(),
                            name.text.trim(),
                            native.text.trim(),
                            direction,
                          );
                        } else {
                          await repo.update(
                            current!.code,
                            name.text.trim(),
                            native.text.trim(),
                            direction,
                            enabled,
                            revision,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) setState(() => code = key.text.trim());
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() {
                            failure = readable(e);
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    editing = false;
    key.dispose();
    name.dispose();
    native.dispose();
    if (mounted) await load();
  }

  Future<void> editWord(TranslationEntry entry) async {
    final selected = code;
    if (selected == null) return;
    final text = TextEditingController(text: entry.value);
    final expected = revision;
    String? failure;
    var saving = false;
    editing = true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Translate app text'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'English source',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(entry.source),
                  if (entry.placeholders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Keep these placeholders exactly: ${entry.placeholders.map((v) => '{$v}').join(' ')}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: text,
                    minLines: 3,
                    maxLines: 10,
                    maxLength: 12000,
                    decoration: InputDecoration(
                      labelText: language?.nativeName ?? selected,
                      border: const OutlineInputBorder(),
                      helperText: 'Leave blank to mark missing. Drafts are not live until published.',
                    ),
                  ),
                  Text(entry.notes, style: const TextStyle(fontSize: 11)),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (widget.canWrite)
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialog(() => saving = true);
                        try {
                          await repo.save(selected, {
                            entry.key: text.text,
                          }, expected);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setDialog(() {
                              failure = readable(e);
                              saving = false;
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save draft'),
              ),
          ],
        ),
      ),
    );
    editing = false;
    text.dispose();
    if (mounted) await load();
  }

  Future<void> publish() async {
    final selected = code;
    if (selected == null) return;
    setState(() => busy = true);
    Map<String, dynamic> validation;
    try {
      validation = await repo.validate(selected);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(readable(e))));
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    editing = true;
    final absent = List<String>.from(validation['missing'] as List),
        invalid = List<String>.from(validation['invalid'] as List);
    var allowFallback = false;
    String? failure;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Validate & publish'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${language?.nativeName} · draft revision ${validation['revision']}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${absent.length} missing translations · ${invalid.length} placeholder errors',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Publishing creates an immutable version. Devices download it in the background and replace their cache only after successful validation.',
                  ),
                  if (invalid.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Fix these keys before publishing:'),
                    SelectableText(invalid.take(30).join('\n')),
                  ],
                  if (absent.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allowFallback,
                      onChanged: saving
                          ? null
                          : (v) => setDialog(() => allowFallback = v ?? false),
                      title: const Text(
                        'Explicitly use English for missing translations',
                      ),
                    ),
                  if (language?.enabled == false)
                    const Text(
                      'This language is disabled. Enable it in Language settings after publishing.',
                    ),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (widget.canPublish)
              FilledButton(
                onPressed:
                    saving ||
                        invalid.isNotEmpty ||
                        (absent.isNotEmpty && !allowFallback)
                    ? null
                    : () async {
                        setDialog(() => saving = true);
                        try {
                          await repo.publish(
                            selected,
                            (validation['revision'] as num).toInt(),
                            allowFallback,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setDialog(() {
                              failure = readable(e);
                              saving = false;
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Publishing…' : 'Publish new version'),
              ),
          ],
        ),
      ),
    );
    editing = false;
    if (mounted) await load();
  }

  Future<void> transfer({required bool importing}) async {
    final selected = code;
    if (selected == null) return;
    final text = TextEditingController();
    editing = true;
    String? failure;
    var saving = false;
    if (!importing) {
      try {
        text.text = const JsonEncoder.withIndent('  ')
            .convert(await repo.export(selected));
      } catch (e) {
        failure = readable(e);
      }
    }
    if (!mounted) {
      text.dispose();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            importing ? 'Import translation JSON' : 'Export translation JSON',
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Use a flat {"key":"translation"} map, or the exported document with code/messages/source. Placeholder tokens must be preserved.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: text,
                    readOnly: !importing,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'JSON',
                    ),
                  ),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (!importing)
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: text.text)),
                child: const Text('Copy JSON'),
              ),
            if (importing && widget.canWrite)
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialog(() => saving = true);
                        try {
                          final document =
                              jsonDecode(text.text) as Map<String, dynamic>;
                          if (document['code'] != null &&
                              document['code'] != selected) {
                            throw const FormatException(
                              'Import language does not match selection',
                            );
                          }
                          final values = document['messages'] is Map
                              ? Map<String, dynamic>.from(
                                  document['messages'] as Map,
                                )
                              : document;
                          if (values.values.any((v) => v is! String)) {
                            throw const FormatException(
                              'Every translation must be a string',
                            );
                          }
                          await repo.save(selected, values, revision);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setDialog(() {
                              failure = readable(e);
                              saving = false;
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Importing…' : 'Import to draft'),
              ),
          ],
        ),
      ),
    );
    editing = false;
    text.dispose();
    if (mounted) await load();
  }

  Future<void> history() async {
    final selected = code;
    if (selected == null) return;
    editing = true;
    try {
      final rows = await repo.history(selected);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Published versions'),
          content: SizedBox(
            width: 650,
            height: 360,
            child: ListView(
              children: [
                if (rows.isEmpty)
                  const ListTile(title: Text('No published versions')),
                for (final row in rows)
                  ListTile(
                    title: Text('Version ${row['version']}'),
                    subtitle: Text(
                      '${row['created_at']}\n${row['fallback_count']} English fallbacks\n${row['sha256']}',
                    ),
                    isThreeLine: true,
                    trailing: widget.canWrite
                        ? TextButton(
                            onPressed: () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Replace current draft?'),
                                  content: const Text(
                                    'This restores the selected release to draft only. Review, validate and publish a NEW version to roll back live content.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Restore draft'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes != true) return;
                              try {
                                await repo.restore(
                                  selected,
                                  (row['version'] as num).toInt(),
                                  revision,
                                );
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(readable(e))),
                                  );
                                }
                              }
                            },
                            child: const Text('Restore draft'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(readable(e))));
      }
    } finally {
      editing = false;
      if (mounted) await load();
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Language workspace',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create → translate drafts → validate → publish → enable. Vendor devices keep a verified offline copy.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('language-$code'),
                          initialValue: code,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: languages
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l.code,
                                  child: Text('${l.nativeName} (${l.code})'),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) {
                                  setState(() {
                                    code = v;
                                    offset = 0;
                                  });
                                  load();
                                },
                        ),
                      ),
                      if (widget.canWrite)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => metadata(create: true),
                          icon: const Icon(Icons.add),
                          label: const Text('Add language'),
                        ),
                      if (widget.canWrite && language != null)
                        OutlinedButton(
                          onPressed: busy ? null : metadata,
                          child: const Text('Language settings'),
                        ),
                      if (language != null)
                        OutlinedButton(
                          onPressed: busy ? null : publish,
                          child: const Text('Validate / Publish'),
                        ),
                      if (language != null)
                        OutlinedButton(
                          onPressed: busy ? null : history,
                          child: const Text('Version history'),
                        ),
                      if (language != null)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => transfer(importing: false),
                          child: const Text('Export'),
                        ),
                      if (language != null && widget.canWrite)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => transfer(importing: true),
                          child: const Text('Import'),
                        ),
                    ],
                  ),
                  if (language != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${language!.translated}/${language!.total} translated · published v${language!.version} · ${language!.enabled ? 'Enabled' : 'Disabled'} · ${language!.fallbacks} published English fallbacks',
                    ),
                    if (!widget.canWrite)
                      const Text(
                        'Read-only: translation editing is not permitted.',
                      ),
                    if (!widget.canPublish)
                      const Text(
                        'Publishing requires separate Language Publishing write permission.',
                      ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search keys, English or translations',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                offset = 0;
                                load();
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          initialValue: module,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'App section',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All sections'),
                            ),
                            ...modules.map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              module = v ?? '';
                              offset = 0;
                            });
                            load();
                          },
                        ),
                      ),
                      FilterChip(
                        label: const Text('Missing translations'),
                        selected: missing,
                        onSelected: (v) {
                          setState(() {
                            missing = v;
                            offset = 0;
                          });
                          load();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            if (loading || busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
      SliverList.builder(
        itemCount: words.length,
        itemBuilder: (context, index) {
          final entry = words[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: ListTile(
              title: Text(
                entry.source,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 5),
                  Text(
                    entry.value.isEmpty ? 'Missing translation' : entry.value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.invalid
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                entry.invalid
                    ? Icons.error_outline
                    : entry.value.isEmpty
                    ? Icons.translate
                    : Icons.check_circle_outline,
              ),
              onTap: busy ? null : () => editWord(entry),
            ),
          );
        },
      ),
      SliverToBoxAdapter(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Text(
                  '$total words · ${total == 0 ? 0 : offset + 1}–${offset + words.length}',
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: offset == 0 || loading
                      ? null
                      : () {
                          offset = (offset - 40).clamp(0, total);
                          load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: offset + words.length >= total || loading
                      ? null
                      : () {
                          offset += 40;
                          load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
