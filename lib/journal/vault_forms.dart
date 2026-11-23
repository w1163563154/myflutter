import 'package:flutter/material.dart';
import 'journal_theme.dart';
import 'vault_service.dart';

class VaultAuth extends StatefulWidget {
  const VaultAuth({super.key, required this.service, required this.setup});
  final VaultService service;
  final bool setup;
  @override
  State<VaultAuth> createState() => _VaultAuthState();
}

class _VaultAuthState extends State<VaultAuth> {
  final _password = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.clear();
    _confirm.clear();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (widget.setup &&
        (_password.text.runes.length < 12 || _password.text != _confirm.text)) {
      setState(() => _error = '主密码至少12个字符，两次输入需一致');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = '请输入主密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final password = _password.text;
    _password.clear();
    _confirm.clear();
    try {
      if (widget.setup) {
        await widget.service.setup(password);
      } else {
        await widget.service.unlock(password);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '解锁失败：请检查主密码或稍后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.setup ? '设置密码库' : '解锁密码库')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: Color(0xFF999875),
              ),
              const SizedBox(height: 24),
              Text(
                widget.setup ? '为私密记录设一把锁' : '欢迎回来',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '主密码仅用于本机解锁。忘记后无法保证恢复，请牢记主密码；清除应用或站点数据会丢失记录。',
                style: TextStyle(color: Color(0xFF9A866D), height: 1.7),
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('vault-master'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  labelText: '主密码',
                  helperText: '至少12个字符，建议使用较长的独立短语',
                ),
              ),
              if (widget.setup) ...[
                const SizedBox(height: 20),
                TextField(
                  key: const Key('vault-confirm'),
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(labelText: '再次确认'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? '正在验证…'
                      : widget.setup
                      ? '设置并解锁'
                      : '解锁',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class VaultEditor extends StatefulWidget {
  const VaultEditor({super.key, required this.service, this.id});
  final VaultService service;
  final int? id;
  @override
  State<VaultEditor> createState() => _VaultEditorState();
}

class _VaultEditorState extends State<VaultEditor> {
  final _name = TextEditingController(),
      _url = TextEditingController(),
      _account = TextEditingController(),
      _password = TextEditingController(),
      _note = TextEditingController();
  bool _busy = false,
      _loading = true,
      _show = false,
      _dirty = false,
      _allowPop = false;
  String? _error;
  List<TextEditingController> get _controllers => [
    _name,
    _url,
    _account,
    _password,
    _note,
  ];
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_locked);
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.id != null) {
        final entries = await widget.service.entries();
        if (!mounted || !widget.service.isUnlocked) return;
        final e = entries.firstWhere((e) => e.id == widget.id);
        _name.text = e.name;
        _url.text = e.url;
        _account.text = e.account;
        _password.text = e.password;
        _note.text = e.note;
      }
      if (mounted) {
        for (final c in _controllers) {
          c.addListener(_changed);
        }
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取失败，请返回重试';
        });
      }
    }
  }

  void _changed() {
    widget.service.activity();
    _dirty = true;
  }

  void _locked() {
    if (!widget.service.isUnlocked && mounted) {
      for (final c in _controllers) {
        c.clear();
      }
      setState(() {
        _show = false;
        _dirty = false;
      });
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_locked);
    for (final c in _controllers) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _back() async {
    if (_busy) return;
    if (!_dirty ||
        !widget.service.isUnlocked ||
        await confirmDiscard(context)) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = '请填写网站名称和密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.save(
        id: widget.id,
        name: _name.text,
        url: _url.text,
        account: _account.text,
        password: _password.text,
        note: _note.text,
      );
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.service.isUnlocked
              ? '保存失败，内容已保留，请重试'
              : '密码库已锁定，请返回解锁';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(widget.id == null ? '保存一把钥匙' : '编辑密码条目'),
        actions: [
          if (widget.service.isUnlocked)
            TextButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? '保存中…' : '保存'),
            ),
        ],
      ),
      body: !widget.service.isUnlocked
          ? Center(
              child: TextButton(
                onPressed: _back,
                child: const Text('密码库已锁定，返回解锁'),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    for (final field in [
                      (controller: _name, label: '网站名称 *', key: 'vault-name'),
                      (controller: _url, label: '网址', key: 'vault-url'),
                      (controller: _account, label: '账号', key: 'vault-account'),
                    ]) ...[
                      TextField(
                        key: Key(field.key),
                        controller: field.controller,
                        enabled: !_busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(labelText: field.label),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextField(
                      key: const Key('vault-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableInteractiveSelection: false,
                      decoration: InputDecoration(
                        labelText: '密码 *',
                        suffixIcon: IconButton(
                          tooltip: _show ? '隐藏密码' : '显示密码',
                          onPressed: () => setState(() => _show = !_show),
                          icon: Icon(
                            _show ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('vault-note'),
                      controller: _note,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: '备注'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '进入后台或闲置一分钟会自动锁定。锁定时会清除未保存的密码内容。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A866D)),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
