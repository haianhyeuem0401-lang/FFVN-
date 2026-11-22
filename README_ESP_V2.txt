FF CACHE PROTECTED PANEL — ESP P8 V2 (AIM SCOP + ESP)

This build changes only the ESP package parser/installer:
- P8 remains ESP.
- FFTH only.
- New package manifest version: 2.
- New package contains exactly two files:
  Documents/Assembly-CSharp-patch.bytes
  Documents/localConfig.json
- The patch payload minimum size is now 1 KB instead of 1 MB.
- Existing license/session/integrity/feature authorization flow is unchanged.
- App version/build remain 5.5 / 41 for compatibility with the existing builder verifier.

After building/signing the new IPA, update the server single-release integrity manifest to the new IPA fingerprint, then replace the server ESP_package.ffesp with the V2 payload.
