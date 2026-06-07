import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/nim_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _leverageCtrl;
  late TextEditingController _contractXauCtrl;
  late TextEditingController _contractXagCtrl;
  late TextEditingController _contractForexCtrl;
  late TextEditingController _contractIndicesCtrl;
  late TextEditingController _contractCryptoCtrl;
  late TextEditingController _marginCallCtrl;
  late TextEditingController _stopoutCtrl;
  late TextEditingController _startingCapitalCtrl;
  late TextEditingController _nimBaseUrlCtrl;
  late TextEditingController _nimTemperatureCtrl;
  late TextEditingController _apiKeyCtrl;

  String _accountType = 'usd';
  String _nimModel = 'meta/llama-3.1-nemotron-70b-instruct';
  String _aiLanguage = 'en';
  bool _apiKeyVisible = false;
  bool _saving = false;

  static const _models = [
    'meta/llama-3.1-nemotron-70b-instruct',
    'mistralai/mistral-nemo-12b-instruct',
    'nvidia/llama-3.1-nemotron-nano-8b-instruct',
  ];

  @override
  void initState() {
    super.initState();
    _leverageCtrl = TextEditingController();
    _contractXauCtrl = TextEditingController();
    _contractXagCtrl = TextEditingController();
    _contractForexCtrl = TextEditingController();
    _contractIndicesCtrl = TextEditingController();
    _contractCryptoCtrl = TextEditingController();
    _marginCallCtrl = TextEditingController();
    _stopoutCtrl = TextEditingController();
    _startingCapitalCtrl = TextEditingController();
    _nimBaseUrlCtrl = TextEditingController();
    _nimTemperatureCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final settings =
        await ref.read(settingsRepositoryProvider).getSettings(uid);
    final savedKey = await NimService.loadApiKey();

    setState(() {
      _leverageCtrl.text = settings.leverage.toString();
      _contractXauCtrl.text = settings.contractSizeXauusd.toString();
      _contractXagCtrl.text = settings.contractSizeXagusd.toString();
      _contractForexCtrl.text = settings.contractSizeForex.toString();
      _contractIndicesCtrl.text = settings.contractSizeIndices.toString();
      _contractCryptoCtrl.text = settings.contractSizeCrypto.toString();
      _marginCallCtrl.text = settings.marginCallPct.toString();
      _stopoutCtrl.text = settings.stopoutPct.toString();
      _startingCapitalCtrl.text = settings.startingCapital.toString();
      _nimBaseUrlCtrl.text = settings.nimBaseUrl;
      _nimTemperatureCtrl.text = settings.nimTemperature.toString();
      _accountType = settings.accountType;
      _nimModel = settings.nimModel;
      _aiLanguage = settings.aiLanguage;
      _apiKeyCtrl.text = savedKey ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Save API key securely
    final key = _apiKeyCtrl.text.trim();
    if (key.isNotEmpty) {
      await NimService.saveApiKey(key);
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      setState(() => _saving = false);
      return;
    }

    await ref.read(settingsRepositoryProvider).upsertSettings(
          uid,
          SettingsModel(
            leverage: int.parse(_leverageCtrl.text),
            contractSizeXauusd: int.parse(_contractXauCtrl.text),
            contractSizeXagusd: int.parse(_contractXagCtrl.text),
            contractSizeForex: int.parse(_contractForexCtrl.text),
            contractSizeIndices: int.parse(_contractIndicesCtrl.text),
            contractSizeCrypto: int.parse(_contractCryptoCtrl.text),
            accountType: _accountType,
            marginCallPct: double.parse(_marginCallCtrl.text),
            stopoutPct: double.parse(_stopoutCtrl.text),
            startingCapital: double.parse(_startingCapitalCtrl.text),
            nimModel: _nimModel,
            nimTemperature: double.parse(_nimTemperatureCtrl.text),
            nimBaseUrl: _nimBaseUrlCtrl.text.trim(),
            aiLanguage: _aiLanguage,
          ),
        );

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  void dispose() {
    _leverageCtrl.dispose();
    _contractXauCtrl.dispose();
    _contractXagCtrl.dispose();
    _contractForexCtrl.dispose();
    _contractIndicesCtrl.dispose();
    _contractCryptoCtrl.dispose();
    _marginCallCtrl.dispose();
    _stopoutCtrl.dispose();
    _startingCapitalCtrl.dispose();
    _nimBaseUrlCtrl.dispose();
    _nimTemperatureCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Account'),
            _segmentedField(
              label: 'Account Type',
              value: _accountType,
              options: const {'usd': 'USD (Standard)', 'cent': 'Cent'},
              onChanged: (v) => setState(() => _accountType = v),
            ),
            const SizedBox(height: 12),
            _numberField(
                _startingCapitalCtrl, 'Starting Capital (\$)', isDecimal: true),
            const SizedBox(height: 12),
            _numberField(_leverageCtrl, 'Leverage (e.g. 100 for 1:100)'),
            const SizedBox(height: 12),
            _numberField(_contractXauCtrl, 'XAUUSD Contract Size (oz/lot)'),
            const SizedBox(height: 12),
            _numberField(_contractXagCtrl, 'XAGUSD Contract Size (oz/lot)'),
            const SizedBox(height: 12),
            _numberField(_contractForexCtrl, 'Forex Contract Size (units/lot)'),
            const SizedBox(height: 12),
            _numberField(_contractIndicesCtrl, 'Indices Contract Size (units/lot)'),
            const SizedBox(height: 12),
            _numberField(_contractCryptoCtrl, 'Crypto Contract Size (coins/lot)'),
            const SizedBox(height: 24),

            _sectionHeader('Risk Thresholds'),
            _numberField(_marginCallCtrl, 'Margin Call Warning (%)',
                isDecimal: true),
            const SizedBox(height: 12),
            _numberField(_stopoutCtrl, 'Broker Stopout Level (%)',
                isDecimal: true),
            const SizedBox(height: 24),

            _sectionHeader('AI / NVIDIA NIM'),
            TextFormField(
              controller: _apiKeyCtrl,
              obscureText: !_apiKeyVisible,
              decoration: InputDecoration(
                labelText: 'NIM API Key',
                hintText: 'nvapi-...',
                suffixIcon: IconButton(
                  icon: Icon(
                      _apiKeyVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _apiKeyVisible = !_apiKeyVisible),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _nimModel,
              decoration: const InputDecoration(labelText: 'Model'),
              items: _models
                  .map((m) => DropdownMenuItem<String>(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _nimModel = v!),
            ),
            const SizedBox(height: 12),
            _numberField(_nimTemperatureCtrl, 'Temperature (0.1 – 1.0)',
                isDecimal: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nimBaseUrlCtrl,
              decoration: const InputDecoration(labelText: 'Base URL'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppTheme.primaryGreen, letterSpacing: 1.2),
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl, String label,
      {bool isDecimal = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType:
          TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final n = isDecimal ? double.tryParse(v) : int.tryParse(v);
        if (n == null) return 'Invalid number';
        if (n <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }

  Widget _segmentedField({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: options.entries
              .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
              .toList(),
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}
