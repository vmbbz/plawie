import json, hashlib, base64
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

project_dir = sys.argv[1]
tmp_dir = sys.argv[2]

with open(project_dir + '/android-arm64-v8a.json', 'r') as f:
    manifest = json.load(f)

with open(tmp_dir + '/signing-private.pem', 'rb') as f:
    private_key = serialization.load_pem_private_key(f.read(), password=None)

with open(tmp_dir + '/signing-public.pem', 'rb') as f:
    pub_pem = f.read()
keyId = hashlib.sha256(pub_pem).hexdigest()[:16]

print('keyId: ' + keyId)

for pack in manifest['packs']:
    pack_copy = {k: v for k, v in pack.items() if k != 'signature'}
    canonical = json.dumps(
        pack_copy,
        sort_keys=True,
        separators=(',', ':'),
        ensure_ascii=False,
    )
    pid = pack['id']
    print('Signing: ' + pid + ' payload_len=' + str(len(canonical)))
    signature = private_key.sign(canonical.encode('utf-8'))
    sig_b64 = base64.b64encode(signature).decode('utf-8')
    pack['signature'] = {
        'type': 'ed25519',
        'value': sig_b64,
        'keyId': keyId
    }

with open(project_dir + '/android-arm64-v8a.json', 'w') as f:
    json.dump(manifest, f, indent=2)

# Also write the public key Dart constant file
pub_pem_str = pub_pem.decode().strip()
dart_content = """// Auto-generated signing key identifier and public key.
// DO NOT COMMIT the private key (signing-private.pem) to git.

/// The keyId embedded in dependency pack manifests.
/// Corresponds to the first 16 hex chars of SHA256(public_key_pem).
const String kDependencyPackSigningKeyId = '""" + keyId + """';

/// The ed25519 public key (PEM) for verifying dependency pack signatures.
/// Keep this in sync with signing-public.pem.
const String kDependencyPackPublicKey = r'''""" + pub_pem_str + """''';
"""

with open(project_dir + '/lib/services/signing_keys.dart', 'w') as f:
    f.write(dart_content)

print('Created signing_keys.dart')
print('Done!')
