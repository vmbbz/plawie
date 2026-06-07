import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/nano_pdf_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nano-pdf extracts bounded text from provided PDF bytes', () async {
    final frame = await NanoPdfCapability().handle('nano-pdf.extract', {
      'pdfBase64': _simplePdfBase64(),
      'maxChars': 80,
    });

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['runtime'], 'app-native-pdf-text');
    expect(payload['mode'], 'best-effort-text-pdf');
    expect(payload['text'], contains('Gateway tools pass'));
    expect(payload['text'], contains('Nano PDF adapter'));
    expect(payload['chars'], lessThanOrEqualTo(80));
    expect(payload['extractedBlockCount'], greaterThanOrEqualTo(1));
  });

  test('nano-pdf rejects missing, invalid, and encrypted PDFs', () async {
    final capability = NanoPdfCapability();

    final missing = await capability.handle('nano_pdf_extract', {});
    expect(missing.isError, isTrue);
    expect(missing.error?['code'], 'MISSING_PDF');

    final invalid = await capability.handle('nano-pdf.extract', {
      'pdfBase64': base64Encode(utf8.encode('not a pdf')),
    });
    expect(invalid.isError, isTrue);
    expect(invalid.error?['code'], 'INVALID_PDF');

    final encrypted = await capability.handle('nano-pdf.extract', {
      'pdfBase64': base64Encode(latin1.encode('%PDF-1.4\n/Encrypt 3 0 R\n')),
    });
    expect(encrypted.isError, isTrue);
    expect(encrypted.error?['code'], 'ENCRYPTED_PDF');
  });

  test('nano-pdf is classified as app-native ready optional', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('nano-pdf')!;

    expect(entry.status, AndroidSkillSupportStatus.readyOptional);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.appNativeTool);
    expect(entry.requiredPacks, isEmpty);
    expect(entry.launchCritical, isFalse);
  });

  test('nano-pdf is advertised in native tools catalog with byte schema',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final nanoPdf = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'nano-pdf');
    final schema = nanoPdf['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;

    expect(nanoPdf['description'], contains('PDF'));
    expect(properties['pdfBase64'], isA<Map<String, dynamic>>());
    expect(schema['required'], contains('pdfBase64'));
  });

  test('nano-pdf is allowed as an intentional mobile node command', () {
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll([
        'nano-pdf',
        'nano_pdf',
        'nano-pdf.extract',
        'nano_pdf_extract',
      ]),
    );
  });

  test('explicit nano-pdf prompt routes through Gateway-visible chunks',
      () async {
    final execution = await AppNativeChatToolRouter.instance
        .tryExecuteRequiredToolIntent('nano-pdf base64 ${_simplePdfBase64()}');

    expect(execution, isNotNull);
    expect(execution!.toolName, 'nano-pdf');
    expect(execution.input['pdfBase64'], isA<String>());
    expect(execution.ok, isTrue);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:nano-pdf:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:nano-pdf:'));
    expect(execution.visibleText, startsWith('nano-pdf extracted '));
  });

  test('AgentSkillServer routes nano-pdf execution to NanoPdfCapability',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'nano-pdf':"));
    expect(source, contains("'nano-pdf': 'nano-pdf.extract'"));
    expect(source, contains("_nanoPdfCapability.handle("));
  });
}

String _simplePdfBase64() => base64Encode(latin1.encode('''
%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /Contents 4 0 R >> endobj
4 0 obj << /Length 95 >> stream
BT
/F1 12 Tf
72 720 Td
(Gateway tools pass) Tj
0 -20 Td
[(Nano) 120 ( PDF adapter)] TJ
ET
endstream
endobj
%%EOF
'''));
