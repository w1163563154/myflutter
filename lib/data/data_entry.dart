import 'package:flutter/material.dart';
import '../journal/journal_store.dart';
import '../journal/vault_service.dart';
import 'data_management_page.dart';

final dataRevision = ValueNotifier<int>(0);

Widget dataAction(
  BuildContext context, {
  JournalStore? journal,
  VaultService? vault,
}) => IconButton(
  tooltip: '数据管理',
  icon: const Icon(Icons.folder_copy_outlined, size: 21),
  onPressed: () async {
    (vault ?? VaultService.instance).lock();
    final restored = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataManagementPage(journal: journal, vault: vault),
      ),
    );
    if (restored == true) dataRevision.value++;
  },
);
