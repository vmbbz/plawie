import 'package:flutter/material.dart';
import '../../providers/gateway_provider.dart';
import '../../app.dart';
import '../../widgets/json_editor.dart';
import 'package:provider/provider.dart';

class ConfigEditor extends StatefulWidget {
  const ConfigEditor({super.key});

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  bool _isLoading = true;
  Map<String, dynamic>? _config;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke('config.get');
      
      if (result['ok'] == true) {
        setState(() => _config = result['payload']);
      } else {
        setState(() => _error = result['error']?['message'] ?? 'Failed to fetch config');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;

    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      // Using config.patch for safer partial updates if supported, 
      // but here we send the whole block for config.set as a fallback concept.
      final result = await provider.invoke('config.set', _config);
      
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${result['error']?['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConfig,
          ),
          if (!_isLoading && _config != null)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: JsonEditor(
                initialValue: _config!,
                onChanged: (newValue) {
                  _config = newValue;
                },
              ),
            ),
    );
  }
}
