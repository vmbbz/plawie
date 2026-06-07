import 'package:clawa/services/dependency_pack_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = DependencyPackManifestPolicy(
    supportedAbis: {'arm64-v8a'},
  );

  test('accepts a complete hash-verified Android dependency pack manifest', () {
    final entry = DependencyPackManifestEntry.fromJson(_validPack());

    final validation = entry.validate(policy);

    expect(validation.ok, isTrue);
    expect(validation.errors, isEmpty);
    expect(entry.id, 'android-cli-core-pack');
    expect(entry.abis, contains('arm64-v8a'));
    expect(entry.files.single.sha256, _sha);
  });

  test('rejects remote packs without a package hash', () {
    final json = _validPack()..remove('sha256');
    final entry = DependencyPackManifestEntry.fromJson(json);

    final validation = entry.validate(policy);

    expect(validation.ok, isFalse);
    expect(validation.errorCodes, contains('missing_sha256'));
  });

  test('rejects packs for unsupported Android ABIs', () {
    final json = _validPack()
      ..['abi'] = ['x86_64']
      ..['abis'] = ['x86_64'];
    final entry = DependencyPackManifestEntry.fromJson(json);

    final validation = entry.validate(policy);

    expect(validation.ok, isFalse);
    expect(validation.errorCodes, contains('unsupported_abi'));
  });

  test('rejects unsigned remote executable packs', () {
    final json = _validPack()
      ..remove('signature')
      ..['files'] = [
        {
          'path': 'bin/blu',
          'sha256': _sha,
          'sizeBytes': 123,
          'executable': true,
        }
      ];
    final entry = DependencyPackManifestEntry.fromJson(json);

    final validation = entry.validate(policy);

    expect(validation.ok, isFalse);
    expect(validation.errorCodes, contains('missing_signature'));
  });

  test('rejects unsafe install and file paths', () {
    final json = _validPack()
      ..['installPath'] = '../outside'
      ..['files'] = [
        {
          'path': '../bin/blu',
          'sha256': _sha,
          'sizeBytes': 123,
        }
      ];
    final entry = DependencyPackManifestEntry.fromJson(json);

    final validation = entry.validate(policy);

    expect(validation.ok, isFalse);
    expect(validation.errorCodes, contains('unsafe_install_path'));
    expect(validation.errorCodes, contains('unsafe_file_path'));
  });
}

const _sha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _validPack() => {
      'id': 'android-cli-core-pack',
      'version': '2026.06.07',
      'source': 'remote',
      'url': 'https://downloads.openclaw.example/android-cli-core-pack.zip',
      'abi': ['arm64-v8a'],
      'abis': ['arm64-v8a'],
      'sizeBytes': 123456,
      'sha256': _sha,
      'signature': {
        'type': 'ed25519',
        'value': 'signed-pack-fixture',
        'keyId': 'openclaw-test',
      },
      'archiveType': 'zip',
      'installPath': 'dependencies/packs/android-cli-core-pack',
      'files': [
        {
          'path': 'bin/blu',
          'sha256': _sha,
          'sizeBytes': 123,
          'executable': true,
        }
      ],
      'smokeCommand': {
        'command': 'blu',
        'args': ['--version'],
      },
      'rollback': {
        'strategy': 'remove_install_path',
      },
      'provides': {
        'bins': ['blu'],
      },
    };
