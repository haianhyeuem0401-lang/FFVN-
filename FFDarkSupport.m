#import "FFDarkSupport.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <unistd.h>

#ifdef FF_3105_MCM
#import "FFKernelExploit.h"
#import "FFWorseQuery.h"
#endif

static NSString *FFDarkReadSysctlString(const char *name) {
    char buffer[256] = {0};
    size_t size = sizeof(buffer) - 1;
    if (sysctlbyname(name, buffer, &size, NULL, 0) != 0 || size == 0) return @"UNKNOWN";
    buffer[sizeof(buffer) - 1] = '\0';
    return [NSString stringWithUTF8String:buffer] ?: @"UNKNOWN";
}

NSString *FFDarkSupportIOSVersion(void) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.patchVersion > 0) {
        return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion];
    }
    return [NSString stringWithFormat:@"%ld.%ld",
        (long)version.majorVersion, (long)version.minorVersion];
}

NSString *FFDarkSupportDeviceModel(void) {
    struct utsname info;
    if (uname(&info) == 0 && info.machine[0]) {
        return [NSString stringWithUTF8String:info.machine] ?: FFDarkReadSysctlString("hw.model");
    }
    return FFDarkReadSysctlString("hw.model");
}

BOOL FFDarkSupportIsIPad(void) {
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

BOOL FFDarkSupportJailbreakDetected(void) {
    // Read-only path checks.  Nothing is loaded, executed or modified.
    return access("/var/jb", F_OK) == 0 ||
           access("/usr/libexec/cydia", F_OK) == 0 ||
           access("/Applications/Cydia.app", F_OK) == 0 ||
           access("/usr/sbin/sshd", F_OK) == 0;
}

NSString *FFDarkSupportPolicyTier(void) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
#ifdef FF_3105_MCM
    if (FFWorseQuerySupported()) return @"IOS 26/27 / WORSE_QUERY BUILD RANGE";
#endif
    if (version.majorVersion == 17) return @"IOS 17 / PRIMARY TARGET";
    if (version.majorVersion == 18) {
        if (version.minorVersion >= 4 && version.minorVersion <= 7) {
            return @"IOS 18.4-18.7 / PRIMARY TARGET";
        }
        return @"IOS 18 / PRIMARY TARGET";
    }
    if (version.majorVersion == 26) {
        return version.minorVersion == 0 ? @"IOS 26.0 / KEX RANGE"
                                         : @"IOS 26.1+ / LIMITED";
    }
    if (version.majorVersion >= 27) return @"IOS 27+ / UNTESTED";
    if (version.majorVersion >= 15) return @"IOS 15-16 / LEGACY";
    return @"UNSUPPORTED IOS";
}

NSString *FFDarkSupportDarkSwordReference(void) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    if (version.majorVersion == 18 && version.minorVersion >= 4 && version.minorVersion <= 7) {
        return @"REFERENCE ONLY / 18.4-18.7";
    }
    return @"NOT APPLICABLE";
}

NSString *FFDarkSupportKernelLabel(void) {
#ifdef FF_3105_MCM
    if (FFWorseQuerySupported()) return [NSString stringWithFormat:@"FILE ACCESS: %@", FFWorseQueryStatusText()];
    if (!FFKernelExploitSupported()) return @"3105 KEX: UNSUPPORTED ON THIS IOS";
    return [NSString stringWithFormat:@"3105 KEX: %@", FFKernelExploitStatusText()];
#else
    return @"3105 KEX: NOT COMPILED";
#endif
}

NSString *FFDarkSupportVerdictText(FFDarkSupportVerdict verdict) {
    switch (verdict) {
        case FFDarkSupportVerdictPreviewReady: return @"PREVIEW READY";
        case FFDarkSupportVerdictLimited: return @"LIMITED";
        case FFDarkSupportVerdictBlocked: return @"BLOCKED";
    }
    return @"BLOCKED";
}

static NSString *FFDarkGameName(NSString *gameIdentifier) {
    if ([gameIdentifier isEqualToString:@"com.dts.freefireth"]) return @"FREE FIRE TH";
    if ([gameIdentifier isEqualToString:@"com.dts.freefiremax"]) return @"FREE FIRE MAX";
    return gameIdentifier.length ? gameIdentifier : @"NO GAME SELECTED";
}

NSDictionary<NSString *, id> *FFDarkSupportReport(NSString *gameIdentifier, BOOL licenseActive) {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    BOOL iosAtLeast15 = version.majorVersion >= 15;
    BOOL jailbroken = FFDarkSupportJailbreakDetected();
    BOOL previewPossible = iosAtLeast15 && licenseActive;

    FFDarkSupportVerdict verdict = FFDarkSupportVerdictBlocked;
    if (previewPossible) {
        verdict = FFDarkSupportVerdictPreviewReady;
    } else if (iosAtLeast15) {
        verdict = FFDarkSupportVerdictLimited;
    }

    NSMutableArray<NSString *> *notes = [NSMutableArray array];
    [notes addObject:@"DARK AIM/ESP and the glowing floating button live in the separate Free Fire 1.132.1 IPA with the injected DARK dylib. This app is the companion configurator and button preview."];
    [notes addObject:@"This companion app still never reads Free Fire memory and never injects input; the in-game dylib does the drawing and the aim assist."];
    [notes addObject:@"The DARK Free Fire IPA is unsigned: re-sign the whole app with ESign, Sideloadly or TrollStore. The dylib is ad-hoc signed but iOS still needs the full app signature."];
    [notes addObject:@"The DARK dylib requires an active FAKHER VIP server lease. Open LICENSE in the in-game panel and enter your key, otherwise AIM/ESP are forced off every frame."];
#ifdef FF_3105_MCM
    if (FFWorseQuerySupported()) {
        [notes addObject:@"Container actions use worse_query and require a provisioned App Group. iOS 27.3 is allowed only for beta 1 build 24C5037i. Setup does not prove the target is writable; the app checks target access separately."];
    } else
#endif
    if (version.majorVersion == 26 && version.minorVersion >= 1) {
        [notes addObject:@"iOS 26.1+ is outside the bundled 3105 offset table. The in-game overlay itself does not use the kernel exploit, but old container actions may fail."];
    } else if (version.majorVersion >= 27) {
        [notes addObject:@"iOS 27+ is untested. Keep a backup device and do not rely on old container actions."];
    }
    if (jailbroken) {
        [notes addObject:@"A jailbreak root is visible. The DARK IPA does not require jailbreak; TrollStore or ESign can install it on stock iOS."];
    }
    [notes addObject:@"DarkSword is used only as a version-policy reference. It is a WebKit exploit chain for iOS 18.4-18.7, not an overlay or ESP engine, and it is patched on newer releases."];
    [notes addObject:@"No anti-cheat bypass is claimed. Use a test account: a modified game client carries a ban risk."];

    return @{
        @"verdict": @(verdict),
        @"verdict_text": FFDarkSupportVerdictText(verdict),
        @"ios": FFDarkSupportIOSVersion(),
        @"device": FFDarkSupportDeviceModel(),
        @"ipad": @(FFDarkSupportIsIPad()),
        @"policy": FFDarkSupportPolicyTier(),
        @"darksword": FFDarkSupportDarkSwordReference(),
        @"kernel": FFDarkSupportKernelLabel(),
        @"jailbreak": @(jailbroken),
        @"license_active": @(licenseActive),
        @"preview_possible": @(previewPossible),
        @"live_overlay_possible": @YES,
        @"game": FFDarkGameName(gameIdentifier),
        @"app_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"UNKNOWN",
        @"app_build": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"UNKNOWN",
        @"notes": notes,
    };
}
