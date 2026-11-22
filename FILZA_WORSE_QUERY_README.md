# Filza worse_query integration

Added 2026-11-12. This project now compiles forcequitOS/worse_query into the
app and routes its container grants through that backend on eligible builds.
It is a sandbox extension primitive, not a kernel exploit or a full jailbreak.

## Version gate

| OS | Policy |
| --- | --- |
| iOS/iPadOS 26.0 through 26.7.2 | Enable worse_query |
| iOS/iPadOS 27.0 through 27.2.1 | Enable worse_query |
| iOS/iPadOS 27.3 beta 1, build 24C5037i | Enable worse_query only for this exact build |
| Other 27.3 builds, 27.4+, 28+ | Disabled until verified upstream |
| Earlier OS | Existing direct/MCM fallback; optional legacy kernel sources if supplied |

Published compatibility is not a successful device test of this application.
The final container identity and read/write verification still determine
whether Apply is available. A setup or grant error is never treated as success.

Sources checked:
- https://github.com/forcequitOS/worse_query
- https://github.com/jailbreakdotparty/Erosion (27.2.1 and 27.3 beta 1 build list)
- https://git.jbjflab.top/admin/filza27.2

## Signing: required on a normal device

1. Use your app's own bundle identifier and register a dedicated App Group
   for it in the signing account. The legacy `com.apple.mobile.MobileHouseArrest`
   identity is not required by worse_query.
2. Use a provisioning profile that authorizes that app identifier AND group.
3. Preserve `com.apple.security.application-groups` when signing the IPA.
   `entitlements-worse-query.example.plist` shows the shape; replace its example
   group with the actual provisioned group. Text in a plist cannot grant access.
4. The app discovers signed groups at runtime. If your signer cannot expose
   entitlement introspection, set `FFWorseQueryAppGroup` in Info.plist to the
   actual group; it is accepted only if iOS opens its container.

Re-signing without a real App Group will display a setup error and prevent the
new backend from obtaining container access. Installing Filza separately does
not transfer its grants to this app. Use a dedicated group: the primitive
temporarily uses its Library/Caches, which the integration backs up and restores.

## Build

Use the existing entry points, for example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_clean.ps1 -FilzaIpa "C:\path\FilzaSlop_1.0.3.ipa"
```

All five PowerShell build entry points compile and link the new sources via
`build_access_backend.ps1`. The old donor is still used for the protected legacy
bridge; worse_query is compiled directly and does not come from that donor.
The supplied ZIP contains neither the donor IPA nor the old `kexploit/` tree.
Missing legacy kernel sources now disable that optional backend instead of
breaking the build or claiming iOS 27 kernel support. If restoring that tree,
use the original matching sources and offset table.

The activation URL is a placeholder in the supplied main.m; restore your real
activation configuration before building a working online client. Publish the
newly generated release manifest to your activation service as required by the
existing build guide. No live server changes were performed here.

## Behavior

- On eligible systems the compatibility wrapper initializes the App Group,
  without running the old kernel chain.
- LaunchServices is tried for the selected game's data-container path. Its
  UUID/path and container identity are checked before use. Existing bounded
  MCM/metadata/inode fallbacks remain available.
- All existing grant calls, including shader paths, route to worse_query.
  Query flags account for the iOS 26 difference and retry the alternative.
- Queries are serialized. Successful extension handles are retained; a cached
  grant is reused only after opening the requested path succeeds.
- Existing App Group caches are moved aside and restored around each query.
  An interrupted backup is recovered on startup; conflicting files are preserved.
- The status distinguishes `WQ READY TO QUERY` from `WQ GRANTS ACTIVE`.
  Only the existing target read/write verifier controls operational readiness.

## Validation

`tests/test_worse_query_policy.c` checks release/beta/build boundaries:

```sh
cc -std=c11 -Wall -Wextra -Werror tests/test_worse_query_policy.c -o /tmp/ff-wq-policy
/tmp/ff-wq-policy
```

No signed IPA or on-device runtime test is included. Real-device validation
must cover a valid profile, a profile without App Groups, selecting each game,
Apply/restore, and retention of pre-existing App Group cache files.

## Upstream source and license

`vendor/worse_query/` includes the upstream GPL-3.0-or-later notices, license,
README and pinned commit identifier. Local primitive changes resolve XPC calls
dynamically for public-SDK compatibility, balance XPC references, and free the
query/clean up on symlink-creation failure. The integration is new code;
attribution and the supplied source are retained for distribution.
