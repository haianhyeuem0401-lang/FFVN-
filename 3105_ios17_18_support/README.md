# 3105 - iOS 17/18 source support

This patch extends the `ExploitSupportPolicy` in `0xjohnnydev/3105` so the
existing kernel-offset table can be used on iOS 17 and 18.

## What is enabled

- iOS 17.0 - 17.7.x
- iOS 18.0 - 18.7.x
- iOS 26.0 - 26.6.1 (unchanged)
- iOS 27 beta 1-4 build whitelist (unchanged)

The offsets are already present in `ThreeOneOSFive/kexploit/offsets.m`
(17.0, 17.1-17.3, 17.4-17.7, 18.0, 18.1-18.3, 18.4-18.5, 18.6-18.7 and
26.0.x blocks). The only blocker was the policy gate.

## iOS 16

iOS 16 is **not enabled** by this patch. `offsets.m` starts at
`SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"17.0")` and has no iOS 16 kernel
offset table. The app deployment target is 16.0, so it can be installed on
iOS 16, but the kexploit/container features cannot work there without a new
iOS 16 offset table and device testing. Neither `3105`, `FilzaSlop`,
`FilzaJailedDS` nor `FJ-iOS15` provides those offsets.

## Build

This patch is source-only. Building a signed IPA requires macOS + Xcode:

```
xcodebuild -project ThreeOneOSFive.xcodeproj   -scheme ThreeOneOSFive   -configuration Release   -sdk iphoneos   -archivePath build/ThreeOneOSFive.xcarchive   archive
```

Then export/install with the provisioning profile used by the target device.
It was not built or device-tested in this environment (Windows, no Xcode).

## Apply

Copy the two files under `ThreeOneOSFive/` into the repository, or run:

```
git apply ios17_18_support.patch
```

The policy change only enables versions whose offsets already exist. Treat
the 17/18 enablement as beta until a real-device boot/exploit test passes.
