# Releases

Lilt currently ships for Apple Silicon on macOS 15 or newer. The release contains
Python, the Kokoro model, every supported voice, and voice previews. It makes no
model downloads on a user's Mac. Development builds still use `.venv` for a faster
edit/build cycle, and keep a separate identity and settings.

## Everyday releases

1. Merge changes with conventional commit titles, such as `fix: restore playback`.
2. Release Please opens a version/changelog PR. Review and merge it.
3. The release workflow builds, tests and publishes a ZIP, signed Sparkle feed,
   dependency SBOM, checksums, and GitHub provenance attestations.

For the first release or a manual retry, create the matching `vVERSION` Git tag
or dispatch the Release workflow with an existing version tag. The workflow
checks the tag against `VERSION`. It does not create a release from an arbitrary
branch. Release Please may create a draft first; the successful publisher makes
it public only after all package checks pass.

## Signing setup

The GitHub `release` environment contains:

| Secret | Value |
| --- | --- |
| `LILT_CERTIFICATE_BASE64` | Base64 PKCS#12 release certificate and private key |
| `LILT_CERTIFICATE_PASSWORD` | Password for that PKCS#12 file |
| `LILT_SIGNING_IDENTITY` | Persistent code-signing identity name |
| `SPARKLE_PRIVATE_KEY` | Sparkle Ed25519 private key, base64 |
| `HOMEBREW_TAP_DEPLOY_KEY` | Repository-scoped deploy key for the Homebrew tap |

`Resources/SparklePublicKey.txt` holds the corresponding public key. Never commit
private keys. Back up both signing keys securely: changing code identity can
require a new Screen Recording grant; losing the update key can prevent existing
users from receiving updates. Release workflow runs need access for `v*` tags
and `main` (Release Please's reusable workflow).

Keep an encrypted certificate backup using Keychain Access's Export Items action;
keep the password separately. Sparkle's `generate_keys` utility supports exporting
its dedicated key for an encrypted backup. Never paste either private key into an
issue, pull request, or terminal output. The release environment may require the
maintainer's approval before signing runs begin.

The initial certificate is self-signed, not issued by Apple. That keeps an app's
identity stable between releases and authenticates Sparkle updates, but it does
**not** satisfy Gatekeeper or notarization. Users need the documented macOS
Privacy & Security → Open Anyway flow for this early version. Never ask them to
disable Gatekeeper globally.

Once Developer ID is available, replace the release certificate secrets and add
`NOTARY_PRIVATE_KEY`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID` for App Store Connect.
Keep the Sparkle key unchanged for that migration. The workflow then notarizes
and staples the app before signing its update archive. Test a real old-to-new
update before publishing the certificate migration; macOS may ask for Screen
Recording permission again because its code identity changed.

## Local package check

```sh
SIGNING_IDENTITY='Lilt Release' scripts/build-release.sh
```

Requires macOS on Apple Silicon, Swift/Xcode command-line tools, `uv`, and the
persistent certificate in Keychain. This builds `dist/Lilt.app` without touching
an installed application. The smoke check copies it to a different path and
synthesizes with American and British voices using an empty cache in offline
mode. It verifies no runtime path or symlink points outside the bundle.

Python comes from a checksum-verified python-build-standalone archive;
`Resources/runtime-lock.json` pins that download and the Kokoro model revision.
`Speech/requirements.txt` pins Python dependencies. To update those, change the
pins, rebuild, run the audit and portable smoke check, and listen to representative
speech samples. The runtime and model are release assets, never Git source files.

The eSpeak 1.52 source has a 160-character default data-path limit on macOS.
`scripts/prepare-espeak.py` compiles the pinned source with its supported
`N_PATH_HOME=4096` option so moving the app or Gatekeeper translocation does not
break speech. It replaces the wheel's native library, keeping the same voice
data. The source and build recipe are included in the corresponding-source
release archive. See [LICENSING.md](LICENSING.md).

## Checks and limitations

- Swift and Python tests run for pushes and pull requests.
- Dependabot maintains Swift, Python and Actions dependencies weekly.
- Dependency review blocks new high-severity vulnerable dependencies in PRs.
- CI validates Python dependency constraints and pip-audit checks the pins;
  CodeQL scans Swift and Python weekly.
- Sparkle verifies signed feeds and archives before extraction. Dev builds do not
  check the production feed.
- The build verifies nested signatures and checks for accidental signing-identity
  changes before replacing an installed app.
- Successful releases update `theronburger/homebrew-tap` using its scoped deploy key.
- No Intel package is currently published.
