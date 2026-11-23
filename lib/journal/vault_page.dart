import 'package:flutter/material.dart';
import 'vault_service.dart';
import 'vault_forms.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key, required this.service});
  final VaultService service;
  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _search = TextEditingController();
  List<VaultEntry> _entries = [];
  VaultEntry? _selected;
  bool _show = false, _busy = true, _configured = false, _failed = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _load();
  }

  void _changed() {
    if (!widget.service.isUnlocked) {
      _request++;
      _entries = [];
      _selected = null;
      _show = false;
      _search.clear();
    }
    if (mounted) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final configured = await widget.service.isConfigured();
      final entries = widget.service.isUnlocked
          ? await widget.service.entries()
          : <VaultEntry>[];
      if (mounted && request == _request) {
        setState(() {
          _configured = configured;
          _entries = entries;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _request++;
    widget.service.removeListener(_changed);
    _entries = [];
    _selected = null;
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([int? id]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VaultEditor(service: widget.service, id: id),
      ),
    );
    if (mounted) {
      setState(() {
        _selected = null;
        _show = false;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('读取失败或数据无法验证，请重试'),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (!widget.service.isUnlocked) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: Color(0xFFE9DFC8),
                child: Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: Color(0xFF999875),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '私密的小角落',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                '常用的网站和账号，单独收好。\n解锁后，再慢慢查看。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A866D), height: 1.8),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => VaultAuth(
                        service: widget.service,
                        setup: !_configured,
                      ),
                    ),
                  );
                  if (mounted) _load();
                },
                child: Text(_configured ? '解锁密码库' : '首次使用 · 设置主密码'),
              ),
            ],
          ),
        ),
      );
    }
    final e = _selected;
    if (e != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _selected = null;
                _show = false;
              }),
              icon: const Icon(Icons.chevron_left),
              label: const Text('返回密码库'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('网址：${e.url.isEmpty ? '未填写' : e.url}'),
                  const SizedBox(height: 12),
                  Text('账号：${e.account.isEmpty ? '未填写' : e.account}'),
                  const SizedBox(height: 12),
                  Text(
                    '密码：${_show ? e.password : '••••••••'}',
                    key: const Key('vault-secret'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _show = !_show),
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    label: Text(_show ? '隐藏密码' : '显示密码'),
                  ),
                  Text('备注：${e.note.isEmpty ? '未填写' : e.note}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => _edit(e.id),
                child: const Text('编辑条目'),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.service.lock,
                child: const Text('立即锁定'),
              ),
            ],
          ),
        ],
      );
    }
    final q = _search.text.toLowerCase();
    final visible = _entries
        .where((e) => '${e.name} ${e.url}'.toLowerCase().contains(q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              const Text('已解锁', style: TextStyle(color: Color(0xFF999875))),
              const Spacer(),
              TextButton(
                onPressed: widget.service.lock,
                child: const Text('立即锁定'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索名称或网址',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: TextButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('新建密码条目'),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text(q.isEmpty ? '还没有保存的密码条目' : '未找到匹配条目'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final entry = visible[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        title: Text(entry.name),
                        subtitle: Text(entry.url.isEmpty ? '未填写网址' : entry.url),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() {
                          _selected = entry;
                          _show = false;
                        }),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
