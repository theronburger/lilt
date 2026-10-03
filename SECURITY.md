# Security

Report suspected vulnerabilities through [GitHub private vulnerability reporting](https://github.com/theronburger/lilt/security/advisories/new). Include the affected Lilt and macOS versions, impact, and safe reproduction steps using synthetic content. Do not post API keys, Keychain contents, or private screenshots in public issues.

Security fixes target the latest release. This is an early project without a guaranteed response time.

## Data and permissions

Lilt requires Screen Recording permission to capture the region you select. Screen images used for selection are transient; only the selected crop is saved with the reading. Vision OCR and Kokoro speech run locally. Optional AI filtering sends the selected crop to the configured HTTPS endpoint. It is off by default.

Saved provider keys use macOS Keychain. Keychain unlocks are explicit user actions. Local reading history and audio are ordinary files in the app’s Application Support directory and inherit the security of your macOS account. They are not separately encrypted by Lilt.

## Releases and updates

Initial releases are signed with a persistent self-signed Lilt release certificate. **They are not Apple-notarized.** Code signing preserves the publisher identity across these releases; it does not establish Apple trust.

Sparkle update archives and the update feed are signed with a separate Ed25519 key and verified before extraction. Published releases include SHA-256 checksums, dependency inventory, and GitHub build-provenance attestations. Download only from this repository’s Releases page or the linked project website.

Dependencies and release signing keys are separate from provider API keys. Neither provider keys nor reading history belong in diagnostics or issue attachments.
