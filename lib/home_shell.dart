import 'package:flutter/material.dart';
import 'journal/journal_store.dart';
import 'journal/notes_page.dart';
import 'journal/vault_service.dart';
import 'records/records_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.store});
  final JournalStore? store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  bool _courierVisited = false;
  late final _store = widget.store ?? JournalStore.instance;
  late final _vault = widget.store == null
      ? VaultService.instance
      : VaultService(_store);
  @override
  void dispose() {
    if (widget.store != null) {
      _vault.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: _selected,
        children: [
          NotesPage(store: _store, vault: _vault),
          if (_courierVisited) const RecordsPage() else const SizedBox.shrink(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (index) => setState(() {
        if (index != _selected) {
          _vault.lock();
        }
        _selected = index;
        if (index == 1) _courierVisited = true;
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.note_alt_outlined),
          label: '个人记录',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: '快递记录',
        ),
      ],
    ),
  );
}
