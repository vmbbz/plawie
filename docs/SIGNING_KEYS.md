# Signing Dependency-Pack Manifests

Private signing keys must never be committed, pasted into issue trackers, or
stored under the project directory. The previous key was exposed in Git history
and must be treated as compromised; rotate it before the next production
dependency-pack release.

The app pins the public key and key ID in
`lib/services/signing_keys.dart`. Store the matching private key only in the
release secret manager or an offline encrypted key store.

## Re-signing a release manifest

1. Create or retrieve the current Ed25519 private key outside this repository.
2. Run `docs/sign_manifest.py <project_dir> <secure-key-directory>`.
3. Verify the script changes `android-arm64-v8a.json` and
   `lib/services/signing_keys.dart` together.
4. Run the Flutter test suite, commit both files, and push the manifest before
   releasing an APK that pins the new public key.

The app accepts remote executable packs only when the manifest entry’s
canonical JSON verifies against the pinned Ed25519 key, then verifies the
archive and extracted-file SHA-256 values before installation.
