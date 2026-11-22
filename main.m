#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <sys/fsgetpath.h>
#import <sys/stat.h>
#import <errno.h>
#import <fcntl.h>
#import <stdbool.h>
#import <stdarg.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import "ProtectedConfig.h"
#ifdef FF_3105_MCM
#import "FFKernelExploit.h"
#import "FFWorseQuery.h"
#endif
#ifdef FF_DARK_BETA
#import "FFDarkViewController.h"
#endif
#ifdef FF_MATCH_STATE
#import "FFMatchStateManager.h"
#import "FFMatchStateViewController.h"
#endif

#ifndef LC_DYLD_EXPORTS_TRIE
#define LC_DYLD_EXPORTS_TRIE (0x33 | LC_REQ_DYLD)
#endif

static NSString *const FFBookmarkKey = @"FFSelectedFolderBookmark";
static NSString *const FFBackupSuffix = @".ffbackup";
static NSString *const FFActiveProfileKey = @"FFActiveProfile";
static NSString *const FFModSkinStateKey = @"FFModSkinState";
static NSString *const FFKnownLicenseExpiryKey = @"FFKnownLicenseExpiry";
static NSString *const FFKeychainService = @"com.fakherddin.ffcachemanager.protected";
static NSString *const FFDeviceAccount = @"installation-id";
static NSString *const FFLegacyLicenseAccount = @"owner-license";
static NSString *const FFAccessTokenAccount = @"session-access-token";
static NSString *const FFRefreshTokenAccount = @"session-refresh-token";
static NSString *const FFAutoClipboardLicenseDigestKey = @"FFAutoClipboardLicenseDigest";
// Activation endpoint obfuscated with a rotating multi-byte mask. This only
// reduces static string exposure; authorization secrets remain server-side.
// Server endpoint REMOVED from this clean project copy. Re-encode the
// real activation URL here when building a working IPA.
static const uint8_t FFENC_APIBaseURL[18] = {
    0xC2,0x6E,0x86,0x35,0xE2,0x0A,0x23,0xA4,0x6E,0xFA,
    0x64,0xD7,0x62,0xDC,0x64,0x82,0x26,0xE3
};
static const uint8_t FFAPIURLMask[13] = {
    0x91,0x2B,0xD4,0x63,0xA7,0x58,0x0E,0xF1,0x3C,0xB6,0x49,0x85,0x27
};

static NSString *FFDecodeMaskedString(const uint8_t *bytes, size_t len,
                                      const uint8_t *mask, size_t maskLen) {
    if (!bytes || !len || !mask || !maskLen) return nil;
    NSMutableData *out = [NSMutableData dataWithLength:len];
    uint8_t *dst = out.mutableBytes;
    for (size_t i = 0; i < len; ++i) dst[i] = bytes[i] ^ mask[i % maskLen];
    return [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
}

static NSString *FFAPIBaseURL(void) {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cached = FFDecodeMaskedString(FFENC_APIBaseURL, sizeof(FFENC_APIBaseURL),
                                      FFAPIURLMask, sizeof(FFAPIURLMask));
    });
    return cached;
}
static NSString *const FFBundleIDFreeFireTH = @"com.dts.freefireth";
static NSString *const FFBundleIDFreeFireMAX = @"com.dts.freefiremax";
// NEW local shader feature (replaces the old server-catalog hologram).
// The shader payloads are bundled in the app, installed to the game container,
// and automatically reverted 60 seconds after activation.
static NSString *const FFNewGunShaderFilename = @"shaders.P0K3UG2TfecMBhWMMV~2Fu8ReudIk~3D";
static NSString *const FFNewSkinShaderFilename = @"optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D";
static NSString *const FFShaderRevertStateKey = @"FFShaderRevertPersistentState";
// Owner-provided game container fast paths (provisioned devices only).
static NSString *const FFUserFallbackContainerPath =
    @"/var/mobile/Containers/Data/Application/30B5221E-51A7-47FB-BDCD-36AFA3B2DED1";
static NSString *const FFHologramShaderFilename = @"shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D";
static NSString *const FFThreeDShaderFilename = @"optionalavatarres_commonab_shader";
static NSString *const FFHologramStateKey = @"FFHologramPersistentState";

// Jailbroken-install fast path: when the app runs unsandboxed (no-sandbox
// entitlement honored by a jailbreak/AMFI patch, or an already-completed
// sandbox escape), it can list the global application-containers directory.
// In that state every file operation works directly and the kernel exploit
// is never needed - skip starting it and skip all kernel waits.
static BOOL FFHasFullFilesystemAccess(void) {
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *root in @[
        @"/private/var/mobile/Containers/Data/Application",
        @"/var/mobile/Containers/Data/Application",
    ]) {
        NSArray<NSString *> *entries = [manager contentsOfDirectoryAtPath:root error:nil];
        if (entries.count >= 2) return YES;
    }
    return NO;
}
// The channel URL and verification bot are delivered exclusively by the
// signed server status response.  No fallback is compiled into the app: if the
// server config is unavailable, channel actions fail closed instead of trusting
// a locally editable link.
// Recent game builds place optional-avatar bundles directly under Optional/ios;
// older builds retain the optionalavatarres child directory.  Both are explicit,
// allowed locations and target discovery stays limited to optionalab_avatar_*.
static NSString *const FFModSkinTargetRelativePath = @"Documents/contentcache/Optional/ios";
static NSString *const FFModSkinTargetLegacyRelativePath = @"Documents/contentcache/Optional/ios/optionalavatarres";
// The owner supplied this already-authorized game container after its UUID
// changed.  It is a narrow fallback for this device only; normal builds still
// resolve the selected game's data container first.
#ifdef FF_OFFLINE_BUILD
static NSString *const FFModSkinOwnerFallbackDirectory = @"/var/mobile/Containers/Data/Application/2E3FBF37-14F3-4B88-AC96-F89F83261E19/Documents/contentcache/Optional/ios";
#else
// Release builds intentionally have no owner-specific fallback path.
// Use a nonnull empty string because the server builder compiles with -Werror/-Wnonnull.
static NSString *const FFModSkinOwnerFallbackDirectory = @"";
#endif
static NSString *const FFChannelLinkFallback = @"https://t.me/+b3ZX2tT6XR02NTQ0";
static NSString *const FFChannelBotUsernameFallback = @"FilzaFiles_bot";

static NSURL *FFFindGameAssetBundles(NSURL *root, NSError **error);

typedef void (*MCMFilzaStartFunction)(void);
typedef void (*MCMFilzaSetUnrestrictedFilesystemFunction)(BOOL);
typedef NSString *(*MCMFilzaDataContainerPathFunction)(NSString *, NSString **);
typedef NSString *(*MCMFilzaVirtualRootFunction)(void);

#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
typedef void *(*FF3105QueryCreateFunction)(void);
typedef void (*FF3105QuerySetClassFunction)(void *, uint64_t);
typedef void (*FF3105QuerySetIdentifiersFunction)(void *, void *);
typedef void (*FF3105QuerySetFlagsFunction)(void *, uint64_t);
typedef void (*FF3105QuerySetPartFunction)(void *, uint64_t);
typedef void (*FF3105QuerySetPartDomainFunction)(void *, const char *);
typedef void *(*FF3105QueryGetResultFunction)(void *);
typedef void *(*FF3105QueryGetErrorFunction)(void *);
typedef void (*FF3105QueryFreeFunction)(void *);
typedef const char *(*FF3105ObjectGetPathFunction)(void *);
typedef void *(*FF3105ObjectCopyFunction)(void *);
typedef char *(*FF3105CopySandboxTokenFunction)(void *);
typedef BOOL (*FF3105ActivateSandboxExtensionFunction)(void *, uint32_t);
typedef int64_t (*FF3105SandboxExtensionConsumeFunction)(const char *);
typedef void (*FF3105ObjectFreeFunction)(void *);
typedef int (*FF3105ErrorPOSIXFunction)(void *);
typedef const char *(*FF3105ErrorMessageFunction)(void *);
typedef void *(*FF3105XPCStringCreateFunction)(const char *);
typedef void (*FF3105XPCReleaseFunction)(void *);

typedef struct {
    void *handle;
    FF3105QueryCreateFunction queryCreate;
    FF3105QuerySetClassFunction querySetClass;
    FF3105QuerySetIdentifiersFunction querySetIdentifiers;
    FF3105QuerySetIdentifiersFunction querySetGroupIdentifiers;
    FF3105QuerySetFlagsFunction querySetFlags;
    FF3105QuerySetPartFunction querySetPart;
    FF3105QuerySetPartDomainFunction querySetPartDomain;
    FF3105QueryGetResultFunction queryGetSingleResult;
    FF3105QueryGetErrorFunction queryGetLastError;
    FF3105QueryFreeFunction queryFree;
    FF3105ObjectGetPathFunction objectGetPath;
    FF3105ObjectCopyFunction objectCopy;
    FF3105CopySandboxTokenFunction copySandboxToken;
    FF3105ActivateSandboxExtensionFunction activateSandboxExtension;
    FF3105SandboxExtensionConsumeFunction sandboxExtensionConsume;
    FF3105ObjectFreeFunction objectFree;
    FF3105ErrorPOSIXFunction errorPOSIX;
    FF3105ErrorMessageFunction errorMessage;
    FF3105XPCStringCreateFunction xpcStringCreate;
    FF3105XPCReleaseFunction xpcRelease;
} FF3105MCMAPI;

static FF3105MCMAPI FF3105API;
static NSString *FF3105MCMContainerPath(NSString *identifier, NSString **detail);
#endif

static void *FFProtectedCoreHandle = NULL;
static MCMFilzaStartFunction FFMCMStart = NULL;
static MCMFilzaSetUnrestrictedFilesystemFunction FFMCMSetUnrestrictedFilesystem = NULL;
static MCMFilzaDataContainerPathFunction FFMCMDataContainerPath = NULL;
static MCMFilzaVirtualRootFunction FFMCMVirtualRoot = NULL;

static NSString *ZXDigest(NSData *data);
static BOOL ZXIsSHA256(NSString *value);
static NSDictionary<NSString *, NSString *> *FFGameDefinition(NSString *bundleIdentifier);
static BOOL FFRestoreOriginal(NSURL *target, NSError **error);
static BOOL FFSkinFilenameIsSafe(NSString *filename);
static BOOL FFDataLooksLikeESPPackage(NSData *data, NSString *gameIdentifier);
static BOOL FFSecuritySensitiveOperationAllowed(void);
static BOOL FFURLTargetsOfficialAPI(NSURL *url);

// The user may copy a license before opening the app.  Accept only the same
// canonical shape validated by the activation service; do not retain the raw
// license in defaults or Keychain.
static NSString *FFClipboardLicenseKey(void) {
    NSString *value = UIPasteboard.generalPasteboard.string;
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *candidate = [[value stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"^[A-Z0-9]{4,12}(?:-[A-Z0-9]{4,8}){3,5}$"
                         options:0 error:nil];
    NSRange range = NSMakeRange(0, candidate.length);
    return candidate.length && [expression firstMatchInString:candidate options:0 range:range]
        ? candidate : nil;
}

static NSString *FFActiveProfileDefaultsKey(NSString *gameIdentifier) {
    if (!FFGameDefinition(gameIdentifier)) return nil;
    return [NSString stringWithFormat:@"%@.%@", FFActiveProfileKey, gameIdentifier];
}

static NSString *FFModSkinDefaultsKey(NSString *gameIdentifier) {
    if (!FFGameDefinition(gameIdentifier)) return nil;
    return [NSString stringWithFormat:@"%@.%@", FFModSkinStateKey, gameIdentifier];
}

static UIColor *FFVIPGold(void) {
    return [UIColor colorWithRed:0.10 green:0.10 blue:0.10 alpha:1.00];
}

static UIColor *FFVIPBackground(void) {
    return [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.00];
}

static UIColor *FFVIPPanel(void) {
    return [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.00];
}

static UIColor *FFStatusCyan(void) {
    return [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:1.00];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *FFSupportedGames(void) {
    static NSArray<NSDictionary<NSString *, NSString *> *> *games;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        games = @[
            @{
                @"id": @"FREE_FIRE_TH",
                @"displayName": @"FREE FIRE TH",
                @"subtitle": @"TH / NORMAL",
                @"bundleIdentifier": FFBundleIDFreeFireTH,
            },
            @{
                @"id": @"FREE_FIRE_MAX",
                @"displayName": @"FREE FIRE MAX",
                @"subtitle": @"MAX",
                @"bundleIdentifier": FFBundleIDFreeFireMAX,
            },
        ];
    });
    return games;
}

static NSDictionary<NSString *, NSString *> *FFGameDefinition(NSString *bundleIdentifier) {
    for (NSDictionary<NSString *, NSString *> *game in FFSupportedGames()) {
        if ([game[@"bundleIdentifier"] isEqualToString:bundleIdentifier]) return game;
    }
    return nil;
}

static NSSet<NSString *> *FFLocalFeaturesForGame(NSString *bundleIdentifier) {
    if ([bundleIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        return [NSSet setWithArray:@[@"BODY", @"DRAG", @"NECK", @"CHEST", @"MAGIC", @"HOLOGRAM_GUN", @"SKIN_HOLO"]];
    }
    if ([bundleIdentifier isEqualToString:FFBundleIDFreeFireMAX]) {
        return [NSSet setWithArray:@[@"BODY", @"DRAG", @"NECK", @"CHEST"]];
    }
    return [NSSet set];
}

#ifdef FF_OFFLINE_BUILD
static NSSet<NSString *> *FFBundledOfflineFeatures(void) {
    static NSSet<NSString *> *features;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableSet<NSString *> *available = [NSMutableSet set];
        for (NSString *feature in @[@"BODY", @"DRAG", @"NECK", @"CHEST"]) {
            NSString *path = [NSBundle.mainBundle pathForResource:feature
                                                            ofType:@"ffcache"
                                                       inDirectory:@"OfflineCache"];
            if (path.length && [NSFileManager.defaultManager fileExistsAtPath:path]) {
                [available addObject:feature];
            }
        }
        features = available.copy;
    });
    return features;
}
#endif

static NSString *ZXWireFeature(NSString *label) {
    static NSDictionary<NSString *, NSString *> *mapping;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mapping = @{
            @"BODY": @"P1", @"DRAG": @"P2", @"NECK": @"P3",
            @"CHEST": @"P4", @"HOLOGRAM_GUN": @"P5", @"THREE_D": @"P6", @"MOD_SKINS": @"P7", @"ESP": @"P8",
            @"MAGIC": @"P9", @"SKIN_HOLO": @"PK"
        };
    });
    return mapping[label.uppercaseString];
}

static NSString *ZXLabelFeature(NSString *wire) {
    static NSDictionary<NSString *, NSString *> *mapping;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mapping = @{
            @"P1": @"BODY", @"P2": @"DRAG", @"P3": @"NECK",
            @"P4": @"CHEST", @"P5": @"HOLOGRAM_GUN", @"P6": @"THREE_D", @"P7": @"MOD_SKINS", @"P8": @"ESP",
            @"P9": @"MAGIC", @"PK": @"SKIN_HOLO"
        };
    });
    return mapping[wire.uppercaseString];
}

static NSString *FFFeatureDisplayName(NSString *feature) {
    if ([feature isEqualToString:@"HOLOGRAM_GUN"]) return @"HOLOGRAM GUN";
    if ([feature isEqualToString:@"SKIN_HOLO"]) return @"SKIN HOLO";
    if ([feature isEqualToString:@"THREE_D"]) return @"3D";
    if ([feature isEqualToString:@"MOD_SKINS"]) return @"MOD SKINS";
    if ([feature isEqualToString:@"MAGIC"]) return @"MAGIC";
    return feature ?: @"FEATURE";
}

static NSString *ZXPlistDigest(NSDictionary *plist, NSArray<NSString *> *keys) {
    if (![plist isKindOfClass:NSDictionary.class]) return nil;
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSString *key in keys) {
        id value = plist[key];
        if (![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) value = @"";
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
    }
    return ZXDigest([[parts componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding]);
}

static NSError *FFError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.fakherddin.ffcachemanager"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL FFIsChannelVerificationError(NSError *error) {
    return error && [error.domain isEqualToString:@"com.fakherddin.ffcachemanager"] && error.code == 70;
}

static void FFOpenExternalURL(NSString *value) {
    NSURL *url = [NSURL URLWithString:value ?: @""];
    if (!url || !url.scheme.length) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
static BOOL FF3105MCMInitialize(void) {
    static BOOL available = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        FF3105API.handle = dlopen("/usr/lib/system/libsystem_containermanager.dylib",
                                 RTLD_NOW | RTLD_LOCAL);
        void *lookup = FF3105API.handle ?: RTLD_DEFAULT;
#define FF3105_RESOLVE(field, symbol) FF3105API.field = (typeof(FF3105API.field))dlsym(lookup, symbol)
        FF3105_RESOLVE(queryCreate, "container_query_create");
        FF3105_RESOLVE(querySetClass, "container_query_set_class");
        FF3105_RESOLVE(querySetIdentifiers, "container_query_set_identifiers");
        FF3105_RESOLVE(querySetGroupIdentifiers, "container_query_set_group_identifiers");
        FF3105_RESOLVE(querySetFlags, "container_query_operation_set_flags");
        FF3105_RESOLVE(querySetPart, "container_query_operation_set_part");
        FF3105_RESOLVE(querySetPartDomain, "container_query_operation_set_part_domain");
        FF3105_RESOLVE(queryGetSingleResult, "container_query_get_single_result");
        FF3105_RESOLVE(queryGetLastError, "container_query_get_last_error");
        FF3105_RESOLVE(queryFree, "container_query_free");
        FF3105_RESOLVE(objectGetPath, "container_object_get_path");
        FF3105_RESOLVE(objectCopy, "container_object_copy");
        FF3105_RESOLVE(copySandboxToken, "container_copy_sandbox_token");
        FF3105_RESOLVE(activateSandboxExtension, "container_object_sandbox_extension_activate");
        FF3105_RESOLVE(objectFree, "container_object_free");
        FF3105_RESOLVE(errorPOSIX, "container_error_get_posix_errno");
        FF3105_RESOLVE(errorMessage, "container_error_get_message");
        FF3105API.sandboxExtensionConsume = (FF3105SandboxExtensionConsumeFunction)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
        FF3105API.xpcStringCreate = (FF3105XPCStringCreateFunction)dlsym(RTLD_DEFAULT, "xpc_string_create");
        FF3105API.xpcRelease = (FF3105XPCReleaseFunction)dlsym(RTLD_DEFAULT, "xpc_release");
#undef FF3105_RESOLVE
        available = FF3105API.queryCreate && FF3105API.querySetClass &&
            FF3105API.querySetIdentifiers && FF3105API.querySetFlags &&
            FF3105API.queryGetSingleResult && FF3105API.queryFree &&
            FF3105API.objectGetPath && FF3105API.objectCopy &&
            FF3105API.copySandboxToken && FF3105API.activateSandboxExtension &&
            FF3105API.objectFree && FF3105API.xpcStringCreate;
    });
    return available;
}

static int64_t FF3105BadQueryGrant(const char *path, BOOL create, const char *groupIdentifier, BOOL isGroup) {
    if (!path || path[0] != '/') return -255;
#ifdef FF_3105_MCM
    if (FFWorseQuerySupported()) {
        return FFWorseQueryGrantPath([NSString stringWithUTF8String:path], create);
    }
#endif
    if (!create) {
        struct stat st;
        if (lstat(path, &st) != 0) return -254;
    }
    if (!FF3105MCMInitialize() || !FF3105API.querySetGroupIdentifiers ||
        !FF3105API.querySetPart || !FF3105API.querySetPartDomain ||
        !FF3105API.sandboxExtensionConsume) {
        return -1;
    }
    void *query = FF3105API.queryCreate();
    if (!query) return -2;
    void *identifier = NULL;
    if (!groupIdentifier) {
        FF3105API.querySetClass(query, 13);
        identifier = FF3105API.xpcStringCreate("systemgroup.com.apple.mobilegestaltcache");
    } else {
        FF3105API.querySetClass(query, 7);
        identifier = FF3105API.xpcStringCreate(groupIdentifier);
    }
    FF3105API.querySetGroupIdentifiers(query, identifier);
    FF3105API.querySetPart(query, 3);
    char *part = NULL;
    int printed = groupIdentifier
        ? asprintf(&part, "../../../../../../../../..%s", path)
        : asprintf(&part, "../../../../../../../..%s", path);
    if (printed == -1 || !part) {
        if (identifier && FF3105API.xpcRelease) FF3105API.xpcRelease(identifier);
        FF3105API.queryFree(query);
        return -5;
    }
    FF3105API.querySetPartDomain(query, part);
    FF3105API.querySetFlags(query, isGroup ? UINT64_C(0x0000000800000000) : UINT64_C(0x0000008000000000));
    void *result = FF3105API.queryGetSingleResult(query);
    if (!result) {
        free(part);
        if (identifier && FF3105API.xpcRelease) FF3105API.xpcRelease(identifier);
        FF3105API.queryFree(query);
        return -3;
    }
    char *token = FF3105API.copySandboxToken(result);
    if (!token) {
        free(part);
        if (identifier && FF3105API.xpcRelease) FF3105API.xpcRelease(identifier);
        FF3105API.queryFree(query);
        return -4;
    }
    int64_t handle = FF3105API.sandboxExtensionConsume(token);
    free(token);
    free(part);
    if (identifier && FF3105API.xpcRelease) FF3105API.xpcRelease(identifier);
    FF3105API.queryFree(query);
    return handle;
}

static void FF3105GrantContainerTree(NSString *containerPath) {
    if (!containerPath.length) return;
    static NSMutableSet<NSString *> *granted;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ granted = [NSMutableSet set]; });
    NSArray<NSString *> *relatives = @[
        @"",
        @"Documents",
        @"Documents/contentcache",
        @"Documents/contentcache/Optional",
        @"Documents/contentcache/Optional/ios",
        @"Documents/contentcache/Optional/ios/optionalavatarres",
        @"Documents/contentcache/Optional/ios/gameassetbundles",
        @"Library",
        @"Library/Preferences",
        @"Library/Saved Application State",
        @"Library/Caches",
        @"Library/SplashBoard/Snapshots"
    ];
    @synchronized (granted) {
        for (NSString *rel in relatives) {
            NSString *target = rel.length
                ? [containerPath stringByAppendingPathComponent:rel]
                : containerPath;
            if ([granted containsObject:target]) continue;
            if (FF3105BadQueryGrant(target.fileSystemRepresentation, YES, NULL, NO) >= 0) {
                [granted addObject:target];
            }
        }
    }
}

static BOOL FF3105ContainerMatchesIdentifier(NSString *container, NSString *identifier);

static NSString *FF3105InodeScanForIdentifier(NSString *rootPath, NSString *identifier, int64_t maxInode) {
    if (!rootPath.length || !identifier.length) return nil;
    const char *rawRoot = rootPath.fileSystemRepresentation;
    struct statfs sfs;
    if (statfs(rawRoot, &sfs) != 0) return nil;
    fsid_t fsid = sfs.f_fsid;
    size_t rootLen = strlen(rawRoot);
    while (rootLen > 1 && rawRoot[rootLen - 1] == '/') rootLen--;
    char buf[1200];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSUInteger candidatesChecked = 0;
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 10.0;
    for (uint64_t ino = 1; ino <= (uint64_t)maxInode; ino++) {
        if ((ino & 0x3FF) == 0 && CFAbsoluteTimeGetCurrent() > deadline) return nil;
        ssize_t n = fsgetpath(buf, sizeof(buf), &fsid, ino);
        if (n <= 0) continue;
        const char *p = buf;
        if (strncmp(rawRoot, "/var/", 5) == 0 && strncmp(p, "/private/var/", 13) == 0) {
            p += 8;
        }
        if (strncmp(p, rawRoot, rootLen) != 0 || p[rootLen] != '/') continue;
        if (strchr(p + rootLen + 1, '/') != NULL) continue;
        NSString *found = [NSString stringWithUTF8String:p];
        if (!found.length || [seen containsObject:found]) continue;
        [seen addObject:found];
        if ([[NSUUID alloc] initWithUUIDString:found.lastPathComponent] == nil) continue;
        if (++candidatesChecked > 800) return nil;
        if (FF3105ContainerMatchesIdentifier(found, identifier)) {
            return found;
        }
    }
    return nil;
}

static BOOL FF3105SafeIdentifier(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0 || identifier.length > 255) return NO;
    static NSCharacterSet *invalid;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *allowed = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_";
        invalid = [[NSCharacterSet characterSetWithCharactersInString:allowed] invertedSet];
    });
    return [identifier rangeOfCharacterFromSet:invalid].location == NSNotFound &&
        ![identifier isEqualToString:@"."] && ![identifier isEqualToString:@".."];
}

static NSString *FF3105LookupFailure(void *query, NSString *fallback) {
    void *containerError = FF3105API.queryGetLastError ? FF3105API.queryGetLastError(query) : NULL;
    int posix = containerError && FF3105API.errorPOSIX ? FF3105API.errorPOSIX(containerError) : 0;
    const char *message = containerError && FF3105API.errorMessage
        ? FF3105API.errorMessage(containerError) : NULL;
    if (message && message[0]) {
        return [NSString stringWithFormat:@"%@ posix=%d message=%s", fallback, posix, message];
    }
    return fallback;
}

@interface FF3105MCMRetainedLease : NSObject {
@public
    void *_query;
    void *_activation;
}
@property(nonatomic, copy) NSString *rootPath;
@property(nonatomic) BOOL activated;
+ (instancetype)leaseForClass:(uint64_t)containerClass
                   identifier:(NSString *)identifier
                        group:(BOOL)group
                       detail:(NSString **)detail;
- (BOOL)activate:(NSString **)detail;
@end

@implementation FF3105MCMRetainedLease
+ (instancetype)leaseForClass:(uint64_t)containerClass
                   identifier:(NSString *)identifier
                        group:(BOOL)group
                       detail:(NSString **)detail {
    if (!FF3105MCMInitialize() || !FF3105SafeIdentifier(identifier)) {
        if (detail) *detail = @"MCM unavailable or identifier contains unsupported characters";
        return nil;
    }
    void *query = FF3105API.queryCreate();
    if (!query) {
        if (detail) *detail = @"query create failed";
        return nil;
    }
    FF3105API.querySetClass(query, containerClass);
    void *xpcIdentifier = FF3105API.xpcStringCreate(identifier.UTF8String);
    if (group && FF3105API.querySetGroupIdentifiers) {
        FF3105API.querySetGroupIdentifiers(query, xpcIdentifier);
    } else {
        FF3105API.querySetIdentifiers(query, xpcIdentifier);
    }
    FF3105API.querySetFlags(query, UINT64_C(0x900000000));
    if (FF3105API.querySetPart) FF3105API.querySetPart(query, 0);

    void *result = FF3105API.queryGetSingleResult(query);
    const char *pathBytes = result ? FF3105API.objectGetPath(result) : NULL;
    NSString *root = pathBytes ? [NSString stringWithUTF8String:pathBytes] : nil;
    if (root.length && ([root isEqualToString:@"/var"] || [root hasPrefix:@"/var/"])) {
        root = [@"/private" stringByAppendingString:root];
    }
    if (!root.length || !root.isAbsolutePath) {
        if (detail) *detail = result
            ? @"MCM returned no absolute container path"
            : FF3105LookupFailure(query, @"MCM lookup failed");
        FF3105API.queryFree(query);
        return nil;
    }
    FF3105MCMRetainedLease *lease = [FF3105MCMRetainedLease new];
    lease->_query = query;
    lease.rootPath = root;
    return lease;
}

- (BOOL)activate:(NSString **)detail {
    if (self.activated) return YES;
    if (!_query) {
        if (detail) *detail = @"lease invalidated";
        return NO;
    }
    void *result = FF3105API.queryGetSingleResult(_query);
    if (result) _activation = FF3105API.objectCopy(result);
    char *token = _activation ? FF3105API.copySandboxToken(_activation) : NULL;
    BOOL hasToken = token && token[0];
    if (token) free(token);
    if (!hasToken) {
        if (detail) *detail = @"MCM object contained no sandbox token";
        return NO;
    }
    self.activated = FF3105API.activateSandboxExtension(_activation, 0);
    if (!self.activated && detail) *detail = @"sandbox extension activation failed";
    return self.activated;
}

- (void)dealloc {
    if (_activation && FF3105API.objectFree) FF3105API.objectFree(_activation);
    if (_query && FF3105API.queryFree) FF3105API.queryFree(_query);
}
@end

static NSString *FF3105MCMContainerPath(NSString *identifier, NSString **detail) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobile.MobileHouseArrest"]) {
        if (detail) *detail = @"host bundle identifier is not com.apple.mobile.MobileHouseArrest";
        return nil;
    }
    static NSMutableDictionary<NSString *, FF3105MCMRetainedLease *> *leases;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ leases = [NSMutableDictionary dictionary]; });
    NSString *key = [NSString stringWithFormat:@"2:0:%@", identifier ?: @""];
    @synchronized (leases) {
        FF3105MCMRetainedLease *lease = leases[key];
        if (lease.rootPath.length) return lease.rootPath;
        lease = [FF3105MCMRetainedLease leaseForClass:2
                                           identifier:identifier
                                                group:NO
                                               detail:detail];
        if (!lease) return nil;
        [lease activate:detail];
        FF3105GrantContainerTree(lease.rootPath);
        int descriptor = open(lease.rootPath.fileSystemRepresentation,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
        if (descriptor < 0) {
            if (detail) *detail = [NSString stringWithFormat:@"container root open failed errno=%d", errno];
            return nil;
        }
        close(descriptor);
        leases[key] = lease;
        return lease.rootPath;
    }
}

#ifdef FF_3105_MCM
static BOOL FF3105ContainerMatchesIdentifier(NSString *container, NSString *identifier) {
    if (!container.length || !identifier.length) return NO;
    FF3105GrantContainerTree(container);
    NSFileManager *manager = NSFileManager.defaultManager;

    NSString *metadata = [container stringByAppendingPathComponent:
        @".com.apple.mobile_container_manager.metadata.plist"];
    FF3105BadQueryGrant(metadata.fileSystemRepresentation, YES, NULL, NO);
    NSData *data = [NSData dataWithContentsOfFile:metadata options:0 error:nil];
    if (!data.length) {
        FILE *handle = fopen(metadata.fileSystemRepresentation, "rb");
        if (handle) {
            NSMutableData *buffer = [NSMutableData data];
            uint8_t chunk[4096];
            size_t bytesRead = 0;
            while ((bytesRead = fread(chunk, 1, sizeof(chunk), handle)) > 0) {
                [buffer appendBytes:chunk length:bytesRead];
            }
            fclose(handle);
            if (buffer.length) data = buffer;
        }
    }
    if (data.length) {
        id plist = [NSPropertyListSerialization propertyListWithData:data
            options:0 format:NULL error:nil];
        if ([plist isKindOfClass:NSDictionary.class]) {
            NSString *bundleIdentifier = ((NSDictionary *)plist)[@"MCMMetadataIdentifier"];
            if ([bundleIdentifier isKindOfClass:NSString.class] &&
                [bundleIdentifier isEqualToString:identifier]) {
                return YES;
            }
        }
    }

    NSString *prefFile = [container stringByAppendingPathComponent:
        [NSString stringWithFormat:@"Library/Preferences/%@.plist", identifier]];
    FF3105BadQueryGrant(prefFile.fileSystemRepresentation, YES, NULL, NO);
    if ([manager fileExistsAtPath:prefFile]) return YES;

    NSString *savedState = [container stringByAppendingPathComponent:
        [NSString stringWithFormat:@"Library/Saved Application State/%@.savedState", identifier]];
    FF3105BadQueryGrant(savedState.fileSystemRepresentation, YES, NULL, NO);
    if ([manager fileExistsAtPath:savedState]) return YES;

    for (NSString *snapRel in @[@"Library/SplashBoard/Snapshots", @"Library/Caches/Snapshots"]) {
        NSString *snapDir = [container stringByAppendingPathComponent:snapRel];
        FF3105BadQueryGrant(snapDir.fileSystemRepresentation, YES, NULL, NO);
        NSArray<NSString *> *snaps = [manager contentsOfDirectoryAtPath:snapDir error:nil];
        for (NSString *snap in snaps) {
            if ([snap isEqualToString:identifier] ||
                [snap hasPrefix:[identifier stringByAppendingString:@" - "]] ||
                [snap hasPrefix:[identifier stringByAppendingString:@"-"]]) {
                return YES;
            }
        }
    }
    return NO;
}

static NSString *FF3105ContainerPathByMetadataScan(NSString *identifier, NSString **detail) {
    if (!FF3105SafeIdentifier(identifier)) {
        if (detail) *detail = @"metadata scan identifier is invalid";
        return nil;
    }
    NSArray<NSString *> *roots = @[
        @"/private/var/mobile/Containers/Data/Application",
        @"/var/mobile/Containers/Data/Application",
    ];
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *root in roots) {
        FF3105BadQueryGrant(root.fileSystemRepresentation, YES, NULL, NO);
        NSArray<NSString *> *entries = [manager contentsOfDirectoryAtPath:root error:nil];
        NSMutableArray<NSString *> *containers = [NSMutableArray array];
        for (NSString *entry in entries) {
            if ([[NSUUID alloc] initWithUUIDString:entry] != nil) {
                [containers addObject:[root stringByAppendingPathComponent:entry]];
            }
        }
        for (NSString *container in containers) {
            if (FF3105ContainerMatchesIdentifier(container, identifier)) {
                return container;
            }
        }
        if (!containers.count) {
            // Directory listing is unavailable. Run a bounded, single-pass
            // fsgetpath inode walk that stops on the first identity match so
            // the compatibility check can never block for minutes.
            NSString *scanned = FF3105InodeScanForIdentifier(root, identifier, 400000);
            if (scanned.length) return scanned;
        }
    }
    if (detail) *detail = @"3105 container scan found no matching app container";
    return nil;
}
#endif
#endif

#ifdef FF_RELEASE_BUILD
#define FFDiagnosticLog(...) ((void)0)
#else
static void FFDiagnosticLog(NSString *component, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);
#endif
static NSError *FFNamedError(NSInteger code, NSString *name, NSString *detail) {
    NSString *message = detail.length ? [NSString stringWithFormat:@"%@: %@", name, detail] : name;
    FFDiagnosticLog(@"ApplyManager", @"%@", message);
    return FFError(code, message);
}

#ifndef FF_RELEASE_BUILD
static void FFDiagnosticLog(NSString *component, NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSLog(@"[%@] %@", component ?: @"Compatibility", message ?: @"");
}
#endif

static NSError *FFPOSIXAccessError(NSInteger code, NSString *operation, NSURL *url, int savedErrno) {
    const char *description = strerror(savedErrno);
    NSString *detail = description ? [NSString stringWithUTF8String:description] : @"unknown POSIX error";
    return FFError(code, [NSString stringWithFormat:@"%@ failed for %@ (errno=%d: %@).",
        operation ?: @"Filesystem access", url.path ?: @"selected path", savedErrno, detail]);
}

static NSString *FFKeychainRead(NSString *account) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: FFKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static BOOL FFKeychainWrite(NSString *account, NSString *value) {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *identity = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: FFKeychainService,
        (__bridge id)kSecAttrAccount: account
    };
    SecItemDelete((__bridge CFDictionaryRef)identity);
    NSMutableDictionary *item = [identity mutableCopy];
    item[(__bridge id)kSecValueData] = data;
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}

static void FFKeychainDelete(NSString *account) {
    NSDictionary *identity = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: FFKeychainService,
        (__bridge id)kSecAttrAccount: account
    };
    SecItemDelete((__bridge CFDictionaryRef)identity);
}

static void FFClearSession(void) {
    FFKeychainDelete(FFAccessTokenAccount);
    FFKeychainDelete(FFRefreshTokenAccount);
}

static volatile BOOL FFSecurityLockedDown = NO;

__attribute__((always_inline)) static inline void FFDenyDebugger(void) {
#if defined(__aarch64__)
    __asm__ volatile(
        "mov x0, #31\n"
        "mov x1, #0\n"
        "mov x2, #0\n"
        "mov x3, #0\n"
        "mov x16, #26\n"
        "svc #0x80\n"
        :
        :
        : "x0", "x1", "x2", "x3", "x16", "memory"
    );
#endif
}

static BOOL FFDebuggerAttachedViaSysctl(void) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    memset(&info, 0, sizeof(info));
    size_t size = sizeof(info);
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static NSString *FFIntegrityFailureDetail = nil;

static NSArray<NSString *> *FFExpectedIconFiles(void) {
    return @[
        @"AppIcon60x60@2x.png",
        @"AppIcon60x60@3x.png",
        @"AppIcon76x76.png",
        @"AppIcon76x76@2x.png",
        @"AppIcon83.5x83.5@2x.png",
        @"AppIcon1024.png"
    ];
}

static BOOL FFVerifyAppIcons(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *bundlePath = bundle.bundlePath;
    if (!bundlePath.length) return NO;
    NSDictionary *info = bundle.infoDictionary;
    if (![info isKindOfClass:NSDictionary.class]) return NO;
    NSOperatingSystemVersion osVersion = NSProcessInfo.processInfo.operatingSystemVersion;
    BOOL legacyOS = osVersion.majorVersion < 17;
    // MobileInstallation/SpringBoard can normalize the icon plist on older
    // iOS (order changes, icon-name keys added). Treat those variants as
    // equivalent on iOS 15/16 while keeping the strict check on iOS 17+.
    if (!legacyOS && (info[@"CFBundleIconFile"] || info[@"CFBundleIconName"])) return NO;
    NSDictionary *icons = [info[@"CFBundleIcons"] isKindOfClass:NSDictionary.class] ? info[@"CFBundleIcons"] : nil;
    NSDictionary *primary = [icons[@"CFBundlePrimaryIcon"] isKindOfClass:NSDictionary.class] ? icons[@"CFBundlePrimaryIcon"] : nil;
    if (!legacyOS && primary[@"CFBundleIconName"]) return NO;
    NSArray *iconFiles = [primary[@"CFBundleIconFiles"] isKindOfClass:NSArray.class] ? primary[@"CFBundleIconFiles"] : nil;
    NSArray *expectedPrimary = @[@"AppIcon60x60", @"AppIcon76x76", @"AppIcon83.5x83.5"];
    if (![iconFiles isEqualToArray:expectedPrimary]) {
        NSSet<NSString *> *fileSet = [NSSet setWithArray:iconFiles ?: @[]];
        NSSet<NSString *> *expectedSet = [NSSet setWithArray:expectedPrimary];
        if (!(legacyOS && [fileSet isEqualToSet:expectedSet])) return NO;
    }

    NSArray<NSString *> *expectedFiles = FFExpectedIconFiles();
    NSSet<NSString *> *expectedSet = [NSSet setWithArray:expectedFiles];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:bundlePath error:nil];
    for (NSString *entry in entries) {
        NSString *lower = entry.lowercaseString;
        // Legacy iOS installers/signers may add extra generated icon sizes
        // (29/40/57...) into the bundle. Ignore them on iOS 15/16; the six
        // required files + combined digest below remain mandatory.
        if ([lower hasPrefix:@"appicon"] && ![expectedSet containsObject:entry] && !legacyOS) return NO;
        if ([lower hasSuffix:@".dylib"] || [lower hasSuffix:@".deb"]) return NO;
    }
    NSString *frameworksPath = bundle.privateFrameworksPath;
    if (frameworksPath.length) {
        NSArray<NSString *> *fwEntries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:frameworksPath error:nil];
        for (NSString *fw in fwEntries) {
            if (![fw isEqualToString:@"CoreTelemetry.framework"]) return NO;
        }
    }
    NSMutableArray<NSString *> *digests = [NSMutableArray arrayWithCapacity:expectedFiles.count];
    for (NSString *iconName in expectedFiles) {
        NSString *iconPath = [bundlePath stringByAppendingPathComponent:iconName];
        NSData *iconData = [NSData dataWithContentsOfFile:iconPath options:NSDataReadingMappedIfSafe error:nil];
        if (iconData.length < 1024) return NO;
        const uint8_t pngSig[8] = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
        if (memcmp(iconData.bytes, pngSig, sizeof(pngSig)) != 0) return NO;
        [digests addObject:ZXDigest(iconData)];
    }
#ifdef FFICON_BUNDLE_SHA256
    NSString *combined = ZXDigest([[digests componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding]);
    if (![combined isEqualToString:FFICON_BUNDLE_SHA256]) return NO;
#endif
    return YES;
}

static BOOL FFStringContainsInstrumentation(const char *value) {
    if (!value || !*value) return NO;
    NSString *candidate = [[NSString stringWithUTF8String:value] lowercaseString];
    if (!candidate.length) return NO;
    for (NSString *needleName in @[
        @"frida", @"fridagadget", @"cycript", @"flex.dylib",
        @"substrate", @"substitute", @"ellekit", @"libhooker",
        @"sslkill", @"dobby", @"fishhook", @"shadow.dylib"
    ]) {
        if ([candidate containsString:needleName]) return YES;
    }
    return NO;
}

static BOOL FFCriticalSymbolsClean(void) {
    // Hook detection: the addresses of the security-critical functions must
    // still live inside Apple's own system images. fishhook/Substitute style
    // pointer swaps and dylib trampolines make dladdr resolve to the attacker
    // dylib instead, which is caught here before any verification runs.
    const char *names[] = {
        "SecKeyVerifySignature", "SecKeyRawVerify",
        "CC_SHA256", "sandbox_extension_consume",
        "SecTrustEvaluateWithError",
    };
    for (size_t index = 0; index < sizeof(names) / sizeof(names[0]); index++) {
        void *address = dlsym(RTLD_DEFAULT, names[index]);
        if (!address) continue;
        Dl_info info;
        memset(&info, 0, sizeof(info));
        if (dladdr(address, &info) && info.dli_fname) {
            NSString *imagePath = [NSString stringWithUTF8String:info.dli_fname];
            if (![imagePath hasPrefix:@"/usr/lib/"] &&
                ![imagePath hasPrefix:@"/usr/lib/system/"] &&
                ![imagePath hasPrefix:@"/System/Library/"]) {
                FFDiagnosticLog(@"Security", @"CRITICAL SYMBOL HOOKED: %s -> %@",
                    names[index], imagePath);
                return NO;
            }
        }
    }
    return YES;
}

static BOOL FFRuntimeInstrumentationDetected(void) {
    FFDenyDebugger();
    if (FFDebuggerAttachedViaSysctl()) return YES;
    if (!FFCriticalSymbolsClean()) return YES;
    const char *dyldInsert = getenv("DYLD_INSERT_LIBRARIES");
    if (dyldInsert && *dyldInsert) return YES;
    NSString *bundlePath = [NSBundle.mainBundle.bundlePath stringByStandardizingPath];
    NSString *expectedMain = [[bundlePath stringByAppendingPathComponent:@"FFCacheManager"] stringByStandardizingPath];
    NSString *expectedCore = [[bundlePath stringByAppendingPathComponent:@"Frameworks/CoreTelemetry.framework/CoreTelemetry"] stringByStandardizingPath];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char *rawName = _dyld_get_image_name(i);
        if (!rawName || !*rawName) continue;
        if (FFStringContainsInstrumentation(rawName)) return YES;
        NSString *imagePath = [[NSString stringWithUTF8String:rawName] stringByStandardizingPath];
        if (bundlePath.length && [imagePath hasPrefix:bundlePath]) {
            if (![imagePath isEqualToString:expectedMain] && ![imagePath isEqualToString:expectedCore]) {
                return YES;
            }
        }
    }
    if (!FFVerifyAppIcons()) return YES;
    return NO;
}

static BOOL FFSecuritySensitiveOperationAllowed(void) {
    if (FFSecurityLockedDown) return NO;
    if (FFRuntimeInstrumentationDetected()) {
        FFSecurityLockedDown = YES;
        FFClearSession();
        return NO;
    }
    return YES;
}

static BOOL FFURLTargetsOfficialAPI(NSURL *url) {
    NSURL *base = [NSURL URLWithString:FFAPIBaseURL() ?: @""];
    if (!url || !base) return NO;
    if (![url.scheme.lowercaseString isEqualToString:@"https"]) return NO;
    if (![url.host.lowercaseString isEqualToString:base.host.lowercaseString]) return NO;
    NSNumber *urlPort = url.port ?: @443;
    NSNumber *basePort = base.port ?: @443;
    return [urlPort isEqualToNumber:basePort];
}

static NSString *ZXInstallID(void) {
    NSString *identifier = FFKeychainRead(FFDeviceAccount);
    if (identifier.length >= 16) return identifier;
    identifier = NSUUID.UUID.UUIDString;
    return FFKeychainWrite(FFDeviceAccount, identifier) ? identifier : nil;
}

static uint32_t FFReadBE32(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
           ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t FFReadBE64(const uint8_t *bytes) {
    return ((uint64_t)FFReadBE32(bytes) << 32) | FFReadBE32(bytes + 4);
}

static BOOL FFRangeFits(uint64_t offset, uint64_t size, uint64_t limit) {
    return offset <= limit && size <= limit - offset;
}

static BOOL ZXVerifySlice(NSData *file, uint64_t sliceOffset, uint64_t sliceSize,
                          NSString **textHash, NSString **exportHash, NSString **sectionHash) {
    if (!FFRangeFits(sliceOffset, sliceSize, file.length) || sliceSize < sizeof(struct mach_header_64)) return NO;
    const uint8_t *slice = (const uint8_t *)file.bytes + sliceOffset;
    struct mach_header_64 header;
    memcpy(&header, slice, sizeof(header));
    if (header.magic != MH_MAGIC_64 || !FFRangeFits(sizeof(header), header.sizeofcmds, sliceSize)) return NO;

    uint64_t textOffset = 0, textSize = 0, exportsOffset = 0, exportsSize = 0;
    uint64_t fallbackExportsOffset = 0, fallbackExportsSize = 0;
    NSMutableData *sectionBytesForHash = sectionHash ? [NSMutableData data] : nil;
    uint64_t cursor = sizeof(header);
    for (uint32_t index = 0; index < header.ncmds; index++) {
        if (!FFRangeFits(cursor, sizeof(struct load_command), sliceSize)) return NO;
        struct load_command command;
        memcpy(&command, slice + cursor, sizeof(command));
        if (command.cmdsize < sizeof(command) || !FFRangeFits(cursor, command.cmdsize, sliceSize)) return NO;

        if (command.cmd == LC_SEGMENT_64 && command.cmdsize >= sizeof(struct segment_command_64)) {
            struct segment_command_64 segment;
            memcpy(&segment, slice + cursor, sizeof(segment));
            uint64_t sectionsSize = (uint64_t)segment.nsects * sizeof(struct section_64);
            if (!FFRangeFits(sizeof(segment), sectionsSize, command.cmdsize)) return NO;
            const uint8_t *sectionBytes = slice + cursor + sizeof(segment);
            for (uint32_t sectionIndex = 0; sectionIndex < segment.nsects; sectionIndex++) {
                struct section_64 section;
                memcpy(&section, sectionBytes + sectionIndex * sizeof(section), sizeof(section));
                if (strncmp(section.segname, "__TEXT", 16) == 0 &&
                    strncmp(section.sectname, "__text", 16) == 0) {
                    textOffset = section.offset;
                    textSize = section.size;
                }
                if (sectionHash && section.offset && section.size &&
                    FFRangeFits(section.offset, section.size, sliceSize)) {
                    [sectionBytesForHash appendBytes:slice + section.offset length:(NSUInteger)section.size];
                }
            }
        } else if (command.cmd == LC_DYLD_EXPORTS_TRIE && command.cmdsize >= sizeof(struct linkedit_data_command)) {
            struct linkedit_data_command exports;
            memcpy(&exports, slice + cursor, sizeof(exports));
            exportsOffset = exports.dataoff;
            exportsSize = exports.datasize;
        } else if (command.cmd == LC_DYLD_INFO_ONLY && command.cmdsize >= sizeof(struct dyld_info_command)) {
            struct dyld_info_command info;
            memcpy(&info, slice + cursor, sizeof(info));
            fallbackExportsOffset = info.export_off;
            fallbackExportsSize = info.export_size;
        }
        cursor += command.cmdsize;
    }

    if (!exportsSize) {
        exportsOffset = fallbackExportsOffset;
        exportsSize = fallbackExportsSize;
    }
    if (!textSize || !exportsSize || !FFRangeFits(textOffset, textSize, sliceSize) ||
        !FFRangeFits(exportsOffset, exportsSize, sliceSize)) return NO;

    *textHash = ZXDigest([file subdataWithRange:NSMakeRange((NSUInteger)(sliceOffset + textOffset), (NSUInteger)textSize)]);
    *exportHash = ZXDigest([file subdataWithRange:NSMakeRange((NSUInteger)(sliceOffset + exportsOffset), (NSUInteger)exportsSize)]);
    if (sectionHash) {
        if (!sectionBytesForHash.length) return NO;
        *sectionHash = ZXDigest(sectionBytesForHash);
    }
    return YES;
}

static BOOL FFVerifyMachOLoadCommands(const uint8_t *bytes, uint64_t limit,
                                      uint64_t *textVMOffsetOut, uint64_t *textFileOffsetOut, uint64_t *textSizeOut,
                                      uint64_t *cstringVMOffsetOut, uint64_t *cstringFileOffsetOut, uint64_t *cstringSizeOut) {
    if (!bytes || limit < sizeof(struct mach_header_64)) return NO;
    struct mach_header_64 header;
    memcpy(&header, bytes, sizeof(header));
    if (header.magic != MH_MAGIC_64 || !FFRangeFits(sizeof(header), header.sizeofcmds, limit)) return NO;
    uint64_t textSegVMAddr = 0;
    BOOL foundTextSeg = NO;
    uint64_t textAddr = 0, textOffset = 0, textSize = 0;
    uint64_t cstringAddr = 0, cstringOffset = 0, cstringSize = 0;
    uint32_t dylibCount = 0;
    uint64_t cursor = sizeof(header);
    for (uint32_t index = 0; index < header.ncmds; index++) {
        if (!FFRangeFits(cursor, sizeof(struct load_command), limit)) return NO;
        struct load_command command;
        memcpy(&command, bytes + cursor, sizeof(command));
        if (command.cmdsize < sizeof(command) || !FFRangeFits(cursor, command.cmdsize, limit)) return NO;
        uint32_t cmd = command.cmd;
        if (cmd == LC_LOAD_DYLIB || cmd == LC_LOAD_WEAK_DYLIB ||
            cmd == LC_REEXPORT_DYLIB || cmd == LC_LAZY_LOAD_DYLIB || cmd == LC_LOAD_UPWARD_DYLIB) {
            if (command.cmdsize < sizeof(struct dylib_command)) return NO;
            struct dylib_command dylibCmd;
            memcpy(&dylibCmd, bytes + cursor, sizeof(dylibCmd));
            uint32_t nameOffset = dylibCmd.dylib.name.offset;
            if (nameOffset < sizeof(dylibCmd) || nameOffset >= command.cmdsize) return NO;
            const char *rawName = (const char *)(bytes + cursor + nameOffset);
            size_t maxLen = command.cmdsize - nameOffset;
            size_t nameLen = strnlen(rawName, maxLen);
            if (nameLen == 0 || nameLen == maxLen) return NO;
            if (strncmp(rawName, "/System/Library/", 16) != 0 &&
                strncmp(rawName, "/usr/lib/", 9) != 0) {
                return NO;
            }
            dylibCount++;
        } else if (cmd == LC_SEGMENT_64 && command.cmdsize >= sizeof(struct segment_command_64)) {
            struct segment_command_64 segment;
            memcpy(&segment, bytes + cursor, sizeof(segment));
            uint64_t sectionsSize = (uint64_t)segment.nsects * sizeof(struct section_64);
            if (!FFRangeFits(sizeof(segment), sectionsSize, command.cmdsize)) return NO;
            if (strncmp(segment.segname, "__TEXT", 16) == 0) {
                textSegVMAddr = segment.vmaddr;
                foundTextSeg = YES;
                const uint8_t *sections = bytes + cursor + sizeof(segment);
                for (uint32_t sectionIndex = 0; sectionIndex < segment.nsects; sectionIndex++) {
                    struct section_64 section;
                    memcpy(&section, sections + sectionIndex * sizeof(section), sizeof(section));
                    if (strncmp(section.segname, "__TEXT", 16) != 0) continue;
                    if (strncmp(section.sectname, "__text", 16) == 0) {
                        textAddr = section.addr;
                        textOffset = section.offset;
                        textSize = section.size;
                    } else if (strncmp(section.sectname, "__cstring", 16) == 0) {
                        cstringAddr = section.addr;
                        cstringOffset = section.offset;
                        cstringSize = section.size;
                    }
                }
            }
        }
        cursor += command.cmdsize;
    }
    if (!foundTextSeg || !textSize || !cstringSize || dylibCount < 8 || dylibCount > 12) return NO;
    if (textAddr < textSegVMAddr || cstringAddr < textSegVMAddr) return NO;
    if (textVMOffsetOut) *textVMOffsetOut = textAddr - textSegVMAddr;
    if (textFileOffsetOut) *textFileOffsetOut = textOffset;
    if (textSizeOut) *textSizeOut = textSize;
    if (cstringVMOffsetOut) *cstringVMOffsetOut = cstringAddr - textSegVMAddr;
    if (cstringFileOffsetOut) *cstringFileOffsetOut = cstringOffset;
    if (cstringSizeOut) *cstringSizeOut = cstringSize;
    return YES;
}

static BOOL FFLiveInMemorySectionHashes(NSString **textHashOut, NSString **cstringHashOut) {
    if (!FFVerifyAppIcons()) return NO;
    const struct mach_header_64 *mainHeader = NULL;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const struct mach_header *hdr = _dyld_get_image_header(i);
        if (hdr && hdr->magic == MH_MAGIC_64 && hdr->filetype == MH_EXECUTE) {
            mainHeader = (const struct mach_header_64 *)hdr;
            break;
        }
    }
    if (!mainHeader) return NO;
    uint64_t headerLimit = sizeof(struct mach_header_64) + (uint64_t)mainHeader->sizeofcmds;
    if (mainHeader->sizeofcmds == 0 || mainHeader->sizeofcmds > 65536) return NO;
    uint64_t textVMOff = 0, textSize = 0, cstringVMOff = 0, cstringSize = 0;
    if (!FFVerifyMachOLoadCommands((const uint8_t *)mainHeader, headerLimit,
                                   &textVMOff, NULL, &textSize,
                                   &cstringVMOff, NULL, &cstringSize)) {
        return NO;
    }
    const uint8_t *base = (const uint8_t *)mainHeader;
    NSData *liveText = [NSData dataWithBytesNoCopy:(void *)(base + textVMOff)
                                            length:(NSUInteger)textSize
                                      freeWhenDone:NO];
    NSData *liveCString = [NSData dataWithBytesNoCopy:(void *)(base + cstringVMOff)
                                               length:(NSUInteger)cstringSize
                                         freeWhenDone:NO];
    if (textHashOut) *textHashOut = ZXDigest(liveText);
    if (cstringHashOut) *cstringHashOut = ZXDigest(liveCString);
    return YES;
}

static BOOL FFApplicationSectionHashes(NSData *file, NSString **textHash, NSString **cstringHash) {
    uint64_t textOffset = 0, textSize = 0, cstringOffset = 0, cstringSize = 0;
    if (!FFVerifyMachOLoadCommands(file.bytes, file.length,
                                   NULL, &textOffset, &textSize,
                                   NULL, &cstringOffset, &cstringSize)) {
        return NO;
    }
    // Final distribution signers may legitimately rewrite non-code metadata
    // sections inside __TEXT.  Pin the executable instructions and constant
    // strings directly; neither is part of the code-signature blob and both
    // must remain byte-for-byte stable on disk and in RAM.
    if (!textSize || !cstringSize ||
        !FFRangeFits(textOffset, textSize, file.length) ||
        !FFRangeFits(cstringOffset, cstringSize, file.length)) return NO;
    NSString *diskText = ZXDigest([file subdataWithRange:NSMakeRange((NSUInteger)textOffset, (NSUInteger)textSize)]);
    NSString *diskCString = ZXDigest([file subdataWithRange:NSMakeRange((NSUInteger)cstringOffset, (NSUInteger)cstringSize)]);
    NSString *ramText = nil, *ramCString = nil;
    BOOL ramAvailable = FFLiveInMemorySectionHashes(&ramText, &ramCString);
    NSOperatingSystemVersion osVersion = NSProcessInfo.processInfo.operatingSystemVersion;
    if (ramAvailable) {
        if (![diskText isEqualToString:ramText] || ![diskCString isEqualToString:ramCString]) {
            if (osVersion.majorVersion >= 17) {
                // Modern OS: a live RAM mismatch means runtime tampering.
                FFDiagnosticLog(@"Integrity", @"RAM/DISK SECTION MISMATCH");
                return NO;
            }
            // iOS 15/16: dyld4 can legitimately rewrite the in-memory header,
            // so a RAM difference is not treated as tampering. The disk
            // section hashes stay pinned by the signed server manifest.
            FFDiagnosticLog(@"Integrity", @"Legacy RAM/DISK mismatch tolerated");
        }
    } else if (osVersion.majorVersion >= 17) {
        // Modern OS: live in-memory hashing is mandatory.
        FFDiagnosticLog(@"Integrity", @"LIVE SECTION HASH UNAVAILABLE");
        return NO;
    }
    // iOS 15/16: dyld4's in-memory image can differ structurally, so the live
    // RAM check is best-effort there. The disk section hashes remain pinned
    // by the signed server manifest, which still rejects any modified binary.
    *textHash = diskText;
    *cstringHash = diskCString;
    return YES;
}

static NSData *FFReadBinaryRobust(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    if (data.length >= 8) return data;
    data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (data.length >= 8) return data;
    FILE *handle = fopen(path.fileSystemRepresentation, "rb");
    if (!handle) return nil;
    fseek(handle, 0, SEEK_END);
    long size = ftell(handle);
    fseek(handle, 0, SEEK_SET);
    if (size <= 0) { fclose(handle); return nil; }
    NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)size];
    size_t read = fread(buffer.mutableBytes, 1, (size_t)size, handle);
    fclose(handle);
    if (read != (size_t)size) return nil;
    return buffer;
}

static BOOL FFVerifyCoreBinaryAtPath(NSString *path) {
    NSData *file = FFReadBinaryRobust(path);
    if (file.length < 8) {
        FFIntegrityFailureDetail = @"core: file unreadable";
        return NO;
    }
    const uint8_t *bytes = file.bytes;
    uint32_t magic = FFReadBE32(bytes);
    BOOL fat64 = magic == 0xcafebabf;
    struct mach_header_64 thinHeader;
    memcpy(&thinHeader, bytes, sizeof(thinHeader));
    BOOL thin = file.length >= sizeof(thinHeader) && thinHeader.magic == MH_MAGIC_64;
    if (magic != 0xcafebabe && !fat64 && !thin) {
        FFIntegrityFailureDetail = @"core: not a Mach-O";
        return NO;
    }
    if (thin) {
        // Legacy signing tools can thin the FAT framework down to a plain
        // arm64 Mach-O. Verify the whole file as one slice; it must still
        // match the build-pinned hashes of slice A or B.
        NSString *textHash = nil, *exportHash = nil, *sectionHash = nil;
        if (!ZXVerifySlice(file, 0, file.length, &textHash, &exportHash, &sectionHash)) {
            FFIntegrityFailureDetail = @"core: thin slice unreadable";
            return NO;
        }
        BOOL matchesA = [textHash isEqualToString:FFCORE_TEXT_SHA256_A] &&
                         [exportHash isEqualToString:FFCORE_EXPORT_SHA256_A] &&
                         [sectionHash isEqualToString:FFCORE_SECTION_SHA256_A];
        BOOL matchesB = [textHash isEqualToString:FFCORE_TEXT_SHA256_B] &&
                         [exportHash isEqualToString:FFCORE_EXPORT_SHA256_B] &&
                         [sectionHash isEqualToString:FFCORE_SECTION_SHA256_B];
        if (!matchesA && !matchesB) {
            FFIntegrityFailureDetail = [NSString stringWithFormat:
                @"core: thin slice hash mismatch (text %@ export %@)",
                [textHash substringToIndex:MIN((NSUInteger)12, textHash.length)],
                [exportHash substringToIndex:MIN((NSUInteger)12, exportHash.length)]];
            return NO;
        }
        return YES;
    }
    uint32_t count = FFReadBE32(bytes + 4);
    uint64_t entrySize = fat64 ? 32 : 20;
    // Legacy signing tools can thin the two-slice framework to the single
    // running arm64 slice. Accept 1 or 2 slices; the text/export hashes of
    // every slice must still match the build-pinned values.
    if ((count != 2 && count != 1) || !FFRangeFits(8, (uint64_t)count * entrySize, file.length)) {
        FFIntegrityFailureDetail = [NSString stringWithFormat:@"core: slice count %u (expected 1-2)", count];
        return NO;
    }

    BOOL foundA = NO, foundB = NO;
    for (uint32_t index = 0; index < count; index++) {
        const uint8_t *entry = bytes + 8 + (uint64_t)index * entrySize;
        uint64_t sliceOffset = fat64 ? FFReadBE64(entry + 8) : FFReadBE32(entry + 8);
        uint64_t sliceSize = fat64 ? FFReadBE64(entry + 16) : FFReadBE32(entry + 12);
        NSString *textHash = nil, *exportHash = nil, *sectionHash = nil;
        if (!ZXVerifySlice(file, sliceOffset, sliceSize, &textHash, &exportHash, &sectionHash)) {
            FFIntegrityFailureDetail = [NSString stringWithFormat:@"core: slice %u unreadable", index];
            return NO;
        }
        BOOL matchesA = [textHash isEqualToString:FFCORE_TEXT_SHA256_A] &&
                         [exportHash isEqualToString:FFCORE_EXPORT_SHA256_A] &&
                         [sectionHash isEqualToString:FFCORE_SECTION_SHA256_A];
        BOOL matchesB = [textHash isEqualToString:FFCORE_TEXT_SHA256_B] &&
                         [exportHash isEqualToString:FFCORE_EXPORT_SHA256_B] &&
                         [sectionHash isEqualToString:FFCORE_SECTION_SHA256_B];
        if ((!matchesA && !matchesB) || (matchesA && foundA) || (matchesB && foundB)) {
            FFIntegrityFailureDetail = [NSString stringWithFormat:
                @"core: slice %u hash mismatch (text %@ export %@)",
                index,
                [textHash substringToIndex:MIN((NSUInteger)12, textHash.length)],
                [exportHash substringToIndex:MIN((NSUInteger)12, exportHash.length)]];
            return NO;
        }
        foundA |= matchesA;
        foundB |= matchesB;
    }
    if (count == 1) {
        if (!foundA && !foundB) {
            FFIntegrityFailureDetail = @"core: single slice unknown";
            return NO;
        }
    } else if (!foundA || !foundB) {
        FFIntegrityFailureDetail = @"core: missing slice identity";
        return NO;
    }
    return YES;
}

static NSDictionary *FFIntegrityReport(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *corePath = [bundle.privateFrameworksPath stringByAppendingPathComponent:@"CoreTelemetry.framework/CoreTelemetry"];
    if (!FFVerifyCoreBinaryAtPath(corePath)) {
        if (!FFIntegrityFailureDetail.length) FFIntegrityFailureDetail = @"core binary verify";
        FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: core binary verify");
        return nil;
    }
    NSData *coreFile = FFReadBinaryRobust(corePath);
    if (coreFile.length < 8) {
        FFIntegrityFailureDetail = @"core file read";
        FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: core file read");
        return nil;
    }
    const uint8_t *coreBytes = coreFile.bytes;
    uint32_t fatMagic = FFReadBE32(coreBytes);
    BOOL fat64 = fatMagic == 0xcafebabf;
    struct mach_header_64 thinCoreHeader;
    memcpy(&thinCoreHeader, coreBytes, sizeof(thinCoreHeader));
    BOOL thinCore = coreFile.length >= sizeof(thinCoreHeader) && thinCoreHeader.magic == MH_MAGIC_64;
    NSMutableArray<NSDictionary *> *slices = [NSMutableArray arrayWithCapacity:2];
    if (thinCore) {
        // Legacy signers thin the FAT framework to a plain arm64 Mach-O.
        // Report its single slice for both core entries.
        NSString *textHash = nil, *exportHash = nil;
        if (!ZXVerifySlice(coreFile, 0, coreFile.length, &textHash, &exportHash, nil)) {
            FFIntegrityFailureDetail = @"core thin slice";
            FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: core thin slice");
            return nil;
        }
        [slices addObject:@{ @"text": textHash, @"exports": exportHash }];
        [slices addObject:slices.firstObject];
    } else {
        uint32_t coreSliceCount = FFReadBE32(coreBytes + 4);
        if ((fatMagic != 0xcafebabe && !fat64) || (coreSliceCount != 2 && coreSliceCount != 1)) {
            FFIntegrityFailureDetail = [NSString stringWithFormat:@"core fat header (slices %u)", coreSliceCount];
            FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: core fat header");
            return nil;
        }
        uint64_t entrySize = fat64 ? 32 : 20;
        for (uint32_t index = 0; index < coreSliceCount; index++) {
            const uint8_t *entry = coreBytes + 8 + (uint64_t)index * entrySize;
            uint64_t offset = fat64 ? FFReadBE64(entry + 8) : FFReadBE32(entry + 8);
            uint64_t size = fat64 ? FFReadBE64(entry + 16) : FFReadBE32(entry + 12);
            NSString *textHash = nil, *exportHash = nil;
            if (!ZXVerifySlice(coreFile, offset, size, &textHash, &exportHash, nil)) {
                FFIntegrityFailureDetail = [NSString stringWithFormat:@"core slice %u", index];
                FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: core slice %u", index);
                return nil;
            }
            [slices addObject:@{ @"text": textHash, @"exports": exportHash }];
        }
        if (coreSliceCount == 1) {
            // Report the single FAT slice for both core entries; the server
            // accepts this as long as core_a matches the manifest.
            [slices addObject:slices.firstObject];
        }
    }

    NSData *appFile = [NSData dataWithContentsOfFile:bundle.executablePath options:NSDataReadingMappedIfSafe error:nil];
    NSString *appText = nil, *appCString = nil;
    if (!appFile.length || !FFApplicationSectionHashes(appFile, &appText, &appCString)) {
        FFIntegrityFailureDetail = @"app sections";
        FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: app sections");
        return nil;
    }
    NSString *frameworkInfoPath = [bundle.privateFrameworksPath stringByAppendingPathComponent:@"CoreTelemetry.framework/Info.plist"];
    NSDictionary *info = bundle.infoDictionary;
    NSDictionary *frameworkInfo = [NSDictionary dictionaryWithContentsOfFile:frameworkInfoPath];
    NSString *displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
    NSString *infoHash = ZXPlistDigest(info, @[
        @"CFBundleDisplayName", @"CFBundleExecutable", @"CFBundleIdentifier", @"CFBundleName",
        @"CFBundlePackageType", @"CFBundleShortVersionString", @"CFBundleVersion", @"MinimumOSVersion"
    ]);
    NSString *frameworkInfoHash = ZXPlistDigest(frameworkInfo, @[
        @"CFBundleExecutable", @"CFBundleIdentifier", @"CFBundleName", @"CFBundlePackageType",
        @"CFBundleShortVersionString", @"CFBundleVersion", @"MinimumOSVersion"
    ]);
    if (!infoHash.length || !frameworkInfoHash.length || !bundle.bundleIdentifier.length || !displayName.length) {
        FFIntegrityFailureDetail = @"plist metadata";
        FFDiagnosticLog(@"Integrity", @"MEASURE FAIL: plist metadata");
        return nil;
    }
    FFIntegrityFailureDetail = nil;
    return @{
        @"app_text_sha256": appText,
        @"app_cstring_sha256": appCString,
        @"core_a_text_sha256": slices[0][@"text"],
        @"core_a_export_sha256": slices[0][@"exports"],
        @"core_b_text_sha256": slices[1][@"text"],
        @"core_b_export_sha256": slices[1][@"exports"],
        @"info_plist_sha256": infoHash,
        @"framework_plist_sha256": frameworkInfoHash,
        @"bundle_identifier": bundle.bundleIdentifier,
        @"display_name": displayName,
        @"app_version": info[@"CFBundleShortVersionString"] ?: @"",
        @"build_version": info[@"CFBundleVersion"] ?: @""
    };
}

static BOOL FFLoadSandboxBridge(NSError **error) {
    if (FFProtectedCoreHandle && FFMCMStart && FFMCMDataContainerPath) return YES;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobile.MobileHouseArrest"]) {
        if (error) *error = FFError(2, @"This build's required runtime identity is unavailable.");
        return NO;
    }
    NSString *frameworkPath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"CoreTelemetry.framework"];
    NSString *executablePath = [frameworkPath stringByAppendingPathComponent:@"CoreTelemetry"];
    if (!FFVerifyCoreBinaryAtPath(executablePath)) {
        if (error) *error = FFError(3, @"Protected core integrity verification failed.");
        return NO;
    }
    FFProtectedCoreHandle = dlopen(executablePath.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    if (!FFProtectedCoreHandle) {
        const char *detail = dlerror();
        if (error) *error = FFError(4, [NSString stringWithFormat:@"Protected core failed to load: %s", detail ?: "unknown"]);
        return NO;
    }
    FFMCMStart = (MCMFilzaStartFunction)dlsym(FFProtectedCoreHandle, "FKX0A7Q2M9Z");
    FFMCMDataContainerPath = (MCMFilzaDataContainerPathFunction)dlsym(FFProtectedCoreHandle, "FKX1R4V8N6P");
    FFMCMSetUnrestrictedFilesystem = (MCMFilzaSetUnrestrictedFilesystemFunction)dlsym(FFProtectedCoreHandle, "FKX2C5J9T3W");
    // FilzaSlop 1.0.3 keeps this read-only helper exported. It exposes only
    // the bridge's own virtual root, which lets us use its iOS 18 fallback
    // links without constructing arbitrary filesystem paths.
    FFMCMVirtualRoot = (MCMFilzaVirtualRootFunction)dlsym(FFProtectedCoreHandle, "FKX3D8H4K7R");
    if (!FFMCMStart || !FFMCMDataContainerPath || !FFMCMSetUnrestrictedFilesystem) {
        if (error) *error = FFError(5, @"Protected core APIs are incomplete.");
        return NO;
    }
    // MCMFilzaStart builds its Device Storage links only once. Set this before
    // starting the bridge so iOS 18 can enumerate the class-2 App Data links
    // instead of pruning them during its first start.
    FFMCMSetUnrestrictedFilesystem(YES);
    FFMCMStart();
    return YES;
}

static NSArray<NSString *> *FFGameContainerCandidates(NSString *selectedGameIdentifier,
                                                       NSString **lookupDetail) {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
    // Fast known-container path: owner-provisioned devices resolve instantly
    // without the slow MCM/kernel/scan compatibility flow.
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *knownRoot in @[FFUserFallbackContainerPath]) {
        if (!knownRoot.length) continue;
        BOOL isDirectory = NO;
        if ([manager fileExistsAtPath:knownRoot isDirectory:&isDirectory] && isDirectory) {
#ifdef FF_3105_MCM
            if (FFWorseQuerySupported() &&
                !FF3105ContainerMatchesIdentifier(knownRoot, selectedGameIdentifier)) continue;
#endif
            [paths addObject:knownRoot];
        }
    }
#ifdef FF_3105_MCM
    if (FFWorseQuerySupported()) {
        if (!FFWorseQueryPrepare() && !FFHasFullFilesystemAccess()) {
            if (lookupDetail) *lookupDetail = FFWorseQueryFailureReason();
            return paths.array;
        }
        NSString *candidate = FFWorseQueryDataContainerCandidate(selectedGameIdentifier);
        if (candidate.length && FF3105ContainerMatchesIdentifier(candidate, selectedGameIdentifier)) {
            [paths addObject:candidate];
            return paths.array;
        }
    }
#endif
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
    NSString *exact3105Detail = nil;
    NSString *exact3105 = FF3105MCMContainerPath(selectedGameIdentifier, &exact3105Detail);
    if (exact3105.length) [paths addObject:exact3105];
    if (lookupDetail && exact3105Detail.length) *lookupDetail = exact3105Detail;
#ifdef FF_3105_MCM
    // If LaunchServices / direct MCM lookup is unavailable, retain the bounded
    // inode and metadata scan. Grants route through worse_query on iOS 26/27.
    if (!exact3105.length) {
        NSString *scanDetail = nil;
        NSString *scanned = FF3105ContainerPathByMetadataScan(selectedGameIdentifier, &scanDetail);
        if (scanned.length) [paths addObject:scanned];
        if (lookupDetail && scanDetail.length) *lookupDetail = scanDetail;
    }
#endif
#endif

    NSError *bridgeError = nil;
    if (FFLoadSandboxBridge(&bridgeError)) {
        NSString *direct = FFMCMDataContainerPath(selectedGameIdentifier, lookupDetail);
        if (direct.length) [paths addObject:direct];
    } else if (lookupDetail && !(*lookupDetail).length) {
        *lookupDetail = bridgeError.localizedDescription;
    }

    // A direct MCM lookup can return no path even when this existing bridge
    // exposes its own virtual root. Probe the exported capability instead of
    // routing by an OS-version number; every candidate is verified later by
    // AccessVerifier before it can become CONNECTED/READY.
    if (FFMCMVirtualRoot) {
        NSString *root = FFMCMVirtualRoot();
        if (root.length && root.isAbsolutePath) {
            // FilzaSlop 1.0.3 creates this class-2 directory when started with
            // unrestricted enumeration. Keep the legacy name as a read-only
            // fallback for devices that already have a pre-migration root.
            for (NSString *directoryName in @[@"[MHA-C2] App Data", @"App Data"]) {
                NSString *appData = [root stringByAppendingPathComponent:directoryName];
                NSString *linked = [appData stringByAppendingPathComponent:selectedGameIdentifier];
                if (linked.length) [paths addObject:linked];
            }
        }
    }
    return paths.array;
}

static NSMutableDictionary<NSString *, NSDictionary *> *FFContainerDiscoveryCache(void) {
    static NSMutableDictionary<NSString *, NSDictionary *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

static NSURL *FFDirectGameContainer(NSString *selectedGameIdentifier,
                                    NSString **gameIdentifier, NSString **gameName,
                                    NSURL **assetBundles, NSError **error) {
    NSDictionary<NSString *, NSString *> *game = FFGameDefinition(selectedGameIdentifier);
    if (!game) {
        if (error) *error = FFError(5, @"Select a supported game first.");
        return nil;
    }
    NSFileManager *manager = NSFileManager.defaultManager;
    // Fresh discovery cache: once the container is resolved for a game, every
    // subsequent apply reuses it instead of re-running the slow MCM/scan flow.
    NSDictionary *cached = FFContainerDiscoveryCache()[selectedGameIdentifier];
    if (cached) {
        NSTimeInterval age = [NSDate.date timeIntervalSince1970] - [cached[@"at"] doubleValue];
        NSString *cachedContainer = [cached[@"container"] isKindOfClass:NSString.class] ? cached[@"container"] : nil;
        NSString *cachedBundles = [cached[@"assetBundles"] isKindOfClass:NSString.class] ? cached[@"assetBundles"] : nil;
        if (age >= 0 && age < 300.0 && cachedContainer.length) {
            BOOL isDirectory = NO;
            NSURL *containerURL = [NSURL fileURLWithPath:cachedContainer isDirectory:YES];
            if ([manager fileExistsAtPath:containerURL.path isDirectory:&isDirectory] && isDirectory) {
                NSURL *bundlesURL = cachedBundles.length
                    ? [NSURL fileURLWithPath:cachedBundles isDirectory:YES] : nil;
                BOOL bundlesOK = bundlesURL &&
                    [manager fileExistsAtPath:bundlesURL.path isDirectory:&isDirectory] && isDirectory;
                if (bundlesOK) {
                    if (gameIdentifier) *gameIdentifier = selectedGameIdentifier;
                    if (gameName) *gameName = game[@"displayName"];
                    if (assetBundles) *assetBundles = bundlesURL;
                    FFDiagnosticLog(@"GameDetector", @"Container cache hit: %@", cachedContainer);
                    return containerURL;
                }
            }
        }
    }
    NSString *lookupDetail = nil;
    NSURL *foundContainer = nil;
    NSError *assetBundleError = nil;
    for (NSString *containerPath in FFGameContainerCandidates(selectedGameIdentifier, &lookupDetail)) {
        NSURL *container = [NSURL fileURLWithPath:containerPath isDirectory:YES];
        BOOL isDirectory = NO;
        if (![manager fileExistsAtPath:container.path isDirectory:&isDirectory] || !isDirectory) continue;
        if (!foundContainer) foundContainer = container;
        NSError *candidateError = nil;
        // Read the container directly when possible, then ALWAYS apply the
        // MCM grants: a readable container is not necessarily writable, and
        // the sandbox extension is what turns read into read/write.
        NSURL *directory = FFFindGameAssetBundles(container, &candidateError);
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
        FF3105GrantContainerTree(containerPath);
        if (!directory) {
            directory = FFFindGameAssetBundles(container, &candidateError);
        }
#endif
        if (directory) {
            FFContainerDiscoveryCache()[selectedGameIdentifier] = @{
                @"container": container.path,
                @"assetBundles": directory.path ?: @"",
                @"at": @([NSDate.date timeIntervalSince1970]),
            };
            if (gameIdentifier) *gameIdentifier = selectedGameIdentifier;
            if (gameName) *gameName = game[@"displayName"];
            if (assetBundles) *assetBundles = directory;
            return container;
        }
        if (!assetBundleError) assetBundleError = candidateError;
    }
    if (foundContainer) {
        // A valid class-2 container proves that the game is installed. The
        // cache may not exist until the game has completed its first launch,
        // so do not report a false "GAME NOT INSTALLED" result on iOS 18.
        if (gameIdentifier) *gameIdentifier = selectedGameIdentifier;
        if (gameName) *gameName = game[@"displayName"];
        if (assetBundles) *assetBundles = nil;
        if (error) *error = assetBundleError ?: FFError(10, @"Game cache is not ready yet.");
        return foundContainer;
    }
    NSString *message = [NSString stringWithFormat:@"%@ is not installed or its container is not available yet.", game[@"displayName"]];
    if (lookupDetail.length) message = [message stringByAppendingFormat:@"\n%@", lookupDetail];
    if (error) *error = FFError(5, message);
    return nil;
}

static NSURL *FFDirectGameAssetBundles(NSString *selectedGameIdentifier,
                                       NSString **gameIdentifier, NSString **gameName, NSError **error) {
    NSURL *directory = nil;
    FFDirectGameContainer(selectedGameIdentifier, gameIdentifier, gameName, &directory, error);
    return directory;
}

static BOOL FFLaunchGame(NSString *gameIdentifier, NSError **error) {
    if (!FFGameDefinition(gameIdentifier)) {
        if (error) *error = FFError(54, @"Select a supported game first.");
        return NO;
    }
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (!workspaceClass || ![workspaceClass respondsToSelector:defaultSelector]) {
        if (error) *error = FFError(54, @"Game launcher is unavailable on this installation.");
        return NO;
    }
    id (*sendWorkspace)(id, SEL) = (void *)objc_msgSend;
    BOOL (*sendOpen)(id, SEL, id) = (void *)objc_msgSend;
    id workspace = sendWorkspace((id)workspaceClass, defaultSelector);
    if (!workspace || ![workspace respondsToSelector:openSelector] ||
        !sendOpen(workspace, openSelector, gameIdentifier)) {
        if (error) *error = FFError(54, @"GAME NOT INSTALLED");
        return NO;
    }
    return YES;
}

static BOOL FFDataLooksLikeUnityBundle(NSData *data) {
    if (data.length < 8) return NO;
    const unsigned char expected[] = {'U','n','i','t','y','F','S',0};
    return memcmp(data.bytes, expected, sizeof(expected)) == 0;
}

static NSString *const FFAssemblyPatchFilename = @"Assembly-CSharp-patch.bytes";
static NSString *const FFLocalConfigFilename = @"localConfig.json";

static BOOL FFParseAssemblyPackage(NSData *packageData, NSData **assemblyOut, NSData **configOut, NSError **error) {
    if (packageData.length < 64 || packageData.length > 10000000) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"Assembly package size is invalid.");
        return NO;
    }
    const uint8_t *bytes = packageData.bytes;
    static const uint8_t magic[8] = {'F','F','A','S','M','0','0','1'};
    if (memcmp(bytes, magic, sizeof(magic)) != 0) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"Assembly package header is invalid.");
        return NO;
    }
    uint32_t manifestLength = FFReadBE32(bytes + 8);
    if (manifestLength == 0 || manifestLength > 65536 ||
        (NSUInteger)12 + (NSUInteger)manifestLength >= packageData.length) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"Assembly package manifest length is invalid.");
        return NO;
    }
    NSData *manifestData = [packageData subdataWithRange:NSMakeRange(12, manifestLength)];
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
    if (![manifest isKindOfClass:NSDictionary.class] ||
        [manifest[@"version"] integerValue] != 1 ||
        ![manifest[@"feature"] isEqualToString:@"ASSEMBLY"]) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"Assembly package manifest is invalid.");
        return NO;
    }
    NSArray *rows = [manifest[@"files"] isKindOfClass:NSArray.class] ? manifest[@"files"] : nil;
    if (rows.count != 2) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"Assembly package must contain exactly two files.");
        return NO;
    }
    NSUInteger payloadStart = 12 + manifestLength;
    NSUInteger payloadLength = packageData.length - payloadStart;
    NSData *assemblyData = nil;
    NSData *configData = nil;
    for (id candidate in rows) {
        if (![candidate isKindOfClass:NSDictionary.class]) return NO;
        NSDictionary *row = candidate;
        NSString *name = [row[@"name"] isKindOfClass:NSString.class] ? row[@"name"] : nil;
        NSNumber *offsetNumber = [row[@"offset"] isKindOfClass:NSNumber.class] ? row[@"offset"] : nil;
        NSNumber *lengthNumber = [row[@"length"] isKindOfClass:NSNumber.class] ? row[@"length"] : nil;
        NSString *expectedHash = [row[@"sha256"] isKindOfClass:NSString.class] ? [row[@"sha256"] lowercaseString] : nil;
        if (!name.length || !offsetNumber || !lengthNumber || !ZXIsSHA256(expectedHash)) return NO;
        unsigned long long offset64 = offsetNumber.unsignedLongLongValue;
        unsigned long long length64 = lengthNumber.unsignedLongLongValue;
        if (length64 == 0 || offset64 > payloadLength || length64 > payloadLength ||
            offset64 + length64 > payloadLength || offset64 + length64 < offset64) {
            return NO;
        }
        NSData *slice = [packageData subdataWithRange:NSMakeRange(payloadStart + (NSUInteger)offset64, (NSUInteger)length64)];
        if (![[ZXDigest(slice) lowercaseString] isEqualToString:expectedHash]) return NO;
        if ([name isEqualToString:FFAssemblyPatchFilename]) {
            NSRange headerRange = NSMakeRange(0, MIN(slice.length, (NSUInteger)64));
            BOOL ifixHeader = slice.length > 8 &&
                [slice rangeOfData:[@"IFix" dataUsingEncoding:NSASCIIStringEncoding]
                           options:0 range:headerRange].location != NSNotFound;
            if ((slice.length < 100000 || slice.length > 2000000) ||
                (!FFDataLooksLikeUnityBundle(slice) && !ifixHeader)) {
                return NO;
            }
            assemblyData = slice;
        } else if ([name isEqualToString:FFLocalConfigFilename]) {
            id json = [NSJSONSerialization JSONObjectWithData:slice options:0 error:nil];
            if (![json isKindOfClass:NSDictionary.class] || ![json[@"testCodePatch"] boolValue]) {
                return NO;
            }
            configData = slice;
        } else {
            return NO;
        }
    }
    if (!assemblyData.length || !configData.length) return NO;
    if (assemblyOut) *assemblyOut = assemblyData;
    if (configOut) *configOut = configData;
    return YES;
}

static NSData *FFDecryptWrappedPayload(NSData *encrypted, NSString *nonceHex,
                                       NSString *featureToken, NSString *accessToken) {
    if (!encrypted.length || !nonceHex.length || !featureToken.length || !accessToken.length) return nil;
    NSString *liveText = nil, *liveCString = nil;
    if (!FFLiveInMemorySectionHashes(&liveText, &liveCString) || !liveText.length || !liveCString.length) {
        return nil;
    }
    NSString *seedMaterial = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@",
        featureToken, accessToken, liveText, liveCString, FFCORE_TEXT_SHA256_A, nonceHex.lowercaseString];
    NSData *seedInput = [seedMaterial dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t seed[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(seedInput.bytes, (CC_LONG)seedInput.length, seed);

    NSMutableData *decrypted = [NSMutableData dataWithLength:encrypted.length];
    const uint8_t *src = encrypted.bytes;
    uint8_t *dst = decrypted.mutableBytes;
    size_t total = encrypted.length;
    uint32_t counter = 0;
    uint8_t blockInput[CC_SHA256_DIGEST_LENGTH + 4];
    memcpy(blockInput, seed, CC_SHA256_DIGEST_LENGTH);
    uint8_t keystream[CC_SHA256_DIGEST_LENGTH];

    for (size_t offset = 0; offset < total; offset += CC_SHA256_DIGEST_LENGTH, ++counter) {
        blockInput[CC_SHA256_DIGEST_LENGTH + 0] = (uint8_t)((counter >> 24) & 0xFF);
        blockInput[CC_SHA256_DIGEST_LENGTH + 1] = (uint8_t)((counter >> 16) & 0xFF);
        blockInput[CC_SHA256_DIGEST_LENGTH + 2] = (uint8_t)((counter >> 8) & 0xFF);
        blockInput[CC_SHA256_DIGEST_LENGTH + 3] = (uint8_t)(counter & 0xFF);
        CC_SHA256(blockInput, sizeof(blockInput), keystream);
        size_t chunk = (total - offset < CC_SHA256_DIGEST_LENGTH) ? (total - offset) : CC_SHA256_DIGEST_LENGTH;
        for (size_t i = 0; i < chunk; ++i) {
            dst[offset + i] = src[offset + i] ^ keystream[i];
        }
    }
    return decrypted;
}

static NSURL *FFGameDocumentsDirectory(NSURL *root, NSError **error) {
    if (!root) {
        if (error) *error = FFNamedError(62, @"DOCUMENTS_NOT_FOUND", @"The game container is unavailable.");
        return nil;
    }
    NSFileManager *manager = NSFileManager.defaultManager;
    if ([root.lastPathComponent caseInsensitiveCompare:@"Documents"] == NSOrderedSame) return root;
    NSURL *direct = [root URLByAppendingPathComponent:@"Documents" isDirectory:YES];
    BOOL isDirectory = NO;
    if ([manager fileExistsAtPath:direct.path isDirectory:&isDirectory] && isDirectory) return direct;
    NSArray<NSURL *> *children = [manager contentsOfDirectoryAtURL:root
                                        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             error:nil];
    for (NSURL *child in children) {
        NSNumber *childIsDirectory = nil;
        if ([child getResourceValue:&childIsDirectory forKey:NSURLIsDirectoryKey error:nil] &&
            childIsDirectory.boolValue &&
            [child.lastPathComponent caseInsensitiveCompare:@"Documents"] == NSOrderedSame) {
            return child;
        }
    }
    if (error) *error = FFNamedError(62, @"DOCUMENTS_NOT_FOUND", @"The game's Documents folder was not found.");
    return nil;
}

static NSString *ZXDigest(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) [hex appendFormat:@"%02x", digest[index]];
    return hex;
}

static NSString *FFHardwareModel(void) {
    struct utsname systemInfo;
    if (uname(&systemInfo) != 0) return @"unknown";
    return [NSString stringWithUTF8String:systemInfo.machine] ?: @"unknown";
}

static NSString *FFAPIErrorMessage(NSDictionary *json, NSString *fallback) {
    id value = [json isKindOfClass:NSDictionary.class] ? json[@"error"] : nil;
    if ([value isKindOfClass:NSString.class] && [value length]) return value;
    if ([value isKindOfClass:NSDictionary.class]) {
        NSString *message = value[@"message"];
        if ([message isKindOfClass:NSString.class] && message.length) return message;
    }
    return fallback;
}

// ---------------------------------------------------------------------------
// Response signing verification (RSA-2048 PSS-SHA256).
//
// The server wraps critical responses as
//   { "data": {...}, "sig_alg": "RSA-PSS-SHA256",
//     "sig_ts": <epoch>, "sig_nonce": <hex>, "sig": <base64> }
// Signing input is exactly "<sig_ts>|<sig_nonce>|<canonical_json(data)>".
//
// Release builds define FF_REQUIRE_SIGNED_RESPONSES and fail closed when a
// successful JSON response is unsigned, stale, malformed, or invalid.
// ---------------------------------------------------------------------------
static NSString *const FFResponseSigningPublicKeyPEM =
    @"-----BEGIN PUBLIC KEY-----\nPUBLIC-KEY-REMOVED\n-----END PUBLIC KEY-----";

static SecKeyRef FFLoadSigningPublicKey(void) {
    static SecKeyRef cached = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *pem = FFResponseSigningPublicKeyPEM;
        NSMutableString *body = [pem mutableCopy];
        [body replaceOccurrencesOfString:@"-----BEGIN PUBLIC KEY-----" withString:@""
                                 options:0 range:NSMakeRange(0, body.length)];
        [body replaceOccurrencesOfString:@"-----END PUBLIC KEY-----" withString:@""
                                 options:0 range:NSMakeRange(0, body.length)];
        [body replaceOccurrencesOfString:@"\n" withString:@""
                                 options:0 range:NSMakeRange(0, body.length)];
        [body replaceOccurrencesOfString:@"\r" withString:@""
                                 options:0 range:NSMakeRange(0, body.length)];
        [body replaceOccurrencesOfString:@" " withString:@""
                                 options:0 range:NSMakeRange(0, body.length)];
        NSData *spki = [[NSData alloc] initWithBase64EncodedString:body options:0];
        if (spki.length <= 24) return;
        NSData *pkcs1 = [spki subdataWithRange:NSMakeRange(24, spki.length - 24)];
        NSDictionary *attrs = @{
            (__bridge id)kSecAttrKeyType:  (__bridge id)kSecAttrKeyTypeRSA,
            (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
            (__bridge id)kSecAttrKeySizeInBits: @2048,
        };
        CFErrorRef err = NULL;
        cached = SecKeyCreateWithData((__bridge CFDataRef)pkcs1, (__bridge CFDictionaryRef)attrs, &err);
        if (err) { CFRelease(err); err = NULL; }
        if (!cached) {
            cached = SecKeyCreateWithData((__bridge CFDataRef)spki, (__bridge CFDictionaryRef)attrs, &err);
            if (err) CFRelease(err);
        }
    });
    return cached;
}

static NSDictionary *FFVerifySignedResponse(NSDictionary *envelope, NSError **error) {
    NSString *sigAlg = envelope[@"sig_alg"];
    if (![sigAlg isEqualToString:@"RSA-PSS-SHA256"]) {
        if (error) *error = FFError(60, @"Server signature algorithm is unsupported.");
        return nil;
    }
    NSDictionary *data = envelope[@"data"];
    NSNumber *tsNum   = envelope[@"sig_ts"];
    NSString *nonce   = envelope[@"sig_nonce"];
    NSString *sigB64  = envelope[@"sig"];
    if (![data isKindOfClass:NSDictionary.class] || ![tsNum isKindOfClass:NSNumber.class] ||
        ![nonce isKindOfClass:NSString.class]    || ![sigB64 isKindOfClass:NSString.class]) {
        if (error) *error = FFError(61, @"Server signature envelope is malformed.");
        return nil;
    }
    NSTimeInterval ts  = tsNum.doubleValue;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (fabs(now - ts) > 300.0) {
        if (error) *error = FFError(62, @"Server response is outside the allowed clock window.");
        return nil;
    }
    NSData *canonical = [NSJSONSerialization dataWithJSONObject:data
        options:NSJSONWritingSortedKeys error:nil];
    if (!canonical) {
        if (error) *error = FFError(63, @"Could not canonicalize the server response.");
        return nil;
    }
    NSString *canonicalString = [[NSString alloc] initWithData:canonical encoding:NSUTF8StringEncoding];
    NSString *signingInput = [NSString stringWithFormat:@"%lld|%@|%@",
        (long long)ts, nonce, canonicalString];
    NSData *inputBytes = [signingInput dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sigBytes = [[NSData alloc] initWithBase64EncodedString:sigB64 options:0];
    if (!sigBytes.length || !inputBytes.length) {
        if (error) *error = FFError(64, @"Server signature payload is malformed.");
        return nil;
    }
    SecKeyRef key = FFLoadSigningPublicKey();
    if (!key) {
        if (error) *error = FFError(65, @"Server signing key is unavailable to the app.");
        return nil;
    }
    CFErrorRef verifyErr = NULL;
    Boolean ok = SecKeyVerifySignature(key, kSecKeyAlgorithmRSASignatureMessagePSSSHA256,
                                       (__bridge CFDataRef)inputBytes,
                                       (__bridge CFDataRef)sigBytes, &verifyErr);
    if (verifyErr) { CFRelease(verifyErr); verifyErr = NULL; }
    if (!ok) {
        NSString *unescaped = [canonicalString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        NSString *altSigningInput = [NSString stringWithFormat:@"%lld|%@|%@",
            (long long)ts, nonce, unescaped];
        NSData *altBytes = [altSigningInput dataUsingEncoding:NSUTF8StringEncoding];
        if (altBytes.length) {
            ok = SecKeyVerifySignature(key, kSecKeyAlgorithmRSASignatureMessagePSSSHA256,
                                       (__bridge CFDataRef)altBytes,
                                       (__bridge CFDataRef)sigBytes, &verifyErr);
            if (verifyErr) { CFRelease(verifyErr); verifyErr = NULL; }
        }
    }
    if (!ok) {
        if (error) *error = FFError(66, @"Server signature verification failed.");
        return nil;
    }
    return data;
}

// ---------------------------------------------------------------------------
// TLS certificate pinning: only the activation server's own certificate and
// its Let's Encrypt chain (leaf + intermediate + roots) are accepted. A
// custom-CA MITM (SSL Kill Switch, Burp/Charles on-device proxies) cannot
// complete the handshake, so requests, tokens and keys never reach a sniffer.
// ---------------------------------------------------------------------------
static NSArray<NSString *> *FFPinnedCertificateHashes(void) {
    return @[
        // server leaf certificate (renews automatically with Let's Encrypt)
        @"0000000000000000000000000000000000000000000000000000000000000000",
        // Let's Encrypt intermediate YR2 (valid to 2028)
        @"0000000000000000000000000000000000000000000000000000000000000000",
        // ISRG Root YR (valid to 2032)
        @"0000000000000000000000000000000000000000000000000000000000000000",
        // ISRG Root X1 (valid to 2035)
        @"0000000000000000000000000000000000000000000000000000000000000000",
    ];
}

@interface FFSecureSessionDelegate : NSObject <NSURLSessionDelegate>
@end

@implementation FFSecureSessionDelegate
- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if (![challenge.protectionSpace.authenticationMethod
            isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (!trust) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    CFErrorRef evaluationError = NULL;
    BOOL evaluated = SecTrustEvaluateWithError(trust, &evaluationError);
    if (evaluationError) CFRelease(evaluationError);
    if (!evaluated) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    NSSet<NSString *> *allowed = [NSSet setWithArray:FFPinnedCertificateHashes()];
    BOOL pinned = NO;
    CFIndex certificateCount = SecTrustGetCertificateCount(trust);
    for (CFIndex index = 0; index < certificateCount; index++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, index);
        if (!certificate) continue;
        NSData *der = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);
        NSString *hash = [ZXDigest(der) lowercaseString];
        if ([allowed containsObject:hash]) {
            pinned = YES;
            break;
        }
    }
    if (!pinned) {
        FFDiagnosticLog(@"Security", @"TLS PIN MISMATCH — connection cancelled");
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}
@end

static NSURLSession *FFSecureURLSession(void) {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.URLCache = nil;
        // Bypass system proxy entirely: simple MITM proxies (Burp/Charles/
        // fiddler-style tweaks) get nothing even before TLS pinning runs.
        config.connectionProxyDictionary = @{};
        static FFSecureSessionDelegate *delegate;
        delegate = [FFSecureSessionDelegate new];
        session = [NSURLSession sessionWithConfiguration:config
                                                delegate:delegate
                                           delegateQueue:nil];
    });
    return session;
}

static void FFJSONRequest(NSString *method, NSString *path, NSDictionary *body, NSString *accessToken,
                          void (^completion)(NSDictionary *json, NSError *error)) {
    if (!FFSecuritySensitiveOperationAllowed()) {
        completion(nil, FFError(69, @"Security verification failed. Restart the official app."));
        return;
    }
    NSString *installationID = ZXInstallID();
    if (!installationID.length) {
        completion(nil, FFError(30, @"Installation identity is unavailable."));
        return;
    }
    NSURL *requestURL = [NSURL URLWithString:[FFAPIBaseURL() stringByAppendingString:path ?: @""]];
    if (!FFURLTargetsOfficialAPI(requestURL)) {
        completion(nil, FFError(69, @"Security verification failed for the API endpoint."));
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    request.HTTPMethod = method;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:installationID forHTTPHeaderField:@"X-Installation-ID"];
    if (accessToken.length) {
        [request setValue:[@"Bearer " stringByAppendingString:accessToken] forHTTPHeaderField:@"Authorization"];
    }
    if (body) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        if (!request.HTTPBody) {
            completion(nil, FFError(31, @"Could not create the secure request."));
            return;
        }
    }
    NSURLSessionDataTask *task = [FFSecureURLSession() dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
            if (networkError) {
                completion(nil, FFError(32, @"Activation server is unavailable. Check the internet connection."));
                return;
            }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSDictionary *json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (http.statusCode < 200 || http.statusCode >= 300) {
                id errorValue = [json isKindOfClass:NSDictionary.class] ? json[@"error"] : nil;
                NSString *errorCode = [errorValue isKindOfClass:NSDictionary.class]
                    ? errorValue[@"code"] : nil;
                if ([errorCode isKindOfClass:NSString.class] &&
                    [errorCode isEqualToString:@"CHANNEL_VERIFICATION_REQUIRED"]) {
                    completion(nil, FFError(70, FFAPIErrorMessage(json,
                        @"STfamily FF channel verification is required.")));
                    return;
                }
                completion(nil, FFError(33, FFAPIErrorMessage(json, @"Server authorization failed.")));
                return;
            }
            if ([json isKindOfClass:NSDictionary.class] && json[@"sig_alg"]) {
                NSError *sigErr = nil;
                NSDictionary *verified = FFVerifySignedResponse(json, &sigErr);
                if (sigErr || !verified) {
                    completion(nil, sigErr ?: FFError(67, @"Server signature verification failed."));
                    return;
                }
                json = verified;
            }
#ifdef FF_REQUIRE_SIGNED_RESPONSES
            else {
                completion(nil, FFError(68, @"Server response is unsigned but signing is required."));
                return;
            }
#endif
            if (![json isKindOfClass:NSDictionary.class] || ![json[@"success"] boolValue]) {
                completion(nil, FFError(34, @"Activation server returned an invalid response."));
                return;
            }
            completion(json, nil);
        }];
    [task resume];
}

static NSArray<NSString *> *FFIntegrityFieldOrder(void) {
    return @[
        @"app_text_sha256", @"app_cstring_sha256",
        @"core_a_text_sha256", @"core_a_export_sha256",
        @"core_b_text_sha256", @"core_b_export_sha256",
        @"info_plist_sha256", @"framework_plist_sha256",
        @"bundle_identifier", @"display_name", @"app_version", @"build_version"
    ];
}

static void ZXProof(NSString *purpose, NSString *context,
                    void (^completion)(NSDictionary *proof, NSError *error)) {
    NSDictionary *integrity = FFIntegrityReport();
    NSString *installationID = ZXInstallID();
    if (!integrity || !installationID.length) {
        NSString *detail = FFIntegrityFailureDetail.length
            ? [NSString stringWithFormat:@" (step: %@)", FFIntegrityFailureDetail] : @"";
        completion(nil, FFError(43, [NSString stringWithFormat:@"Application measurement failed%@.", detail]));
        return;
    }
    NSString *safeContext = context ?: @"";
    FFJSONRequest(@"POST", @"/integrity/challenge", @{
        @"installation_id": installationID,
        @"purpose": purpose,
        @"context": safeContext
    }, nil, ^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSString *challenge = [json[@"challenge"] isKindOfClass:NSString.class] ? json[@"challenge"] : nil;
        if (!challenge.length) {
            completion(nil, FFError(44, @"Security challenge response is invalid."));
            return;
        }
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (NSString *field in FFIntegrityFieldOrder()) [values addObject:integrity[field] ?: @""];
        NSString *fingerprint = ZXDigest([[values componentsJoinedByString:@"|"] dataUsingEncoding:NSUTF8StringEncoding]);
        NSString *binding = [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            challenge, purpose, installationID, safeContext, fingerprint];
        NSString *requestHash = ZXDigest([binding dataUsingEncoding:NSUTF8StringEncoding]);
        completion(@{
            @"challenge": challenge,
            @"request_hash": requestHash,
            @"integrity": integrity
        }, nil);
    });
}

static BOOL ZXPersist(NSDictionary *session) {
    NSString *accessToken = [session[@"access_token"] isKindOfClass:NSString.class] ? session[@"access_token"] : nil;
    NSString *refreshToken = [session[@"refresh_token"] isKindOfClass:NSString.class] ? session[@"refresh_token"] : nil;
    if (![accessToken hasPrefix:@"ffa_"] || ![refreshToken hasPrefix:@"ffr_"]) return NO;
    if (!FFKeychainWrite(FFAccessTokenAccount, accessToken)) return NO;
    if (!FFKeychainWrite(FFRefreshTokenAccount, refreshToken)) {
        FFClearSession();
        return NO;
    }
    return YES;
}

static void FFActivateLicense(NSString *licenseKey, void (^completion)(NSDictionary *response, NSError *error)) {
    NSString *trimmed = [licenseKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *installationID = ZXInstallID();
    if (!trimmed.length || !installationID.length) {
        completion(nil, FFError(35, @"Enter the owner license key."));
        return;
    }
    ZXProof(@"activation", @"", ^(NSDictionary *proof, NSError *proofError) {
        if (proofError) {
            completion(nil, proofError);
            return;
        }
        NSDictionary *payload = @{
            @"license_key": trimmed,
            @"installation_id": installationID,
            @"device_model": FFHardwareModel(),
            @"ios_version": UIDevice.currentDevice.systemVersion ?: @"unknown",
            @"app_version": NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"unknown",
            @"proof": proof
        };
        FFJSONRequest(@"POST", @"/license/activate", payload, nil, completion);
    });
}

static void ZXRenew(void (^completion)(NSDictionary *response, NSError *error)) {
    NSString *refreshToken = FFKeychainRead(FFRefreshTokenAccount);
    NSString *installationID = ZXInstallID();
    if (!refreshToken.length || !installationID.length) {
        completion(nil, FFError(36, @"Session refresh is unavailable. Activate the license again."));
        return;
    }
    ZXProof(@"refresh", @"", ^(NSDictionary *proof, NSError *proofError) {
        if (proofError) {
            completion(nil, proofError);
            return;
        }
        FFJSONRequest(@"POST", @"/session/refresh", @{
            @"refresh_token": refreshToken,
            @"installation_id": installationID,
            @"proof": proof
        }, nil, completion);
    });
}

static void FFValidateSession(NSString *accessToken, void (^completion)(NSDictionary *response, NSError *error)) {
    if (!accessToken.length) {
        completion(nil, FFError(37, @"Session is unavailable."));
        return;
    }
    FFJSONRequest(@"GET", @"/session/validate", nil, accessToken, completion);
}

static void FFFetchChannelStatus(NSString *installationID,
                                 void (^completion)(NSDictionary *response, NSError *error)) {
    if (!installationID.length) {
        completion(nil, FFError(30, @"Installation identity is unavailable."));
        return;
    }
    NSString *escaped = [installationID stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/channel/status?installation_id=%@", escaped ?: @""];
    FFJSONRequest(@"GET", path, nil, nil, completion);
}

static void FFLogoutSession(NSString *accessToken, void (^completion)(NSError *error)) {
    if (!accessToken.length) {
        if (completion) completion(nil);
        return;
    }
    FFJSONRequest(@"POST", @"/session/logout", @{}, accessToken,
        ^(NSDictionary *response, NSError *error) {
            (void)response;
            if (completion) completion(error);
        });
}

static void FFFetchServiceStatus(void (^completion)(NSDictionary *response, NSError *error)) {
    FFJSONRequest(@"GET", @"/status", nil, nil, completion);
}

static void FFFetchFeatureCatalog(NSString *gameIdentifier, NSString *accessToken,
                                  void (^completion)(NSSet<NSString *> *planFeatures,
                                                     NSSet<NSString *> *serverFeatures,
                                                     NSError *error)) {
    if (!FFGameDefinition(gameIdentifier) || !accessToken.length) {
        completion(nil, nil, FFError(38, @"A supported game and active session are required."));
        return;
    }
    NSString *escapedGame = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/feature/catalog?game=%@", escapedGame ?: @""];
    FFJSONRequest(@"GET", path, nil, accessToken, ^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }
        NSDictionary *game = [json[@"game"] isKindOfClass:NSDictionary.class] ? json[@"game"] : nil;
        NSString *responseGame = [game[@"bundle_identifier"] isKindOfClass:NSString.class]
            ? game[@"bundle_identifier"] : nil;
        NSArray *rows = [game[@"features"] isKindOfClass:NSArray.class] ? game[@"features"] : nil;
        if (![responseGame isEqualToString:gameIdentifier] || !rows) {
            completion(nil, nil, FFError(38, @"Feature catalog response is invalid."));
            return;
        }
        NSMutableSet<NSString *> *plan = [NSMutableSet set];
        NSMutableSet<NSString *> *available = [NSMutableSet set];
        NSSet<NSString *> *local = FFLocalFeaturesForGame(gameIdentifier);
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSString *wire = [row[@"id"] isKindOfClass:NSString.class] ? row[@"id"] : nil;
            NSString *feature = ZXLabelFeature(wire) ?: ([local containsObject:wire] ? wire : nil);
            if (!feature || ![local containsObject:feature]) continue;
            if ([row[@"plan_authorized"] boolValue]) [plan addObject:feature];
            if ([row[@"server_available"] boolValue]) [available addObject:feature];
        }
        completion(plan, available, nil);
    });
}

static void ZXGrant(NSString *feature, NSString *gameIdentifier, NSString *accessToken,
                    void (^completion)(NSString *featureToken, NSString *profileHash, NSError *error)) {
    NSString *wireFeature = ZXWireFeature(feature);
    if (!wireFeature.length || !FFGameDefinition(gameIdentifier) ||
        ![FFLocalFeaturesForGame(gameIdentifier) containsObject:feature]) {
        completion(nil, nil, FFError(38, @"Option authorization response is invalid."));
        return;
    }
#ifdef FF_OFFLINE_BUILD
    (void)accessToken;
    completion(@"ffg_offline", nil, nil);
    return;
#endif
    NSString *context = [NSString stringWithFormat:@"%@|%@", gameIdentifier, wireFeature];
    ZXProof(@"feature", context, ^(NSDictionary *proof, NSError *proofError) {
        if (proofError) {
            completion(nil, nil, proofError);
            return;
        }
        FFJSONRequest(@"POST", @"/feature/authorize", @{
            @"feature": wireFeature, @"game": gameIdentifier, @"proof": proof
        }, accessToken, ^(NSDictionary *json, NSError *error) {
            if (error) {
                completion(nil, nil, error);
                return;
            }
            NSDictionary *authorization = [json[@"authorization"] isKindOfClass:NSDictionary.class] ? json[@"authorization"] : nil;
            NSString *token = [authorization[@"token"] isKindOfClass:NSString.class] ? authorization[@"token"] : nil;
            NSString *authorizedGame = [authorization[@"game"] isKindOfClass:NSString.class] ? authorization[@"game"] : nil;
            NSString *authorizedFeature = [authorization[@"feature"] isKindOfClass:NSString.class] ? authorization[@"feature"] : nil;
            NSString *profileHash = [authorization[@"profile_sha256"] isKindOfClass:NSString.class]
                ? [authorization[@"profile_sha256"] lowercaseString] : nil;
            BOOL coreFeature = [@[@"BODY", @"DRAG", @"NECK", @"CHEST", @"MAGIC", @"ESP", @"SKIN_HOLO"]
                containsObject:feature.uppercaseString];
            if (![token hasPrefix:@"ffg_"] || ![authorizedGame isEqualToString:gameIdentifier] ||
                ![authorizedFeature isEqualToString:wireFeature] ||
                (coreFeature && !ZXIsSHA256(profileHash))) {
                completion(nil, nil, FFError(38, @"Feature authorization response is invalid."));
                return;
            }
            completion(token, coreFeature ? profileHash : nil, nil);
        });
    });
}

static void ZXFetch(NSString *feature, NSString *gameIdentifier, NSString *color, NSString *expectedHash,
                    NSString *accessToken, NSString *featureToken,
                    void (^completion)(NSData *data, NSError *error)) {
#ifdef FF_OFFLINE_BUILD
    (void)accessToken; (void)featureToken; (void)color; (void)expectedHash;
    if (!FFGameDefinition(gameIdentifier) ||
        ![FFLocalFeaturesForGame(gameIdentifier) containsObject:feature]) {
        completion(nil, FFError(39, @"Feature is not available for the selected game."));
        return;
    }
    // Keep data resources extension-qualified.  ESign and similar tools scan
    // extensionless bundle files as candidate Mach-O executables; naming a
    // UnityFS payload BODY/DRAG/NECK without an extension makes those signers
    // reject the whole .app before certificate selection.
    NSString *offlinePath = [[NSBundle mainBundle] pathForResource:feature
                                                            ofType:@"ffcache"
                                                       inDirectory:@"OfflineCache"];
    NSData *offlineData = offlinePath ? [NSData dataWithContentsOfFile:offlinePath] : nil;
    if (!offlineData.length) {
        completion(nil, FFError(40, @"Offline profile not bundled for this feature."));
        return;
    }
    if (![feature isEqualToString:@"HOLOGRAM_GUN"] && !FFDataLooksLikeUnityBundle(offlineData)) {
        completion(nil, FFError(42, @"Bundled offline profile is not a valid UnityFS cache."));
        return;
    }
    completion(offlineData, nil);
    return;
#endif
    if (!FFSecuritySensitiveOperationAllowed()) {
        completion(nil, FFError(69, @"Security verification failed. Restart the official app."));
        return;
    }
    NSString *installationID = ZXInstallID();
    NSString *wireFeature = ZXWireFeature(feature);
    if (!installationID.length || !accessToken.length || !featureToken.length ||
        !FFGameDefinition(gameIdentifier) ||
        ![FFLocalFeaturesForGame(gameIdentifier) containsObject:feature]) {
        completion(nil, FFError(39, @"Feature authorization is required."));
        return;
    }
    if (!wireFeature.length) {
        completion(nil, FFError(39, @"Option authorization is unavailable."));
        return;
    }
    NSString *escapedGame = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *endpoint = [NSString stringWithFormat:@"%@/profile/%@?game=%@",
        FFAPIBaseURL(), wireFeature, escapedGame ?: @""];
    if (color.length) {
        NSString *escapedColor = [color stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
        endpoint = [endpoint stringByAppendingFormat:@"&color=%@", escapedColor ?: @""];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    [request setValue:[@"Bearer " stringByAppendingString:accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:installationID forHTTPHeaderField:@"X-Installation-ID"];
    [request setValue:featureToken forHTTPHeaderField:@"X-Feature-Token"];
    [request setValue:@"FFC1" forHTTPHeaderField:@"X-Payload-Wrap"];
    NSString *buildVer = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"";
    if (buildVer.length) [request setValue:buildVer forHTTPHeaderField:@"X-Client-Build"];
    NSURLSessionDataTask *task = [FFSecureURLSession() dataTaskWithRequest:request
        completionHandler:^(NSData *rawData, NSURLResponse *response, NSError *networkError) {
            if (networkError) {
                completion(nil, FFError(40, @"Could not download the selected option."));
                return;
            }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode < 200 || http.statusCode >= 300) {
                NSDictionary *json = rawData.length ? [NSJSONSerialization JSONObjectWithData:rawData options:0 error:nil] : nil;
                completion(nil, FFError(41, FFAPIErrorMessage(json, @"The selected option is unavailable.")));
                return;
            }
            NSData *data = rawData;
            NSString *wrapNonce = [http valueForHTTPHeaderField:@"X-Payload-Nonce"];
            if (wrapNonce.length) {
                data = FFDecryptWrappedPayload(rawData, wrapNonce, featureToken, accessToken);
                if (!data.length) {
                    completion(nil, FFError(42, @"Downloaded option failed binary-bound decryption."));
                    return;
                }
            }
            NSString *normalized = feature.uppercaseString;
            NSString *serverHash = [[http valueForHTTPHeaderField:@"X-Profile-SHA256"] lowercaseString];
            NSString *responseGame = [http valueForHTTPHeaderField:@"X-Game-Identifier"];
            // Core hashes come from the RSA-signed one-use authorization;
            // colored resources keep using their signed catalog selection.
            NSString *authorizedHash = expectedHash.lowercaseString;
            NSString *actualHash = [ZXDigest(data) lowercaseString];
            BOOL validFormat = NO;
            if ([@[@"BODY", @"DRAG", @"NECK", @"CHEST", @"MAGIC"] containsObject:normalized]) {
                validFormat = data.length >= 40000 && data.length <= 150000 && FFDataLooksLikeUnityBundle(data);
            } else if ([normalized isEqualToString:@"SKIN_HOLO"]) {
                validFormat = data.length >= 100000 && data.length <= 2000000 &&
                    FFDataLooksLikeUnityBundle(data);
            } else if ([normalized isEqualToString:@"ESP"]) {
                validFormat = FFDataLooksLikeESPPackage(data, gameIdentifier);
            } else if ([normalized isEqualToString:@"HOLOGRAM_GUN"]) {
                validFormat = data.length > 1000000 && data.length < 30000000 &&
                    FFDataLooksLikeUnityBundle(data);
            } else if ([normalized isEqualToString:@"THREE_D"]) {
                validFormat = data.length >= 100000 && data.length <= 2000000 &&
                    FFDataLooksLikeUnityBundle(data);
            }
            if (!validFormat || !ZXIsSHA256(serverHash) || !ZXIsSHA256(authorizedHash) ||
                ![responseGame isEqualToString:gameIdentifier] ||
                ![actualHash isEqualToString:authorizedHash] ||
                ![serverHash isEqualToString:actualHash]) {
                completion(nil, FFError(42, @"Downloaded option failed integrity validation."));
                return;
            }
            completion(data, nil);
        }];
    [task resume];
}

static BOOL ZXIsSHA256(NSString *value) {
    if (value.length != 64) return NO;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    return [[value lowercaseString] rangeOfCharacterFromSet:invalid].location == NSNotFound;
}

static void ZXFeatureColors(NSString *feature, NSString *gameIdentifier, NSString *accessToken,
                            void (^completion)(NSArray<NSDictionary *> *colors, NSError *error)) {
    NSString *installationID = ZXInstallID();
    BOOL hologram = [feature isEqualToString:@"HOLOGRAM_GUN"];
    BOOL threeD = [feature isEqualToString:@"THREE_D"];
    if (!installationID.length || !accessToken.length || (!hologram && !threeD) ||
        (hologram && ![gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) ||
        !FFGameDefinition(gameIdentifier)) {
        completion(nil, FFError(39, @"Feature authorization is required."));
        return;
    }
    NSString *escapedGame = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *route = hologram ? @"hologram" : @"3d";
    NSString *display = hologram ? @"Hologram" : @"3D";
    NSURL *url = [NSURL URLWithString:[FFAPIBaseURL() stringByAppendingFormat:
        @"/%@/colors?game=%@", route, escapedGame ?: @""]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    [request setValue:[@"Bearer " stringByAppendingString:accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:installationID forHTTPHeaderField:@"X-Installation-ID"];
    NSURLSessionDataTask *task = [FFSecureURLSession() dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
            if (networkError) {
                completion(nil, FFError(40, [NSString stringWithFormat:@"Could not load %@ options.", display]));
                return;
            }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSDictionary *json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (http.statusCode < 200 || http.statusCode >= 300) {
                completion(nil, FFError(41, FFAPIErrorMessage(json,
                    [NSString stringWithFormat:@"%@ options are unavailable.", display])));
                return;
            }
            NSArray *rows = [json[@"colors"] isKindOfClass:NSArray.class] ? json[@"colors"] : nil;
            NSString *responseGame = [json[@"game"] isKindOfClass:NSString.class] ? json[@"game"] : nil;
            if (![responseGame isEqualToString:gameIdentifier]) {
                completion(nil, FFError(41, [NSString stringWithFormat:@"%@ game validation failed.", display]));
                return;
            }
            NSMutableArray<NSDictionary *> *valid = [NSMutableArray array];
            NSCharacterSet *colorCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
            for (NSDictionary *row in rows) {
                NSString *name = [row[@"name"] isKindOfClass:NSString.class] ? row[@"name"] : nil;
                NSString *label = [row[@"label"] isKindOfClass:NSString.class] ? row[@"label"] : nil;
                NSString *hash = [row[@"sha256"] isKindOfClass:NSString.class] ? row[@"sha256"] : nil;
                if (!name.length || name.length > 48 || [name rangeOfCharacterFromSet:colorCharacters.invertedSet].location != NSNotFound || !ZXIsSHA256(hash)) continue;
                [valid addObject:@{@"name": name, @"label": label.length ? label : name, @"sha256": hash.lowercaseString}];
            }
            if (threeD) {
                NSArray *expected = @[@"BLACK", @"PINK", @"BLUE"];
                NSArray *received = [valid valueForKey:@"name"];
                if (![received isEqualToArray:expected]) {
                    completion(nil, FFNamedError(53, @"ASSET_NOT_FOUND", @"3D catalog must contain exactly Black, Pink, and Blue."));
                    return;
                }
            } else if (!valid.count) {
                completion(nil, FFNamedError(53, @"ASSET_NOT_FOUND", @"No Hologram colors are available."));
                return;
            }
            completion(valid, nil);
        }];
    [task resume];
}

@interface FFProgressDataDelegate : NSObject <NSURLSessionDataDelegate>
@property(nonatomic, strong) NSMutableData *data;
@property(nonatomic, strong) NSHTTPURLResponse *response;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, copy) void (^progress)(int64_t received, int64_t expected);
@property(nonatomic, copy) void (^completion)(NSData *data, NSHTTPURLResponse *response, NSError *error);
@end

@implementation FFProgressDataDelegate
- (instancetype)init {
    if ((self = [super init])) _data = [NSMutableData data];
    return self;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
 didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    (void)session; (void)task;
    self.response = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    if (self.progress) self.progress(0, response.expectedContentLength);
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    (void)session;
    [self.data appendData:data];
    if (self.progress) self.progress((int64_t)self.data.length, task.response.expectedContentLength);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session; (void)task;
    void (^completion)(NSData *, NSHTTPURLResponse *, NSError *) = self.completion;
    NSData *data = self.data.copy;
    NSHTTPURLResponse *response = self.response;
    [self.session finishTasksAndInvalidate];
    self.session = nil;
    self.completion = nil;
    self.progress = nil;
    if (completion) completion(data, response, error);
}
@end

static void FFDownloadDataWithProgress(NSURLRequest *request,
                                       void (^progress)(int64_t received, int64_t expected),
                                       void (^completion)(NSData *data, NSHTTPURLResponse *response, NSError *error)) {
    FFProgressDataDelegate *delegate = [FFProgressDataDelegate new];
    delegate.progress = progress;
    delegate.completion = completion;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.URLCache = nil;
    configuration.connectionProxyDictionary = @{};
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
    delegate.session = session;
    [[session dataTaskWithRequest:request] resume];
}

static NSMutableURLRequest *FFProtectedRawRequest(NSString *path, NSString *accessToken, NSString *featureToken) {
    if (!FFSecuritySensitiveOperationAllowed()) return nil;
    NSString *installationID = ZXInstallID();
    if (!installationID.length || !accessToken.length || !path.length) return nil;
    NSURL *url = [NSURL URLWithString:[FFAPIBaseURL() stringByAppendingString:path ?: @""]];
    if (!FFURLTargetsOfficialAPI(url)) return nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    [request setValue:[@"Bearer " stringByAppendingString:accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:installationID forHTTPHeaderField:@"X-Installation-ID"];
    if (featureToken.length) [request setValue:featureToken forHTTPHeaderField:@"X-Feature-Token"];
    return request;
}

static BOOL FFSkinIDIsSafe(NSString *skinID) {
    if (!skinID.length || skinID.length > 64) return NO;
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"^[A-Z][A-Z0-9_]{2,63}$" options:0 error:nil];
    return [expression firstMatchInString:skinID options:0 range:NSMakeRange(0, skinID.length)] != nil;
}

static void ZXSkinCatalog(NSString *gameIdentifier, NSString *accessToken,
                          void (^completion)(NSArray<NSDictionary *> *skins, NSError *error)) {
    if (!FFGameDefinition(gameIdentifier) || !accessToken.length) {
        completion(nil, FFError(39, @"Feature authorization is required."));
        return;
    }
    NSString *game = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/skins/catalog?game=%@", game ?: @""];
    FFJSONRequest(@"GET", path, nil, accessToken, ^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSString *responseGame = [json[@"game"] isKindOfClass:NSString.class] ? json[@"game"] : nil;
        NSString *targetPath = [json[@"target_relative_path"] isKindOfClass:NSString.class]
            ? json[@"target_relative_path"] : nil;
        NSArray *rows = [json[@"skins"] isKindOfClass:NSArray.class] ? json[@"skins"] : nil;
        BOOL acceptedTargetPath = [targetPath isEqualToString:FFModSkinTargetRelativePath] ||
            [targetPath isEqualToString:FFModSkinTargetLegacyRelativePath];
        if (![responseGame isEqualToString:gameIdentifier] || !acceptedTargetPath || !rows) {
            completion(nil, FFError(38, @"MOD SKINS catalog response is invalid."));
            return;
        }
        NSMutableArray<NSDictionary *> *valid = [NSMutableArray array];
        NSMutableSet<NSString *> *seen = [NSMutableSet set];
        for (id candidate in rows) {
            if (![candidate isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *row = candidate;
            NSString *skinID = [row[@"id"] isKindOfClass:NSString.class] ? row[@"id"] : nil;
            NSString *name = [row[@"name"] isKindOfClass:NSString.class] ? row[@"name"] : nil;
            NSString *character = [row[@"character"] isKindOfClass:NSString.class] ? row[@"character"] : nil;
            NSString *target = [row[@"target_filename"] isKindOfClass:NSString.class] ? row[@"target_filename"] : nil;
            NSString *payloadHash = [row[@"payload_sha256"] isKindOfClass:NSString.class]
                ? [row[@"payload_sha256"] lowercaseString] : nil;
            NSString *previewHash = [row[@"preview_sha256"] isKindOfClass:NSString.class]
                ? [row[@"preview_sha256"] lowercaseString] : nil;
            NSInteger payloadSize = [row[@"payload_size"] integerValue];
            NSInteger previewSize = [row[@"preview_size"] integerValue];
            if (!FFSkinIDIsSafe(skinID) || [seen containsObject:skinID] || !name.length || name.length > 96 ||
                !character.length || character.length > 48 || !FFSkinFilenameIsSafe(target) ||
                !ZXIsSHA256(payloadHash) || !ZXIsSHA256(previewHash) ||
                payloadSize < 1000000 || payloadSize > 4000000 || previewSize <= 0 || previewSize > 2000000) continue;
            [seen addObject:skinID];
            [valid addObject:@{
                @"id": skinID, @"name": name, @"character": character, @"target_filename": target,
                @"payload_sha256": payloadHash, @"payload_size": @(payloadSize),
                @"preview_sha256": previewHash, @"preview_size": @(previewSize),
            }];
        }
        if (!valid.count) {
            completion(nil, FFError(38, @"No verified MOD SKINS are available."));
            return;
        }
        completion(valid, nil);
    });
}

static void ZXSkinPreview(NSDictionary *skin, NSString *gameIdentifier, NSString *accessToken,
                          void (^completion)(UIImage *image, NSError *error)) {
    NSString *skinID = skin[@"id"];
    NSString *expectedHash = skin[@"preview_sha256"];
    if (!FFSkinIDIsSafe(skinID) || !ZXIsSHA256(expectedHash)) {
        completion(nil, FFError(38, @"Skin preview metadata is invalid."));
        return;
    }
    NSString *escapedID = [skinID stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *escapedGame = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSMutableURLRequest *request = FFProtectedRawRequest(
        [NSString stringWithFormat:@"/skins/%@/preview?game=%@", escapedID ?: @"", escapedGame ?: @""],
        accessToken, nil);
    if (!request) {
        completion(nil, FFError(39, @"Secure skin preview request is unavailable."));
        return;
    }
    FFDownloadDataWithProgress(request, nil, ^(NSData *data, NSHTTPURLResponse *response, NSError *networkError) {
        if (networkError || response.statusCode < 200 || response.statusCode >= 300 ||
            data.length == 0 || data.length > 2000000 ||
            ![[ZXDigest(data) lowercaseString] isEqualToString:expectedHash.lowercaseString]) {
            completion(nil, FFError(40, @"Skin preview could not be verified."));
            return;
        }
        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            completion(nil, FFError(40, @"Skin preview image is invalid."));
            return;
        }
        completion(image, nil);
    });
}

static void ZXSkinDownload(NSDictionary *skin, NSString *gameIdentifier, NSString *accessToken,
                           NSString *featureToken, void (^progress)(int64_t received, int64_t expected),
                           void (^completion)(NSData *data, NSError *error)) {
    NSString *skinID = skin[@"id"];
    NSString *expectedHash = skin[@"payload_sha256"];
    NSString *targetName = skin[@"target_filename"];
    if (!FFSkinIDIsSafe(skinID) || !ZXIsSHA256(expectedHash) || !FFSkinFilenameIsSafe(targetName)) {
        completion(nil, FFError(38, @"Skin download metadata is invalid."));
        return;
    }
    NSString *escapedID = [skinID stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *escapedGame = [gameIdentifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSMutableURLRequest *request = FFProtectedRawRequest(
        [NSString stringWithFormat:@"/skins/%@/download?game=%@", escapedID ?: @"", escapedGame ?: @""],
        accessToken, featureToken);
    if (!request) {
        completion(nil, FFError(39, @"Secure skin download request is unavailable."));
        return;
    }
    FFDownloadDataWithProgress(request, progress, ^(NSData *data, NSHTTPURLResponse *response, NSError *networkError) {
        NSString *serverHash = [[response valueForHTTPHeaderField:@"X-Skin-SHA256"] lowercaseString];
        NSString *serverID = [response valueForHTTPHeaderField:@"X-Skin-ID"];
        NSString *serverTarget = [response valueForHTTPHeaderField:@"X-Skin-Target"];
        NSString *serverGame = [response valueForHTTPHeaderField:@"X-Game-Identifier"];
        NSString *actualHash = [ZXDigest(data) lowercaseString];
        if (networkError || response.statusCode < 200 || response.statusCode >= 300 ||
            data.length < 1000000 || data.length > 4000000 || !FFDataLooksLikeUnityBundle(data) ||
            !ZXIsSHA256(serverHash) || ![serverHash isEqualToString:actualHash] ||
            ![actualHash isEqualToString:expectedHash.lowercaseString] ||
            ![serverID isEqualToString:skinID] || ![serverTarget isEqualToString:targetName] ||
            ![serverGame isEqualToString:gameIdentifier]) {
            completion(nil, FFError(42, @"Skin download failed integrity validation."));
            return;
        }
        completion(data, nil);
    });
}

static BOOL FFIsKnownCacheFilename(NSString *name) {
    NSString *lower = name.lowercaseString;
    return [lower isEqualToString:@"cache_res"] ||
        [lower hasPrefix:@"cache_res."] ||
        [lower isEqualToString:@"content_cache_compulsory"] ||
        [lower hasPrefix:@"content_cache_compulsory."];
}

static NSURL *FFFindGameAssetBundles(NSURL *root, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSNumber *isDirectory = nil;
    [root getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    if (isDirectory.boolValue && [root.lastPathComponent caseInsensitiveCompare:@"gameassetbundles"] == NSOrderedSame) {
        return root;
    }

    NSArray<NSString *> *relativeCandidates = @[
        @"Documents/contentcache/Compulsory/ios/gameassetbundles",
        @"Documents/contentcache/Optional/ios/gameassetbundles",
        @"Documents/contentcache/Optional/ios/GameAssetBundles",
        @"contentcache/Compulsory/ios/gameassetbundles",
        @"contentcache/Optional/ios/gameassetbundles",
        @"contentcache/Optional/ios/GameAssetBundles",
        @"Compulsory/ios/gameassetbundles",
        @"Optional/ios/gameassetbundles",
        @"ios/gameassetbundles",
        @"gameassetbundles"
    ];
    for (NSString *relativePath in relativeCandidates) {
        NSURL *candidate = [root URLByAppendingPathComponent:relativePath isDirectory:YES];
        BOOL directory = NO;
        if ([fm fileExistsAtPath:candidate.path isDirectory:&directory] && directory) return candidate;
    }

    NSMutableOrderedSet<NSURL *> *cacheParents = [NSMutableOrderedSet orderedSet];
    NSDirectoryEnumerator<NSURL *> *enumerator = [fm enumeratorAtURL:root
                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsRegularFileKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants
                                                         errorHandler:^BOOL(NSURL *url, NSError *enumerationError) {
        (void)url; (void)enumerationError;
        return YES;
    }];
    NSUInteger visited = 0;
    for (NSURL *url in enumerator) {
        if (++visited > 250000) break;
        NSNumber *directory = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
        if (directory.boolValue) {
            if ([url.lastPathComponent caseInsensitiveCompare:@"gameassetbundles"] == NSOrderedSame) {
                return url;
            }
            continue;
        }
        NSNumber *regular = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (regular.boolValue && FFIsKnownCacheFilename(url.lastPathComponent)) {
            [cacheParents addObject:url.URLByDeletingLastPathComponent];
        }
    }
    if (cacheParents.count == 1) return cacheParents.firstObject;
    if (error) {
        *error = cacheParents.count > 1
            ? FFError(10, [NSString stringWithFormat:
                @"Found %lu possible cache locations in the game container; no unique target was selected.",
                (unsigned long)cacheParents.count])
            : FFError(10, @"No gameassetbundles or cache_res location was found in the game container.");
    }
    return nil;
}

static NSURL *FFTargetFile(NSURL *directory, NSString *gameIdentifier, BOOL allowBackupOnly, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    // The two games keep their own data containers, but current Free Fire
    // builds use different cache naming orders. Prefer the known TH bundle
    // name and the MAX base name, then retain the safe recursive discovery
    // for versioned filenames introduced by game updates.
    NSArray<NSString *> *names = [gameIdentifier isEqualToString:FFBundleIDFreeFireTH]
        ? @[@"cache_res.GkLlYqzsX4AtTdE55sDMRh9sJOI~3D", @"cache_res", @"content_cache_compulsory"]
        : @[@"cache_res", @"content_cache_compulsory", @"cache_res.GkLlYqzsX4AtTdE55sDMRh9sJOI~3D"];
    for (NSString *name in names) {
        NSURL *candidate = [directory URLByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:candidate.path]) return candidate;
    }
    if (allowBackupOnly) {
        for (NSString *name in names) {
            NSURL *candidate = [directory URLByAppendingPathComponent:name];
            NSURL *backup = [NSURL fileURLWithPath:[candidate.path stringByAppendingString:FFBackupSuffix]];
            if ([fm fileExistsAtPath:backup.path]) return candidate;
        }
    }

    NSData *cabMarker = [@"CAB-f35e59c15686beb35c2683bdcd5b9393" dataUsingEncoding:NSASCIIStringEncoding];
    NSString *knownCacheName = @"cache_res.GkLlYqzsX4AtTdE55sDMRh9sJOI~3D";
    NSMutableArray<NSURL *> *knownNameMatches = [NSMutableArray array];
    NSMutableArray<NSURL *> *cacheNameMatches = [NSMutableArray array];
    NSMutableArray<NSURL *> *backupMatches = [NSMutableArray array];
    NSMutableArray<NSURL *> *markerMatches = [NSMutableArray array];
    NSMutableArray<NSURL *> *unityCandidates = [NSMutableArray array];
    NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];
    NSArray<NSURLResourceKey> *keys = @[NSURLIsRegularFileKey, NSURLFileSizeKey];
    NSDirectoryEnumerator<NSURL *> *enumerator = [fm enumeratorAtURL:directory
                                           includingPropertiesForKeys:keys
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants
                                                         errorHandler:^BOOL(NSURL *url, NSError *enumerationError) {
        (void)url; (void)enumerationError;
        return YES;
    }];
    NSUInteger visited = 0;
    for (NSURL *url in enumerator) {
        if (++visited > 50000) break;
        NSNumber *regular = nil;
        NSNumber *size = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        if (!regular.boolValue || size.unsignedLongLongValue < 40000 || size.unsignedLongLongValue > 150000) continue;

        BOOL isBackup = [url.path hasSuffix:FFBackupSuffix];
        NSURL *liveURL = isBackup ? [NSURL fileURLWithPath:[url.path substringToIndex:url.path.length - FFBackupSuffix.length]] : url;
        if (isBackup && !allowBackupOnly && ![fm fileExistsAtPath:liveURL.path]) continue;
        NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
        if (!FFDataLooksLikeUnityBundle(data)) continue;
        if (![seenPaths containsObject:liveURL.path]) {
            [seenPaths addObject:liveURL.path];
            [unityCandidates addObject:liveURL];
        }
        NSString *liveName = liveURL.lastPathComponent;
        NSString *lowerName = liveName.lowercaseString;
        if ([liveName caseInsensitiveCompare:knownCacheName] == NSOrderedSame && ![knownNameMatches containsObject:liveURL]) {
            [knownNameMatches addObject:liveURL];
        }
        BOOL cacheNameMatch = [lowerName isEqualToString:@"cache_res"] ||
            [lowerName hasPrefix:@"cache_res."] ||
            [lowerName isEqualToString:@"content_cache_compulsory"] ||
            [lowerName hasPrefix:@"content_cache_compulsory."];
        if (cacheNameMatch && ![cacheNameMatches containsObject:liveURL]) [cacheNameMatches addObject:liveURL];
        if (isBackup && ![backupMatches containsObject:liveURL]) [backupMatches addObject:liveURL];
        BOOL markerMatch = [data rangeOfData:cabMarker options:0 range:NSMakeRange(0, data.length)].location != NSNotFound;
        if (markerMatch && ![markerMatches containsObject:liveURL]) [markerMatches addObject:liveURL];
    }

    if (backupMatches.count == 1) return backupMatches.firstObject;
    if (knownNameMatches.count == 1) return knownNameMatches.firstObject;
    if (cacheNameMatches.count == 1) return cacheNameMatches.firstObject;
    if (markerMatches.count == 1) return markerMatches.firstObject;
    if (knownNameMatches.count > 1 || cacheNameMatches.count > 1) {
        NSUInteger count = knownNameMatches.count > 1 ? knownNameMatches.count : cacheNameMatches.count;
        if (error) *error = FFError(11, [NSString stringWithFormat:@"Found %lu files named cache_res. Update Free Fire once, then retry.", (unsigned long)count]);
        return nil;
    }
    if (unityCandidates.count == 1) return unityCandidates.firstObject;
    if (error) {
        NSString *message = unityCandidates.count == 0
            ? @"No UnityFS cache bundle found under gameassetbundles. Open FREE FIRE once, let it download its content data, then retry."
            : [NSString stringWithFormat:@"Found %lu UnityFS bundles, but the expected cache_res file name was not present.", (unsigned long)unityCandidates.count];
        *error = FFError(11, message);
    }
    return nil;
}

typedef NS_ENUM(NSInteger, FFAccessMethod) {
    FFAccessMethodNone = 0,
    FFAccessMethodDirect,
    FFAccessMethodAuthorizedFolder,
};

static NSString *FFAccessMethodName(FFAccessMethod method) {
    switch (method) {
        case FFAccessMethodDirect:
#ifdef FF_OFFLINE_BUILD
            return @"3105 MCM DirectAccess";
#else
            return @"DirectAccess";
#endif
        case FFAccessMethodAuthorizedFolder: return @"AuthorizedFolderAccess";
        default: return @"NONE";
    }
}

@interface FFAccessContext : NSObject
@property(nonatomic) FFAccessMethod method;
@property(nonatomic, copy) NSString *gameIdentifier;
@property(nonatomic, strong) NSURL *rootURL;
@property(nonatomic, strong) NSURL *assetBundlesURL;
@property(nonatomic, strong) NSURL *targetURL;
@property(nonatomic, copy) NSString *activeFeature;
@property(nonatomic, strong) NSError *error;
@property(nonatomic, copy) NSString *fallbackReason;
@property(nonatomic) BOOL discovered;
@property(nonatomic) BOOL opened;
@property(nonatomic) BOOL readVerified;
@property(nonatomic) BOOL writeVerified;
@property(nonatomic) BOOL usable;
@property(nonatomic) BOOL needsFolderSelection;
@end

@implementation FFAccessContext
@end

static NSString *FFActiveFeatureAtTarget(NSURL *target, NSString *gameIdentifier) {
    NSData *current = [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil];
    if (!current) return @"UNKNOWN";
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSData *original = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
    if (original && [current isEqualToData:original]) return @"ORIGINAL";
    NSString *key = FFActiveProfileDefaultsKey(gameIdentifier);
    NSString *saved = key ? [NSUserDefaults.standardUserDefaults stringForKey:key] : nil;
    return saved.length ? saved : @"CUSTOM / ORIGINAL";
}

@interface FFGameDetector : NSObject
+ (FFAccessContext *)detectDirectContainerForGame:(NSString *)gameIdentifier;
@end

@implementation FFGameDetector
+ (FFAccessContext *)detectDirectContainerForGame:(NSString *)gameIdentifier {
    FFAccessContext *context = [FFAccessContext new];
    context.method = FFAccessMethodDirect;
    context.gameIdentifier = gameIdentifier;
    FFDiagnosticLog(@"GameDetector", @"Bundle: %@", gameIdentifier ?: @"NONE");

    NSError *error = nil;
    NSString *detectedIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(gameIdentifier, &detectedIdentifier, nil,
        &assetBundles, &error);
    context.rootURL = container;
    context.assetBundlesURL = assetBundles;
    context.discovered = container != nil && [detectedIdentifier isEqualToString:gameIdentifier];
    context.error = error;
    FFDiagnosticLog(@"DirectAccess", @"Discovery: %@%@", context.discovered ? @"SUCCESS" : @"FAILED",
        container.path.length ? [NSString stringWithFormat:@" (%@)", container.path] : @"");
    if (error) FFDiagnosticLog(@"DirectAccess", @"Discovery detail: %@", error.localizedDescription);
    return context;
}
@end

@interface FFAccessVerifier : NSObject
+ (FFAccessContext *)verifyContext:(FFAccessContext *)context
                     requiresWrite:(BOOL)requiresWrite
                   allowBackupOnly:(BOOL)allowBackupOnly;
@end

@implementation FFAccessVerifier
+ (FFAccessContext *)verifyContext:(FFAccessContext *)context
                     requiresWrite:(BOOL)requiresWrite
                   allowBackupOnly:(BOOL)allowBackupOnly {
    NSString *component = FFAccessMethodName(context.method);
    NSFileManager *manager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (!context.discovered || !context.rootURL ||
        ![manager fileExistsAtPath:context.rootURL.path isDirectory:&isDirectory] || !isDirectory) {
        context.error = context.error ?: FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Game detector did not produce an existing directory.");
        FFDiagnosticLog(component, @"Open: FAILED (%@)", context.error.localizedDescription);
        return context;
    }

    errno = 0;
    int rootDescriptor = open(context.rootURL.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (rootDescriptor < 0) {
        NSError *posix = FFPOSIXAccessError(61, @"Container root open", context.rootURL, errno);
        context.error = FFNamedError(61, @"CONTAINER_FOUND_ACCESS_DENIED", posix.localizedDescription);
        FFDiagnosticLog(component, @"Open: FAILED (%@)", context.error.localizedDescription);
        return context;
    }
    close(rootDescriptor);
    context.opened = YES;
    FFDiagnosticLog(component, @"Open: SUCCESS");

    NSError *lookupError = nil;
    NSURL *assetBundles = context.assetBundlesURL ?: FFFindGameAssetBundles(context.rootURL, &lookupError);
    NSURL *target = assetBundles
        ? FFTargetFile(assetBundles, context.gameIdentifier, allowBackupOnly, &lookupError) : nil;
    if (!assetBundles || !target) {
        context.error = FFNamedError(62, @"ASSET_NOT_FOUND",
            lookupError.localizedDescription ?: @"Required game files were not found.");
        FFDiagnosticLog(@"AccessVerifier", @"Read: FAILED (%@)", context.error.localizedDescription);
        return context;
    }
    context.assetBundlesURL = assetBundles;
    context.targetURL = target;

    NSURL *readURL = target;
    if (allowBackupOnly && ![manager fileExistsAtPath:target.path]) {
        readURL = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    }
    errno = 0;
    int targetDescriptor = open(readURL.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
    if (targetDescriptor < 0) {
        NSError *posix = FFPOSIXAccessError(63, @"Required game file read", readURL, errno);
        context.error = FFNamedError(63, @"READ_FAILED", posix.localizedDescription);
        FFDiagnosticLog(@"AccessVerifier", @"Read: FAILED (%@)", context.error.localizedDescription);
        return context;
    }
    unsigned char header[8] = {0};
    ssize_t bytesRead = read(targetDescriptor, header, sizeof(header));
    int readErrno = errno;
    close(targetDescriptor);
    const unsigned char unityHeader[] = {'U','n','i','t','y','F','S',0};
    if (bytesRead != (ssize_t)sizeof(header) || memcmp(header, unityHeader, sizeof(unityHeader)) != 0) {
        NSError *readFailure = bytesRead < 0
            ? FFPOSIXAccessError(63, @"Required game file read", readURL, readErrno)
            : FFError(63, @"Required game file is readable but does not have the expected UnityFS header.");
        context.error = FFNamedError(63, @"READ_FAILED", readFailure.localizedDescription);
        FFDiagnosticLog(@"AccessVerifier", @"Read: FAILED (%@)", context.error.localizedDescription);
        return context;
    }
    context.readVerified = YES;
    FFDiagnosticLog(@"AccessVerifier", @"Read: SUCCESS");

    if (requiresWrite) {
        if ([manager fileExistsAtPath:target.path]) {
            errno = 0;
            int writableTarget = open(target.fileSystemRepresentation, O_WRONLY | O_CLOEXEC);
            if (writableTarget < 0) {
                NSError *posix = FFPOSIXAccessError(64, @"Required destination write open", target, errno);
                context.error = FFNamedError(64, @"WRITE_FAILED", posix.localizedDescription);
                FFDiagnosticLog(@"AccessVerifier", @"Write: FAILED (%@)", context.error.localizedDescription);
                return context;
            }
            close(writableTarget);
        }
        NSURL *destination = target.URLByDeletingLastPathComponent;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *probeError = nil;
        __block BOOL probeSucceeded = NO;
        NSError *coordinationError = nil;
        [coordinator coordinateWritingItemAtURL:destination
                                        options:NSFileCoordinatorWritingForMerging
                                          error:&coordinationError
                                     byAccessor:^(NSURL *coordinatedDestination) {
            NSString *probeName = [NSString stringWithFormat:@".ffaccess-%@.tmp", NSUUID.UUID.UUIDString];
            NSURL *probeURL = [coordinatedDestination URLByAppendingPathComponent:probeName];
            errno = 0;
            int descriptor = open(probeURL.fileSystemRepresentation,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
            if (descriptor < 0) {
                probeError = FFPOSIXAccessError(64, @"Destination write probe open", probeURL, errno);
                return;
            }
            const unsigned char probe[] = {'F','F','A','C','C','E','S','S'};
            ssize_t written = write(descriptor, probe, sizeof(probe));
            int savedErrno = errno;
            close(descriptor);
            if (written != (ssize_t)sizeof(probe)) {
                unlink(probeURL.fileSystemRepresentation);
                probeError = FFPOSIXAccessError(64, @"Destination write probe", probeURL,
                    written < 0 ? savedErrno : EIO);
                return;
            }
            if (unlink(probeURL.fileSystemRepresentation) != 0) {
                probeError = FFPOSIXAccessError(64, @"Destination write probe cleanup", probeURL, errno);
                return;
            }
            probeSucceeded = YES;
        }];
        if (!probeError && coordinationError) probeError = coordinationError;
        if (!probeSucceeded || probeError) {
            context.error = FFNamedError(64, @"WRITE_FAILED",
                probeError.localizedDescription ?: @"Destination write verification failed.");
            FFDiagnosticLog(@"AccessVerifier", @"Write: FAILED (%@)", context.error.localizedDescription);
            return context;
        }
        context.writeVerified = YES;
        FFDiagnosticLog(@"AccessVerifier", @"Write: SUCCESS");
    } else {
        context.writeVerified = YES;
        FFDiagnosticLog(@"AccessVerifier", @"Write: SKIPPED (read-only operation)");
    }

    context.error = nil;
    context.usable = context.opened && context.readVerified && context.writeVerified;
    if (context.usable) {
        context.activeFeature = FFActiveFeatureAtTarget(context.targetURL, context.gameIdentifier);
    }
    return context;
}
@end

@interface FFAccessManager : NSObject
+ (BOOL)storeBookmarkForAuthorizedURL:(NSURL *)url error:(NSError **)error;
+ (NSURL *)beginBookmarkedFolderAccessWithStale:(BOOL *)stale error:(NSError **)error;
+ (void)endBookmarkedFolderAccess:(NSURL *)url;
+ (void)invalidateStoredBookmark:(NSString *)reason;
@end

@implementation FFAccessManager
+ (BOOL)storeBookmarkForAuthorizedURL:(NSURL *)url error:(NSError **)error {
    NSData *bookmark = [url bookmarkDataWithOptions:0
                         includingResourceValuesForKeys:nil relativeToURL:nil error:error];
    if (!bookmark) {
        NSString *detail = (error && *error) ? (*error).localizedDescription : @"creation failed";
        FFDiagnosticLog(@"Bookmark", @"Stored: NO (%@)", detail);
        return NO;
    }
    [NSUserDefaults.standardUserDefaults setObject:bookmark forKey:FFBookmarkKey];
    FFDiagnosticLog(@"Bookmark", @"Stored: YES");
    return YES;
}

+ (NSURL *)beginBookmarkedFolderAccessWithStale:(BOOL *)stale error:(NSError **)error {
    NSData *bookmark = [NSUserDefaults.standardUserDefaults dataForKey:FFBookmarkKey];
    if (!bookmark) {
        if (error) *error = FFError(65, @"No authorized game folder is stored.");
        FFDiagnosticLog(@"Bookmark", @"Restored: NO (missing)");
        return nil;
    }
    BOOL bookmarkStale = NO;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark options:0 relativeToURL:nil
                            bookmarkDataIsStale:&bookmarkStale error:error];
    FFDiagnosticLog(@"Bookmark", @"Restored: %@", url ? @"YES" : @"NO");
    FFDiagnosticLog(@"Bookmark", @"Stale: %@", bookmarkStale ? @"YES" : @"NO");
    if (!url) return nil;

    BOOL accessed = [url startAccessingSecurityScopedResource];
    FFDiagnosticLog(@"AuthorizedFolderAccess", @"Security-scoped resource: %@", accessed ? @"STARTED" : @"FAILED");
    if (!accessed) {
        if (error) *error = FFError(66, @"Folder authorization expired. Select the game folder again.");
        return nil;
    }
    if (bookmarkStale) {
        NSError *renewError = nil;
        if (![self storeBookmarkForAuthorizedURL:url error:&renewError]) {
            [url stopAccessingSecurityScopedResource];
            if (error) *error = renewError ?: FFError(66, @"The stale folder bookmark could not be renewed.");
            return nil;
        }
        FFDiagnosticLog(@"Bookmark", @"Renewed: YES");
    }
    if (stale) *stale = bookmarkStale;
    return url;
}

+ (void)endBookmarkedFolderAccess:(NSURL *)url {
    if (!url) return;
    [url stopAccessingSecurityScopedResource];
    FFDiagnosticLog(@"AuthorizedFolderAccess", @"Security-scoped resource: STOPPED");
}

+ (void)invalidateStoredBookmark:(NSString *)reason {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:FFBookmarkKey];
    FFDiagnosticLog(@"Bookmark", @"Invalidated: %@", reason.length ? reason : @"authorization unavailable");
}
@end

@interface FFCompatibilityRouter : NSObject
+ (FFAccessContext *)routeGame:(NSString *)gameIdentifier requiresWrite:(BOOL)requiresWrite;
+ (FFAccessContext *)verifyAuthorizedURL:(NSURL *)url
                                 forGame:(NSString *)gameIdentifier
                           requiresWrite:(BOOL)requiresWrite;
@end


@implementation FFCompatibilityRouter
+ (FFAccessContext *)verifyAuthorizedURL:(NSURL *)url
                                 forGame:(NSString *)gameIdentifier
                           requiresWrite:(BOOL)requiresWrite {
    FFAccessContext *context = [FFAccessContext new];
    context.method = FFAccessMethodAuthorizedFolder;
    context.gameIdentifier = gameIdentifier;
    context.rootURL = url;
    context.discovered = url != nil;
    return [FFAccessVerifier verifyContext:context requiresWrite:requiresWrite allowBackupOnly:NO];
}

+ (FFAccessContext *)routeGame:(NSString *)gameIdentifier requiresWrite:(BOOL)requiresWrite {
#ifdef FF_3105_MCM
    // The OGIOS kernel chain must be active before MCM sandbox tokens can be
    // used on iOS 17/18.5. viewDidLoad warms it up; this wait covers the user
    // tapping a game before the background exploit finished.
    // Wait ONCE per process run: repeating checks must never pay this cost
    // again while the exploit keeps grinding in the background. Skipped
    // entirely when the app already has full filesystem access (jailbroken
    // unsandboxed installs).
    BOOL fullFilesystemAccess = FFHasFullFilesystemAccess();
    static BOOL kernelWaitConsumed = NO;
    if (!fullFilesystemAccess && !kernelWaitConsumed &&
        FFKernelExploitSupported() &&
        !FFKernelExploitIsReady() && !FFKernelExploitHasFailed()) {
        kernelWaitConsumed = YES;
        FFKernelExploitWaitReady(20.0);
    }
#endif
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    FFDiagnosticLog(@"Compatibility", @"iOS: %ld.%ld.%ld", (long)version.majorVersion,
        (long)version.minorVersion, (long)version.patchVersion);
    FFDiagnosticLog(@"GameDetector", @"Bundle: %@", gameIdentifier ?: @"NONE");

    FFAccessContext *direct = [FFGameDetector detectDirectContainerForGame:gameIdentifier];
    if (direct.discovered) {
        [FFAccessVerifier verifyContext:direct requiresWrite:requiresWrite allowBackupOnly:NO];
        if (direct.usable) {
            FFDiagnosticLog(@"Compatibility", @"Selected access method: DirectAccess");
            FFDiagnosticLog(@"Compatibility", @"Final access state: READY");
            return direct;
        }
    }

#ifdef FF_3105_MCM
    // Retry once after a bounded wait for the still-warming kernel chain: on
    // iOS 26/27 the sandbox escape is what turns a readable container into a
    // writable one, and it can take minutes on those systems.
    static BOOL kernelRetryConsumed = NO;
    if (!fullFilesystemAccess && !kernelRetryConsumed && FFKernelExploitSupported() &&
        !FFKernelExploitIsReady() && !FFKernelExploitHasFailed()) {
        kernelRetryConsumed = YES;
        FFKernelExploitWaitReady(30.0);
        direct = [FFGameDetector detectDirectContainerForGame:gameIdentifier];
        if (direct.discovered) {
            [FFAccessVerifier verifyContext:direct requiresWrite:requiresWrite allowBackupOnly:NO];
            if (direct.usable) {
                FFDiagnosticLog(@"Compatibility", @"Selected access method: DirectAccess (after kernel wait)");
                FFDiagnosticLog(@"Compatibility", @"Final access state: READY");
                return direct;
            }
        }
    }
#endif

    // On iOS 18.5+ and iOS 26+, Files does not expose another application's
    // private data container. A document picker cannot grant a URL the user
    // cannot select, so report the verified access state instead of presenting
    // a folder workflow that cannot authorize the target.
    if ((version.majorVersion == 18 && version.minorVersion >= 5) || version.majorVersion >= 26) {
        direct.needsFolderSelection = NO;
        NSString *state = direct.discovered ? @"CONTAINER_FOUND_ACCESS_DENIED"
                                            : @"AUTHORIZED_CONTAINER_ACCESS_UNAVAILABLE";
        direct.error = FFNamedError(67, state,
            @"This iOS version did not grant the app legitimate read/write access to the game's private container. The folder is not exposed in Files, so manual folder selection is unavailable. Wait for kernel access to be established and retry.");
#ifdef FF_3105_MCM
        if (FFWorseQuerySupported()) {
            direct.error = FFNamedError(67, state, FFWorseQueryFailureReason());
        }
#endif
        return direct;
    }

#ifdef FF_OFFLINE_BUILD
    direct.needsFolderSelection = NO;
    direct.error = direct.error ?: FFError(67,
        @"3105 MCM direct access is unavailable on this device/signing method. Offline mode does not use a folder picker.");
    FFDiagnosticLog(@"Compatibility", @"Offline direct-only mode: no AuthorizedFolderAccess fallback");
    FFDiagnosticLog(@"Compatibility", @"Final access state: DIRECT ACCESS UNAVAILABLE");
    return direct;
#endif

    NSString *fallbackReason = direct.error.localizedDescription ?: @"Direct access did not pass filesystem verification.";
    FFDiagnosticLog(@"Compatibility", @"Falling back to AuthorizedFolderAccess");
    FFDiagnosticLog(@"Compatibility", @"Fallback reason: %@", fallbackReason);

    NSError *bookmarkError = nil;
    BOOL stale = NO;
    NSURL *authorizedRoot = [FFAccessManager beginBookmarkedFolderAccessWithStale:&stale error:&bookmarkError];
    if (!authorizedRoot) {
        FFAccessContext *failed = [FFAccessContext new];
        failed.method = FFAccessMethodNone;
        failed.gameIdentifier = gameIdentifier;
        failed.fallbackReason = fallbackReason;
        failed.error = bookmarkError ?: FFError(65, @"Select an authorized game folder to continue.");
        failed.needsFolderSelection = YES;
        if (bookmarkError.code == 66) [FFAccessManager invalidateStoredBookmark:bookmarkError.localizedDescription];
        FFDiagnosticLog(@"Compatibility", @"Final access state: AUTHORIZATION REQUIRED");
        return failed;
    }

    FFAccessContext *authorized = [self verifyAuthorizedURL:authorizedRoot
                                                   forGame:gameIdentifier
                                             requiresWrite:requiresWrite];
    authorized.fallbackReason = fallbackReason;
    [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    if (authorized.usable) {
        FFDiagnosticLog(@"Compatibility", @"Selected access method: AuthorizedFolderAccess");
        FFDiagnosticLog(@"Compatibility", @"Final access state: READY");
        return authorized;
    }
    [FFAccessManager invalidateStoredBookmark:authorized.error.localizedDescription];
    authorized.needsFolderSelection = YES;
    FFDiagnosticLog(@"Compatibility", @"Final access state: AUTHORIZATION REQUIRED");
    return authorized;
}
@end

static BOOL FFCreateBackupIfNeeded(NSURL *target, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    if ([fm fileExistsAtPath:backup.path]) {
        NSData *saved = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
        if (saved.length && FFDataLooksLikeUnityBundle(saved)) {
            FFDiagnosticLog(@"ApplyManager", @"Backup Original: VERIFIED (existing, never overwritten)");
            return YES;
        }
        if (error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Existing original backup is invalid; apply aborted safely.");
        return NO;
    }
    NSDictionary *attributes = [fm attributesOfItemAtPath:target.path error:error];
    if (!attributes || [attributes fileSize] == 0) {
        if (error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Original file is missing or empty.");
        return NO;
    }
    NSData *original = [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:error];
    if (!original.length || !FFDataLooksLikeUnityBundle(original) ||
        ![fm copyItemAtURL:target toURL:backup error:error]) {
        if (error && !*error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Could not create the original backup.");
        return NO;
    }
    NSData *saved = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
    if (!saved.length || ![[ZXDigest(original) lowercaseString] isEqualToString:[ZXDigest(saved) lowercaseString]]) {
        [fm removeItemAtURL:backup error:nil];
        if (error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Backup verification failed.");
        return NO;
    }
    FFDiagnosticLog(@"ApplyManager", @"Backup Original: SUCCESS + SHA256 VERIFIED");
    return YES;
}

static BOOL FFReplaceTargetWithData(NSURL *target, NSData *data, NSError **error) {
    if (!FFDataLooksLikeUnityBundle(data)) {
        if (error) *error = FFError(14, @"The selected feature is not a valid UnityFS cache bundle.");
        return NO;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *directory = [target URLByDeletingLastPathComponent];
    NSString *temporaryName = [NSString stringWithFormat:@".%@.%@.tmp", target.lastPathComponent, NSUUID.UUID.UUIDString];
    NSURL *temporary = [directory URLByAppendingPathComponent:temporaryName];
    if (![data writeToURL:temporary options:NSDataWritingAtomic error:error]) return NO;

    BOOL succeeded = NO;
    if ([fm fileExistsAtPath:target.path]) {
        NSURL *result = nil;
        succeeded = [fm replaceItemAtURL:target
                            withItemAtURL:temporary
                           backupItemName:nil
                                  options:0
                         resultingItemURL:&result
                                    error:error];
    } else {
        succeeded = [fm moveItemAtURL:temporary toURL:target error:error];
    }
    if (!succeeded && [fm fileExistsAtPath:temporary.path]) [fm removeItemAtURL:temporary error:nil];
    NSData *installed = succeeded ? [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil] : nil;
    if (!succeeded || ![[ZXDigest(installed) lowercaseString] isEqualToString:[ZXDigest(data) lowercaseString]]) {
        if (error && !*error) *error = FFNamedError(51, @"APPLY_FAILED", @"Post-write SHA-256 verification failed.");
        return NO;
    }
    FFDiagnosticLog(@"ApplyManager", @"APPLY_SUCCESS: target SHA256 verified");
    return YES;
}

static BOOL FFInstallFeatureData(NSData *data, NSURL *target, NSError **error) {
    if (!FFCreateBackupIfNeeded(target, error)) return NO;
    if (FFReplaceTargetWithData(target, data, error)) return YES;
    NSError *initial = error ? *error : nil;
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSData *original = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
    if (original.length) FFReplaceTargetWithData(target, original, nil);
    if (error) *error = initial ?: FFNamedError(51, @"APPLY_FAILED", @"Installation failed and original recovery was attempted.");
    return NO;
}

static BOOL FFReplaceRawData(NSURL *target, NSData *data, NSError **error) {
    if (!data.length) {
        if (error) *error = FFError(45, @"Protected resource is empty.");
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *directory = target.URLByDeletingLastPathComponent;
    NSURL *temporary = [directory URLByAppendingPathComponent:
        [NSString stringWithFormat:@".%@.%@.tmp", target.lastPathComponent, NSUUID.UUID.UUIDString]];
    if (![data writeToURL:temporary options:NSDataWritingAtomic error:error]) return NO;
    NSURL *result = nil;
    BOOL succeeded = [fm replaceItemAtURL:target withItemAtURL:temporary backupItemName:nil
                                  options:0 resultingItemURL:&result error:error];
    if (!succeeded && [fm fileExistsAtPath:temporary.path]) [fm removeItemAtURL:temporary error:nil];
    NSData *installed = succeeded ? [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil] : nil;
    if (!succeeded || ![[ZXDigest(installed) lowercaseString] isEqualToString:[ZXDigest(data) lowercaseString]]) {
        if (error && !*error) *error = FFNamedError(51, @"APPLY_FAILED", @"Post-write SHA-256 verification failed.");
        return NO;
    }
    FFDiagnosticLog(@"ApplyManager", @"APPLY_SUCCESS: protected target SHA256 verified");
    return YES;
}

static BOOL FFInstallRawData(NSURL *target, NSData *data, NSError **error) {
    if (!FFCreateBackupIfNeeded(target, error)) return NO;
    if (FFReplaceRawData(target, data, error)) return YES;
    NSError *initial = error ? *error : nil;
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSData *original = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
    if (original.length) FFReplaceRawData(target, original, nil);
    if (error) *error = initial ?: FFNamedError(51, @"APPLY_FAILED", @"Installation failed and original recovery was attempted.");
    return NO;
}



static NSString *FFESPAbsentBackupPath(NSURL *target) {
    return [target.path stringByAppendingString:@".ffbackup.absent"];
}

static BOOL FFESPCreateBackupIfNeeded(NSURL *target, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSString *absentPath = FFESPAbsentBackupPath(target);

    if ([fm fileExistsAtPath:backup.path] || [fm fileExistsAtPath:absentPath]) {
        return YES;
    }

    if (![fm fileExistsAtPath:target.path]) {
        NSData *marker = [@"ABSENT" dataUsingEncoding:NSASCIIStringEncoding];
        if (![marker writeToFile:absentPath options:NSDataWritingAtomic error:error]) {
            if (error && !*error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Could not record the missing ESP destination.");
            return NO;
        }
        return YES;
    }

    NSData *original = [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:error];
    if (!original || ![fm copyItemAtURL:target toURL:backup error:error]) {
        if (error && !*error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"Could not create the ESP original backup.");
        return NO;
    }
    NSData *saved = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:nil];
    if (!saved || ![[ZXDigest(original) lowercaseString] isEqualToString:[ZXDigest(saved) lowercaseString]]) {
        [fm removeItemAtURL:backup error:nil];
        if (error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", @"ESP backup verification failed.");
        return NO;
    }
    return YES;
}

static BOOL FFESPReplaceData(NSURL *target, NSData *data, NSError **error) {
    if (!data) {
        if (error) *error = FFNamedError(51, @"APPLY_FAILED", @"ESP resource is missing.");
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *directory = target.URLByDeletingLastPathComponent;
    NSURL *temporary = [directory URLByAppendingPathComponent:
        [NSString stringWithFormat:@".%@.%@.tmp", target.lastPathComponent, NSUUID.UUID.UUIDString]];

    if (![data writeToURL:temporary options:NSDataWritingAtomic error:error]) return NO;

    BOOL succeeded = NO;
    if ([fm fileExistsAtPath:target.path]) {
        NSURL *result = nil;
        succeeded = [fm replaceItemAtURL:target withItemAtURL:temporary
            backupItemName:nil options:0 resultingItemURL:&result error:error];
    } else {
        succeeded = [fm moveItemAtURL:temporary toURL:target error:error];
    }
    if (!succeeded && [fm fileExistsAtPath:temporary.path]) {
        [fm removeItemAtURL:temporary error:nil];
    }

    NSData *installed = succeeded
        ? [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil] : nil;
    if (!succeeded || !installed ||
        ![[ZXDigest(installed) lowercaseString] isEqualToString:[ZXDigest(data) lowercaseString]]) {
        if (error && !*error) *error = FFNamedError(51, @"APPLY_FAILED", @"ESP post-write SHA-256 verification failed.");
        return NO;
    }
    return YES;
}

static BOOL FFESPRestoreFile(NSURL *target, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *absentPath = FFESPAbsentBackupPath(target);
    if ([fm fileExistsAtPath:absentPath]) {
        if ([fm fileExistsAtPath:target.path] && ![fm removeItemAtURL:target error:error]) {
            return NO;
        }
        [fm removeItemAtPath:absentPath error:nil];
        return YES;
    }

    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSData *original = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:error];
    if (!original) {
        if (error && !*error) *error = FFNamedError(15, @"RESTORE_FAILED", @"ESP original backup was not found.");
        return NO;
    }
    return FFESPReplaceData(target, original, error);
}

static BOOL FFESPInstallFile(NSURL *target, NSData *data, NSError **error) {
    if (!FFESPCreateBackupIfNeeded(target, error)) return NO;
    if (FFESPReplaceData(target, data, error)) return YES;
    NSError *initial = error ? *error : nil;
    FFESPRestoreFile(target, nil);
    if (error) *error = initial ?: FFNamedError(51, @"APPLY_FAILED", @"ESP file installation failed and recovery was attempted.");
    return NO;
}

static NSArray<NSString *> *FFESPExpectedRelativePaths(void) {
    static NSArray<NSString *> *paths;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        paths = @[
            @"Documents/Assembly-CSharp-patch.bytes",
            @"Documents/localConfig.json",
        ];
    });
    return paths;
}

static BOOL FFParseESPPackage(NSData *packageData, NSString *gameIdentifier,
                              NSDictionary<NSString *, NSData *> **filesOut, NSError **error) {
    if (![gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        if (error) *error = FFNamedError(39, @"FEATURE_UNAVAILABLE", @"ESP package is available for FREE FIRE TH only.");
        return NO;
    }
    if (packageData.length < 64 || packageData.length > 10000000) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package size is invalid.");
        return NO;
    }

    const uint8_t *bytes = packageData.bytes;
    static const uint8_t magic[8] = {'F','F','E','S','P','0','0','1'};
    if (memcmp(bytes, magic, sizeof(magic)) != 0) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package header is invalid.");
        return NO;
    }

    uint32_t manifestLength = ((uint32_t)bytes[8] << 24) | ((uint32_t)bytes[9] << 16) |
                              ((uint32_t)bytes[10] << 8) | (uint32_t)bytes[11];
    if (manifestLength == 0 || manifestLength > 65536 ||
        (NSUInteger)12 + (NSUInteger)manifestLength >= packageData.length) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package manifest length is invalid.");
        return NO;
    }

    NSData *manifestData = [packageData subdataWithRange:NSMakeRange(12, manifestLength)];
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
    if (![manifest isKindOfClass:NSDictionary.class] ||
        [manifest[@"version"] integerValue] != 2 ||
        ![manifest[@"feature"] isEqualToString:@"ESP"] ||
        ![manifest[@"game"] isEqualToString:gameIdentifier]) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package manifest is invalid.");
        return NO;
    }

    NSArray *rows = [manifest[@"files"] isKindOfClass:NSArray.class] ? manifest[@"files"] : nil;
    NSArray<NSString *> *expectedPaths = FFESPExpectedRelativePaths();
    if (rows.count != expectedPaths.count) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package must contain exactly two approved files.");
        return NO;
    }

    NSUInteger payloadStart = 12 + manifestLength;
    NSUInteger payloadLength = packageData.length - payloadStart;
    NSMutableDictionary<NSString *, NSData *> *files = [NSMutableDictionary dictionaryWithCapacity:rows.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (id candidate in rows) {
        if (![candidate isKindOfClass:NSDictionary.class]) {
            if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package contains malformed file metadata.");
            return NO;
        }
        NSDictionary *row = candidate;
        NSString *relativePath = [row[@"path"] isKindOfClass:NSString.class] ? row[@"path"] : nil;
        NSNumber *offsetNumber = [row[@"offset"] isKindOfClass:NSNumber.class] ? row[@"offset"] : nil;
        NSNumber *lengthNumber = [row[@"length"] isKindOfClass:NSNumber.class] ? row[@"length"] : nil;
        NSString *expectedHash = [row[@"sha256"] isKindOfClass:NSString.class]
            ? [row[@"sha256"] lowercaseString] : nil;

        if (!relativePath.length || ![expectedPaths containsObject:relativePath] ||
            [seen containsObject:relativePath] || !offsetNumber || !lengthNumber || !ZXIsSHA256(expectedHash)) {
            if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package file metadata failed validation.");
            return NO;
        }

        unsigned long long offset64 = offsetNumber.unsignedLongLongValue;
        unsigned long long length64 = lengthNumber.unsignedLongLongValue;
        if (length64 == 0 || offset64 > payloadLength || length64 > payloadLength ||
            offset64 + length64 > payloadLength || offset64 + length64 < offset64) {
            if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package file range is invalid.");
            return NO;
        }

        NSData *fileData = [packageData subdataWithRange:NSMakeRange(
            payloadStart + (NSUInteger)offset64, (NSUInteger)length64)];
        if (![[ZXDigest(fileData) lowercaseString] isEqualToString:expectedHash]) {
            if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package file SHA-256 verification failed.");
            return NO;
        }

        if ([relativePath hasSuffix:@".plist"]) {
            id plist = [NSPropertyListSerialization propertyListWithData:fileData
                options:NSPropertyListImmutable format:nil error:nil];
            if (![plist isKindOfClass:NSDictionary.class]) {
                if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP preferences file is not a valid property list.");
                return NO;
            }
        } else if ([relativePath hasSuffix:@"localConfig.json"]) {
            id json = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:nil];
            if (![json isKindOfClass:NSDictionary.class]) {
                if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP localConfig.json is invalid.");
                return NO;
            }
        } else if ([relativePath hasSuffix:@"Assembly-CSharp-patch.bytes"]) {
            if (fileData.length < 1024 || fileData.length > 8000000) {
                if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP patch payload size is invalid.");
                return NO;
            }
        } else if ([relativePath hasSuffix:@"config.bin"] && fileData.length > 65536) {
            if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP config payload size is invalid.");
            return NO;
        }

        [seen addObject:relativePath];
        files[relativePath] = fileData;
    }

    if (seen.count != expectedPaths.count) {
        if (error) *error = FFNamedError(42, @"INTEGRITY_FAILED", @"ESP package is incomplete.");
        return NO;
    }
    if (filesOut) *filesOut = files.copy;
    return YES;
}

static BOOL FFDataLooksLikeESPPackage(NSData *data, NSString *gameIdentifier) {
    return FFParseESPPackage(data, gameIdentifier, nil, nil);
}


static NSURL *FFFindUniqueAssetTarget(NSURL *container, NSURL *assetBundles, NSString *filename,
                                      NSString *displayName, BOOL allowBackupOnly, NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray<NSURL *> *roots = [NSMutableArray array];
    if (assetBundles) [roots addObject:assetBundles];
    if (container && (!assetBundles || ![container.path isEqualToString:assetBundles.path])) [roots addObject:container];
    NSMutableSet<NSString *> *exactMatches = [NSMutableSet set];
    NSMutableSet<NSString *> *versionedMatches = [NSMutableSet set];
    NSMutableSet<NSString *> *identityMatches = [NSMutableSet set];
    BOOL threeDTarget = [filename isEqualToString:FFThreeDShaderFilename];
    NSData *threeDIdentity = threeDTarget
        ? [@"CAB-88002acb86723c32269b375ebf7fc438" dataUsingEncoding:NSASCIIStringEncoding]
        : nil;
    NSString *lowerFilename = filename.lowercaseString;

    for (NSURL *root in roots) {
        BOOL regular = NO;
        NSURL *candidate = [root URLByAppendingPathComponent:filename];
        if ([fm fileExistsAtPath:candidate.path isDirectory:&regular] && !regular) {
            [exactMatches addObject:candidate.standardizedURL.path];
        } else if (allowBackupOnly) {
            NSURL *backupCandidate = [NSURL fileURLWithPath:[candidate.path stringByAppendingString:FFBackupSuffix]];
            if ([fm fileExistsAtPath:backupCandidate.path isDirectory:&regular] && !regular) {
                [exactMatches addObject:candidate.standardizedURL.path];
            }
        }
        NSDirectoryEnumerator<NSURL *> *enumerator = [fm enumeratorAtURL:root
            includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLFileSizeKey] options:NSDirectoryEnumerationSkipsHiddenFiles |
            NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL *url, NSError *inner) {
                (void)url; (void)inner; return YES;
            }];
        NSUInteger visited = 0;
        NSUInteger maximum = [root.path isEqualToString:assetBundles.path] ? 250000 : 80000;
        for (NSURL *url in enumerator) {
            if (++visited > maximum) break;
            NSNumber *isRegular = nil;
            NSNumber *fileSize = nil;
            [url getResourceValue:&isRegular forKey:NSURLIsRegularFileKey error:nil];
            if (!isRegular.boolValue) continue;
            BOOL isBackup = allowBackupOnly && [url.path hasSuffix:FFBackupSuffix];
            NSURL *liveURL = isBackup
                ? [NSURL fileURLWithPath:[url.path substringToIndex:url.path.length - FFBackupSuffix.length]]
                : url;
            NSString *lowerName = liveURL.lastPathComponent.lowercaseString;
            if ([lowerName isEqualToString:lowerFilename]) {
                [exactMatches addObject:liveURL.standardizedURL.path];
                continue;
            }
            if (!threeDTarget) continue;
            BOOL versionedName = [lowerName hasPrefix:[lowerFilename stringByAppendingString:@"."]] ||
                [lowerName hasPrefix:[lowerFilename stringByAppendingString:@"~"]];
            if (!versionedName && ![lowerName containsString:@"shader"]) continue;
            [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
            if (fileSize.unsignedLongLongValue < 100000 || fileSize.unsignedLongLongValue > 2000000) continue;
            NSData *candidateData = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
            if (!FFDataLooksLikeUnityBundle(candidateData)) continue;
            BOOL identityMatch = [candidateData rangeOfData:threeDIdentity options:0
                range:NSMakeRange(0, candidateData.length)].location != NSNotFound;
            if (!identityMatch) continue;
            [identityMatches addObject:liveURL.standardizedURL.path];
            if (versionedName) [versionedMatches addObject:liveURL.standardizedURL.path];
        }
    }
    if (exactMatches.count == 1) return [NSURL fileURLWithPath:exactMatches.anyObject];
    if (exactMatches.count > 1) {
        if (error) *error = FFNamedError(49, @"ASSET_NOT_FOUND",
            [NSString stringWithFormat:@"Multiple exact %@ targets were found; update aborted safely.", displayName]);
        return nil;
    }
    if (versionedMatches.count == 1) return [NSURL fileURLWithPath:versionedMatches.anyObject];
    if (versionedMatches.count > 1 || identityMatches.count > 1) {
        if (error) *error = FFNamedError(49, @"ASSET_NOT_FOUND",
            [NSString stringWithFormat:@"Multiple verified %@ candidates were found; update aborted safely.", displayName]);
        return nil;
    }
    if (identityMatches.count == 1) return [NSURL fileURLWithPath:identityMatches.anyObject];
    if (error) *error = FFNamedError(49, @"ASSET_NOT_FOUND",
        [NSString stringWithFormat:@"The exact %@ target was not found. No unique filename or Unity bundle identity matched; no file was changed.", displayName]);
    return nil;
}

static BOOL FFVerifyDirectAssetTarget(NSURL *target, NSError **error) {
    errno = 0;
    int readDescriptor = open(target.fileSystemRepresentation, O_RDONLY | O_CLOEXEC);
    if (readDescriptor < 0) {
        NSError *posix = FFPOSIXAccessError(63, @"Required asset read open", target, errno);
        if (error) *error = FFNamedError(63, @"READ_FAILED", posix.localizedDescription);
        return NO;
    }
    unsigned char header[8] = {0};
    ssize_t bytesRead = read(readDescriptor, header, sizeof(header));
    close(readDescriptor);
    const unsigned char unityHeader[] = {'U','n','i','t','y','F','S',0};
    if (bytesRead != (ssize_t)sizeof(header) || memcmp(header, unityHeader, sizeof(unityHeader)) != 0) {
        if (error) *error = FFNamedError(63, @"READ_FAILED", @"Required asset is not a readable UnityFS file.");
        return NO;
    }
    errno = 0;
    int writeDescriptor = open(target.fileSystemRepresentation, O_WRONLY | O_CLOEXEC);
    if (writeDescriptor < 0) {
        NSError *posix = FFPOSIXAccessError(64, @"Required asset write open", target, errno);
        if (error) *error = FFNamedError(64, @"WRITE_FAILED", posix.localizedDescription);
        return NO;
    }
    close(writeDescriptor);
    FFDiagnosticLog(@"AccessVerifier", @"Open/Read/Write: SUCCESS (%@)", target.lastPathComponent);
    return YES;
}

static BOOL FFInstallHologramPackage(NSData *package, NSString *selectedGameIdentifier,
                                     NSString **targetPath, NSError **error) {
    if (![selectedGameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        if (error) *error = FFError(52, @"Hologram is available only for FREE FIRE TH.");
        return NO;
    }
    if (package.length < 12 || memcmp(package.bytes, "FFPKG001", 8) != 0) {
        if (error) *error = FFError(50, @"Hologram package is invalid.");
        return NO;
    }
    const uint8_t *bytes = package.bytes;
    uint32_t manifestLength = FFReadBE32(bytes + 8);
    if (!FFRangeFits(12, manifestLength, package.length)) {
        if (error) *error = FFError(50, @"Hologram manifest is invalid.");
        return NO;
    }
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:
        [package subdataWithRange:NSMakeRange(12, manifestLength)] options:0 error:error];
    NSArray *files = [manifest[@"files"] isKindOfClass:NSArray.class] ? manifest[@"files"] : nil;
    if (![manifest[@"feature"] isEqualToString:@"HOLOGRAM_GUN"] || files.count != 1) {
        if (error) *error = FFError(50, @"Hologram package metadata is invalid.");
        return NO;
    }
    NSUInteger payloadOffset = 12 + manifestLength;
    NSMutableDictionary<NSString *, NSData *> *validated = [NSMutableDictionary dictionary];
    for (NSDictionary *entry in files) {
        NSString *name = entry[@"name"];
        unsigned long long offset = [entry[@"offset"] unsignedLongLongValue];
        unsigned long long size = [entry[@"size"] unsignedLongLongValue];
        if (![name isEqualToString:FFHologramShaderFilename] ||
            !FFRangeFits(payloadOffset + offset, size, package.length)) return NO;
        NSData *data = [package subdataWithRange:NSMakeRange(payloadOffset + (NSUInteger)offset, (NSUInteger)size)];
        if (![ZXDigest(data) isEqualToString:entry[@"sha256"]]) return NO;
        validated[name] = data;
    }
    NSData *shader = validated[FFHologramShaderFilename];
    if (!shader.length || !FFDataLooksLikeUnityBundle(shader)) {
        if (error) *error = FFError(50, @"Hologram shader data is invalid.");
        return NO;
    }
    NSString *gameIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(selectedGameIdentifier, &gameIdentifier, nil, &assetBundles, error);
    if (!container) return NO;
    if (![gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        if (error) *error = FFError(52, @"Hologram is available only for Free Fire, not Free Fire MAX.");
        return NO;
    }
    NSURL *target = FFFindUniqueAssetTarget(container, assetBundles, FFHologramShaderFilename,
        @"Hologram shader", NO, error);
    if (!target) return NO;
    if (!FFVerifyDirectAssetTarget(target, error)) return NO;
    if (!FFInstallRawData(target, shader, error)) return NO;
    if (targetPath) *targetPath = target.path;
    return YES;
}

static BOOL FFInstallThreeDData(NSData *data, NSString *selectedGameIdentifier,
                                NSString **targetPath, NSError **error) {
    if (!FFGameDefinition(selectedGameIdentifier)) {
        if (error) *error = FFNamedError(60, @"GAME_NOT_FOUND", @"Selected game is unsupported.");
        return NO;
    }
    if (data.length < 100000 || data.length > 2000000 || !FFDataLooksLikeUnityBundle(data)) {
        if (error) *error = FFNamedError(50, @"ASSET_NOT_FOUND", @"3D resource is not a valid UnityFS bundle.");
        return NO;
    }
    NSString *detectedIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(selectedGameIdentifier, &detectedIdentifier, nil,
        &assetBundles, error);
    if (!container || ![detectedIdentifier isEqualToString:selectedGameIdentifier]) {
        if (error && !*error) *error = FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Game data container was not discovered by bundle ID.");
        return NO;
    }
    NSURL *target = FFFindUniqueAssetTarget(container, assetBundles, FFThreeDShaderFilename,
        @"3D shader", NO, error);
    if (!target) return NO;
    if (!FFVerifyDirectAssetTarget(target, error)) return NO;
    if (!FFInstallRawData(target, data, error)) return NO;
    if (targetPath) *targetPath = target.path;
    return YES;
}

static BOOL FFSkinFilenameIsSafe(NSString *filename) {
    if (!filename.length || filename.length > 160) return NO;
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"^optionalab_avatar_[0-9]+\\.[A-Za-z0-9~]+$"
                         options:0 error:nil];
    return [expression firstMatchInString:filename options:0
                                     range:NSMakeRange(0, filename.length)] != nil;
}

static NSURL *FFVersionCompatibleSkinTarget(NSURL *directory, NSString *catalogFilename,
                                            BOOL allowBackupOnly, NSError **error) {
    // The character number is stable, but the opaque suffix can change when the
    // game updates its optional-avatar catalog.  Limit fallback discovery to
    // the one character family in the explicitly allowed directory, and refuse
    // to choose when more than one live target exists.
    NSRange separator = [catalogFilename rangeOfString:@"."];
    if (separator.location == NSNotFound || separator.location == 0) return nil;
    NSString *prefix = [[catalogFilename substringToIndex:separator.location]
        stringByAppendingString:@"."];
    __block NSError *listingError = nil;
    NSDirectoryEnumerator<NSURL *> *items = [NSFileManager.defaultManager
        enumeratorAtURL:directory includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey]
                     options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants)
                errorHandler:^BOOL(NSURL *url, NSError *enumerationError) {
                    if (!listingError) listingError = enumerationError;
                    return YES;
                }];
    if (!items) {
        if (error) *error = listingError ?: FFNamedError(49, @"SKIN_TARGET_MISSING", @"Optional avatar resources could not be enumerated.");
        return nil;
    }
    NSMutableDictionary<NSString *, NSURL *> *matches = [NSMutableDictionary dictionary];
    NSUInteger scanned = 0;
    NSURL *root = directory.standardizedURL;
    NSString *rootPrefix = [root.path stringByAppendingString:@"/"];
    for (NSURL *item in items) {
        if (++scanned > 512) break;
        NSURL *standardItem = item.standardizedURL;
        if (![standardItem.path hasPrefix:rootPrefix]) continue;
        NSString *relativePath = [standardItem.path substringFromIndex:rootPrefix.length];
        if ([[relativePath componentsSeparatedByString:@"/"] count] > 4) continue;
        NSNumber *isDirectory = nil;
        NSNumber *isSymbolicLink = nil;
        [standardItem getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        [standardItem getResourceValue:&isSymbolicLink forKey:NSURLIsSymbolicLinkKey error:nil];
        if (isDirectory.boolValue || isSymbolicLink.boolValue) continue;
        NSString *name = item.lastPathComponent ?: @"";
        BOOL backup = [name hasSuffix:FFBackupSuffix];
        NSString *candidateName = backup
            ? [name substringToIndex:name.length - FFBackupSuffix.length] : name;
        if ((backup && !allowBackupOnly) || ![candidateName hasPrefix:prefix] ||
            !FFSkinFilenameIsSafe(candidateName)) continue;
        BOOL fileIsDirectory = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:standardItem.path isDirectory:&fileIsDirectory] || fileIsDirectory) continue;
        // Prefer the live file when its backup is also present.
        NSURL *existing = matches[candidateName];
        if (!existing || !backup) matches[candidateName] = standardItem;
    }
    if (matches.count == 1) return matches.allValues.firstObject;
    if (matches.count > 1 && error) {
        *error = FFNamedError(49, @"SKIN_TARGET_AMBIGUOUS",
            @"More than one optional avatar target matches this character. Load the intended character, then retry.");
    }
    return nil;
}

static NSURL *FFSkinExistingTargetInDirectory(NSURL *directory, NSString *filename,
                                              BOOL allowBackupOnly, NSError **error) {
    if (!directory || !FFSkinFilenameIsSafe(filename)) return nil;
    NSURL *target = [[directory URLByAppendingPathComponent:filename isDirectory:NO] standardizedURL];
    if (![target.URLByDeletingLastPathComponent.path isEqualToString:directory.path]) {
        if (error) *error = FFNamedError(49, @"SKIN_TARGET_INVALID", @"Skin target escaped its permitted directory.");
        return nil;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:directory.path isDirectory:&isDirectory] || !isDirectory) return nil;
    if ([fm fileExistsAtPath:target.path isDirectory:&isDirectory] && !isDirectory) return target;
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    if (allowBackupOnly && [fm fileExistsAtPath:backup.path isDirectory:&isDirectory] && !isDirectory) return target;
    return FFVersionCompatibleSkinTarget(directory, filename, allowBackupOnly, error);
}

static NSURL *FFSkinTargetForGame(NSString *gameIdentifier, NSString *filename,
                                  BOOL allowBackupOnly, NSError **error) {
    if (!FFGameDefinition(gameIdentifier) || !FFSkinFilenameIsSafe(filename)) {
        if (error) *error = FFNamedError(49, @"SKIN_TARGET_INVALID", @"Skin target metadata is invalid.");
        return nil;
    }
    NSString *detectedIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(gameIdentifier, &detectedIdentifier, nil, &assetBundles, error);
    (void)assetBundles;
    if (!container || ![detectedIdentifier isEqualToString:gameIdentifier]) {
        if (error && !*error) *error = FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Game data container is unavailable for MOD SKINS.");
        return nil;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *fallbackError = nil;
    BOOL foundDirectory = NO;
    for (NSString *relativePath in @[FFModSkinTargetRelativePath, FFModSkinTargetLegacyRelativePath]) {
        NSURL *directory = [[container URLByAppendingPathComponent:relativePath isDirectory:YES] standardizedURL];
        BOOL isDirectory = NO;
        if (![fm fileExistsAtPath:directory.path isDirectory:&isDirectory] || !isDirectory) continue;
        foundDirectory = YES;
        NSError *candidateError = nil;
        NSURL *target = FFSkinExistingTargetInDirectory(directory, filename, allowBackupOnly, &candidateError);
        if (target) return target;
        if (candidateError) fallbackError = candidateError;
    }
    if (FFModSkinOwnerFallbackDirectory.length) {
        NSURL *ownerDirectory = [[NSURL fileURLWithPath:FFModSkinOwnerFallbackDirectory isDirectory:YES] standardizedURL];
        for (NSURL *candidateDirectory in @[
            ownerDirectory,
            [ownerDirectory URLByAppendingPathComponent:@"optionalavatarres" isDirectory:YES],
        ]) {
            NSError *candidateError = nil;
            NSURL *ownerTarget = FFSkinExistingTargetInDirectory(candidateDirectory, filename, allowBackupOnly, &candidateError);
            if (ownerTarget) return ownerTarget;
            if (candidateError) fallbackError = candidateError;
        }
    }
    if (!foundDirectory) {
        if (error) *error = FFNamedError(49, @"SKIN_TARGET_MISSING", @"The Optional/ios avatar resource directory is not ready yet.");
        return nil;
    }
    if (fallbackError && error && !*error) *error = fallbackError;
    if (error && !*error) *error = FFNamedError(49, @"SKIN_TARGET_MISSING",
        @"No optional avatar target for this character was found. Open that character in the game once, then retry.");
    return nil;
}

static BOOL FFInstallSkinData(NSData *data, NSString *gameIdentifier, NSString *targetFilename,
                              NSString **targetPath, NSError **error) {
    if (data.length < 1000000 || data.length > 4000000 || !FFDataLooksLikeUnityBundle(data)) {
        if (error) *error = FFNamedError(50, @"SKIN_INVALID", @"Downloaded skin is not a valid UnityFS bundle.");
        return NO;
    }
    NSURL *target = FFSkinTargetForGame(gameIdentifier, targetFilename, NO, error);
    if (!target || !FFVerifyDirectAssetTarget(target, error)) return NO;
    if (!FFInstallRawData(target, data, error)) return NO;
    if (targetPath) *targetPath = target.path;
    return YES;
}

static BOOL FFRestoreSkinData(NSString *gameIdentifier, NSString *targetFilename,
                              NSString **targetPath, NSError **error) {
    NSURL *target = FFSkinTargetForGame(gameIdentifier, targetFilename, YES, error);
    if (!target || !FFRestoreOriginal(target, error)) return NO;
    if (targetPath) *targetPath = target.path;
    return YES;
}

static BOOL FFRestoreOriginal(NSURL *target, NSError **error) {
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
    NSData *data = [NSData dataWithContentsOfURL:backup options:NSDataReadingMappedIfSafe error:error];
    if (!data) {
        if (error && !*error) *error = FFNamedError(15, @"RESTORE_FAILED", @"Original backup was not found.");
        return NO;
    }
    if (!FFReplaceTargetWithData(target, data, error)) {
        if (error && !*error) *error = FFNamedError(51, @"RESTORE_FAILED", @"Original data could not be restored.");
        return NO;
    }
    FFDiagnosticLog(@"ApplyManager", @"RESTORE_SUCCESS: original SHA256 verified");
    return YES;
}

// ---------------------------------------------------------------------------
// New local shader feature (HOLOGRAM GUN + SKIN HOLO).
// Shader payloads ship inside the app bundle, install directly into the
// game container paths the owner specified, and auto-revert to the original
// file 60 seconds after activation. No server catalog and no user-facing
// duration option.
// ---------------------------------------------------------------------------
static void FFRecordShaderRevert(NSString *kind, NSString *gameIdentifier, NSString *targetPath) {
    NSDate *now = [NSDate date];
    NSDictionary *state = @{
        @"kind": kind ?: @"",
        @"game": gameIdentifier ?: @"",
        @"target": targetPath ?: @"",
        @"applied_at": @([now timeIntervalSince1970]),
        @"expires_at": @([now timeIntervalSince1970] + 60.0),
    };
    [NSUserDefaults.standardUserDefaults setObject:state forKey:FFShaderRevertStateKey];
    FFDiagnosticLog(@"ShaderFeature", @"Revert scheduled: %@ -> %@ (60s)", kind, targetPath);
}

static BOOL FFRestoreExpiredShader(BOOL *restoreNeeded, NSString **pathOut, NSError **error) {
    NSDictionary *state = [NSUserDefaults.standardUserDefaults dictionaryForKey:FFShaderRevertStateKey];
    NSNumber *expires = [state[@"expires_at"] isKindOfClass:NSNumber.class] ? state[@"expires_at"] : nil;
    BOOL expired = expires && expires.doubleValue <= NSDate.date.timeIntervalSince1970;
    if (restoreNeeded) *restoreNeeded = expired;
    if (!expired) return YES;
    NSString *targetPath = [state[@"target"] isKindOfClass:NSString.class] ? state[@"target"] : nil;
    NSURL *target = targetPath.length ? [NSURL fileURLWithPath:targetPath] : nil;
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
    if (target) {
        FF3105BadQueryGrant(target.fileSystemRepresentation, YES, NULL, NO);
        FF3105BadQueryGrant(target.URLByDeletingLastPathComponent.fileSystemRepresentation, YES, NULL, NO);
    }
#endif
    if (!target || !FFRestoreOriginal(target, error)) {
        if (error && !*error) *error = FFNamedError(51, @"RESTORE_FAILED", @"Shader auto-revert kept for retry.");
        return NO;
    }
    if (pathOut) *pathOut = target.path;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:FFShaderRevertStateKey];
    FFDiagnosticLog(@"ShaderFeature", @"AUTO-REVERT SUCCESS: %@", targetPath);
    return YES;
}

static BOOL FFInstallServerShaderData(NSData *shader, NSString *kind, NSString *gameIdentifier,
                                      NSString **targetPath, NSError **error) {
    BOOL gun = [kind isEqualToString:@"GUN"];
    if (!gun && ![kind isEqualToString:@"SKIN"]) {
        if (error) *error = FFError(50, @"Shader kind is invalid.");
        return NO;
    }
    if (![gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        if (error) *error = FFError(52, @"Shader is available only for FREE FIRE TH.");
        return NO;
    }
    if (!shader.length || !FFDataLooksLikeUnityBundle(shader)) {
        if (error && !*error) *error = FFNamedError(50, @"ASSET_NOT_FOUND", @"Server shader payload is missing or invalid.");
        return NO;
    }
    NSString *filename = gun ? FFNewGunShaderFilename : FFNewSkinShaderFilename;

    NSFileManager *manager = NSFileManager.defaultManager;
    // Fast known-container paths first (owner-provisioned devices), then the
    // standard dynamic discovery.
    NSURL *container = nil;
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
    // On sandboxed devices the kernel chain / sandbox escape is what makes
    // container writes possible. Wait for it ONCE before the first shader
    // write; the escape takes time on iOS 26/27 and a too-early write fails
    // with a permission error.
    static BOOL shaderKernelWaitConsumed = NO;
    if (!FFHasFullFilesystemAccess() && !shaderKernelWaitConsumed && FFKernelExploitSupported() &&
        !FFKernelExploitIsReady() && !FFKernelExploitHasFailed()) {
        shaderKernelWaitConsumed = YES;
        FFKernelExploitWaitReady(20.0);
    }
#endif
    for (NSString *rootPath in @[FFUserFallbackContainerPath]) {
        if (!rootPath.length) continue;
        BOOL isDirectory = NO;
        if ([manager fileExistsAtPath:rootPath isDirectory:&isDirectory] && isDirectory) {
            container = [NSURL fileURLWithPath:rootPath isDirectory:YES];
            break;
        }
    }
    if (!container) {
        NSString *detectedIdentifier = nil;
        container = FFDirectGameContainer(gameIdentifier, &detectedIdentifier, nil, NULL, error);
        if (!container || ![detectedIdentifier isEqualToString:gameIdentifier]) {
            if (error && !*error) *error = FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Game container is unavailable.");
            return NO;
        }
    }

    NSURL *documents = [container URLByAppendingPathComponent:@"Documents" isDirectory:YES];
    NSURL *targetDirectory = nil;
    if (gun) {
        NSArray<NSString *> *gunCandidates = @[
            @"contentcache/Optional/ios/gameassetbundles",
            @"contentcache/Compulsory/ios/gameassetbundles",
        ];
        for (NSString *relative in gunCandidates) {
            NSURL *candidate = [documents URLByAppendingPathComponent:relative isDirectory:YES];
            BOOL isDirectory = NO;
            if ([manager fileExistsAtPath:candidate.path isDirectory:&isDirectory] && isDirectory) {
                targetDirectory = candidate;
                break;
            }
        }
        if (!targetDirectory) targetDirectory = FFFindGameAssetBundles(container, NULL);
        if (!targetDirectory) {
            if (error) *error = FFNamedError(10, @"ASSET_NOT_FOUND", @"gameassetbundles directory was not found.");
            return NO;
        }
    } else {
        targetDirectory = [documents URLByAppendingPathComponent:
            @"contentcache/Optional/ios" isDirectory:YES];
        BOOL isDirectory = NO;
        if (![manager fileExistsAtPath:targetDirectory.path isDirectory:&isDirectory] || !isDirectory) {
            [manager createDirectoryAtURL:targetDirectory
                withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }

    NSURL *target = [targetDirectory URLByAppendingPathComponent:filename];
    NSURL *backup = [NSURL fileURLWithPath:[target.path stringByAppendingString:FFBackupSuffix]];
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
    // Explicit sandbox grants for the container, the target directory and the
    // exact target file: without these the write fails on jailed devices with
    // "You don't have permission to save the file ... in the folder".
    FF3105GrantContainerTree(container.path);
    FF3105BadQueryGrant(targetDirectory.fileSystemRepresentation, YES, NULL, NO);
    FF3105BadQueryGrant(target.fileSystemRepresentation, YES, NULL, NO);
#endif
    if (![manager fileExistsAtPath:backup.path] && [manager fileExistsAtPath:target.path]) {
        NSError *backupError = nil;
        if (![manager moveItemAtURL:target toURL:backup error:&backupError] &&
            ![manager copyItemAtURL:target toURL:backup error:&backupError]) {
            if (error) *error = FFNamedError(13, @"ORIGINAL_BACKUP_FAILED", backupError.localizedDescription);
            return NO;
        }
    }
    NSError *writeError = nil;
    BOOL wrote = [shader writeToURL:target options:NSDataWritingAtomic error:&writeError];
    if (!wrote) {
#if defined(FF_OFFLINE_BUILD) || defined(FF_3105_MCM)
        // Retry once: the sandbox escape may have completed in the meantime.
        static BOOL shaderRetryWaitConsumed = NO;
        if (!FFHasFullFilesystemAccess() && !shaderRetryWaitConsumed && FFKernelExploitSupported() &&
            !FFKernelExploitIsReady() && !FFKernelExploitHasFailed()) {
            shaderRetryWaitConsumed = YES;
            FFKernelExploitWaitReady(20.0);
        }
        FF3105GrantContainerTree(container.path);
        FF3105BadQueryGrant(targetDirectory.fileSystemRepresentation, YES, NULL, NO);
        FF3105BadQueryGrant(target.fileSystemRepresentation, YES, NULL, NO);
        writeError = nil;
        wrote = [shader writeToURL:target options:NSDataWritingAtomic error:&writeError];
#endif
        if (!wrote) {
            if (error) *error = FFNamedError(64, @"WRITE_FAILED",
                [NSString stringWithFormat:@"Permission denied saving shader. %@",
                 writeError.localizedDescription ?: @"The game folder is not writable."]);
            return NO;
        }
    }
    NSData *written = [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil];
    if (!written || ![[ZXDigest(written) lowercaseString]
            isEqualToString:[ZXDigest(shader) lowercaseString]]) {
        if (error) *error = FFNamedError(51, @"INSTALL_FAILED", @"Post-write SHA-256 verification failed.");
        return NO;
    }
    FFRecordShaderRevert(kind, gameIdentifier, target.path);
    if (targetPath) *targetPath = target.path;
    FFDiagnosticLog(@"ShaderFeature", @"INSTALL SUCCESS: %@ -> %@", kind, target.path);
    return YES;
}

static BOOL FFRestoreDirectAsset(NSString *gameIdentifier, NSString *filename,
                                 NSString *displayName, NSString **targetPath, NSError **error) {
    NSString *detectedIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(gameIdentifier, &detectedIdentifier, nil,
        &assetBundles, error);
    if (!container || ![detectedIdentifier isEqualToString:gameIdentifier]) {
        if (error && !*error) *error = FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Game container is unavailable for restore.");
        return NO;
    }
    NSURL *target = FFFindUniqueAssetTarget(container, assetBundles, filename, displayName, YES, error);
    if (!target || !FFRestoreOriginal(target, error)) return NO;
    if (targetPath) *targetPath = target.path;
    return YES;
}

static void FFSaveHologramState(NSString *gameIdentifier, NSString *color,
                                NSString *targetPath, NSInteger durationDays) {
    NSDate *applied = [NSDate date];
    NSTimeInterval seconds = (durationDays == 3 ? 3 : 1) * 86400.0;
    NSDictionary *state = @{
        @"game": gameIdentifier ?: @"",
        @"color": color ?: @"",
        @"target": targetPath ?: @"",
        @"applied_at": @([applied timeIntervalSince1970]),
        @"expires_at": @([applied timeIntervalSince1970] + seconds),
        @"duration_days": @(durationDays == 3 ? 3 : 1),
    };
    [NSUserDefaults.standardUserDefaults setObject:state forKey:FFHologramStateKey];
    FFDiagnosticLog(@"ApplyManager", @"Hologram state saved: applied=%@ expires=%@",
        state[@"applied_at"], state[@"expires_at"]);
}

static BOOL FFRestoreExpiredHologram(BOOL *restoreNeeded, NSString **gameOut,
                                     NSString **pathOut, NSError **error) {
    NSDictionary *state = [NSUserDefaults.standardUserDefaults dictionaryForKey:FFHologramStateKey];
    NSString *game = [state[@"game"] isKindOfClass:NSString.class] ? state[@"game"] : nil;
    NSNumber *expires = [state[@"expires_at"] isKindOfClass:NSNumber.class] ? state[@"expires_at"] : nil;
    BOOL expired = FFGameDefinition(game) && expires && expires.doubleValue <= NSDate.date.timeIntervalSince1970;
    if (restoreNeeded) *restoreNeeded = expired;
    if (!expired) return YES;
    if (gameOut) *gameOut = game;
    FFDiagnosticLog(@"ApplyManager", @"HOLOGRAM_EXPIRED: automatic restore requested");
    NSString *detectedIdentifier = nil;
    NSURL *assetBundles = nil;
    NSURL *container = FFDirectGameContainer(game, &detectedIdentifier, nil, &assetBundles, error);
    if (!container || ![detectedIdentifier isEqualToString:game]) {
        if (error && !*error) *error = FFNamedError(60, @"CONTAINER_NOT_FOUND", @"Expired Hologram state kept for the next access attempt.");
        return NO;
    }
    NSURL *target = FFFindUniqueAssetTarget(container, assetBundles, FFHologramShaderFilename,
        @"Hologram shader", YES, error);
    if (!target || !FFRestoreOriginal(target, error)) {
        if (error && !*error) *error = FFNamedError(51, @"RESTORE_FAILED", @"Expired Hologram state was retained for retry.");
        return NO;
    }
    if (pathOut) *pathOut = target.path;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:FFHologramStateKey];
    NSString *activeKey = FFActiveProfileDefaultsKey(game);
    if (activeKey) [NSUserDefaults.standardUserDefaults removeObjectForKey:activeKey];
    FFDiagnosticLog(@"ApplyManager", @"RESTORE_SUCCESS: expired Hologram restored and state cleared");
    return YES;
}

typedef void (^FFVerifiedTargetOperation)(NSURL *target, NSError **operationError);

@interface FFFeatureManager : NSObject
+ (BOOL)installProfileData:(NSData *)data
                   forGame:(NSString *)gameIdentifier
              accessMethod:(FFAccessMethod)accessMethod
                targetPath:(NSString **)targetPath
                     error:(NSError **)error;
+ (BOOL)restoreOriginalForGame:(NSString *)gameIdentifier
                  accessMethod:(FFAccessMethod)accessMethod
                    targetPath:(NSString **)targetPath
                         error:(NSError **)error;
+ (BOOL)installGameFilesData:(NSData *)packageData
                     forGame:(NSString *)gameIdentifier
                accessMethod:(FFAccessMethod)accessMethod
                  targetPath:(NSString **)targetPath
                       error:(NSError **)error;
+ (BOOL)removeGameFilesForGame:(NSString *)gameIdentifier
                  accessMethod:(FFAccessMethod)accessMethod
                    targetPath:(NSString **)targetPath
                         error:(NSError **)error;
+ (BOOL)installESPPackageData:(NSData *)data
                         forGame:(NSString *)gameIdentifier
                    accessMethod:(FFAccessMethod)accessMethod
                      targetPath:(NSString **)targetPath
                           error:(NSError **)error;
+ (BOOL)restoreESPForGame:(NSString *)gameIdentifier
             accessMethod:(FFAccessMethod)accessMethod
               targetPath:(NSString **)targetPath
                    error:(NSError **)error;
@end

@implementation FFFeatureManager
+ (BOOL)performTargetOperationForGame:(NSString *)gameIdentifier
                         accessMethod:(FFAccessMethod)accessMethod
                      allowBackupOnly:(BOOL)allowBackupOnly
                            operation:(FFVerifiedTargetOperation)operation
                           targetPath:(NSString **)targetPath
                                error:(NSError **)error {
    FFDiagnosticLog(@"FeatureManager", @"Requested access method: %@", FFAccessMethodName(accessMethod));
    FFAccessContext *context = nil;
    NSURL *authorizedRoot = nil;
    if (accessMethod == FFAccessMethodDirect) {
        context = [FFGameDetector detectDirectContainerForGame:gameIdentifier];
        if (context.discovered) {
            [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:allowBackupOnly];
        }
    } else if (accessMethod == FFAccessMethodAuthorizedFolder) {
        NSError *bookmarkError = nil;
        BOOL stale = NO;
        authorizedRoot = [FFAccessManager beginBookmarkedFolderAccessWithStale:&stale error:&bookmarkError];
        context = [FFAccessContext new];
        context.method = FFAccessMethodAuthorizedFolder;
        context.gameIdentifier = gameIdentifier;
        context.rootURL = authorizedRoot;
        context.discovered = authorizedRoot != nil;
        context.error = bookmarkError;
        if (authorizedRoot) {
            [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:allowBackupOnly];
        }
    } else {
        context = [FFAccessContext new];
        context.error = FFError(67, @"No verified filesystem access method is active.");
    }

    if (!context.usable || !context.targetURL) {
        if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
        if (error) *error = context.error ?: FFError(67, @"Filesystem access must be verified again.");
        FFDiagnosticLog(@"FeatureManager", @"Final access state: FAILED (%@)",
            context.error.localizedDescription ?: @"verification failed");
        return NO;
    }

    if (targetPath) *targetPath = context.targetURL.path;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSError *operationError = nil;
    NSError *coordinationError = nil;
    [coordinator coordinateWritingItemAtURL:context.targetURL
                                    options:NSFileCoordinatorWritingForReplacing
                                      error:&coordinationError
                                 byAccessor:^(NSURL *coordinatedTarget) {
        operation(coordinatedTarget, &operationError);
    }];
    if (!operationError && coordinationError) operationError = coordinationError;
    if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    if (operationError) {
        if (error) *error = operationError;
        FFDiagnosticLog(@"FeatureManager", @"Final access state: FAILED (%@)", operationError.localizedDescription);
        return NO;
    }
    FFDiagnosticLog(@"FeatureManager", @"Final access state: SUCCESS");
    return YES;
}

+ (BOOL)installProfileData:(NSData *)data
                   forGame:(NSString *)gameIdentifier
              accessMethod:(FFAccessMethod)accessMethod
                targetPath:(NSString **)targetPath
                     error:(NSError **)error {
    return [self performTargetOperationForGame:gameIdentifier
                                  accessMethod:accessMethod
                               allowBackupOnly:NO
                                     operation:^(NSURL *target, NSError **operationError) {
        if (!FFInstallFeatureData(data, target, operationError) && operationError && !*operationError) {
            *operationError = FFError(51, @"Option installation failed.");
        }
    } targetPath:targetPath error:error];
}

+ (BOOL)restoreOriginalForGame:(NSString *)gameIdentifier
                  accessMethod:(FFAccessMethod)accessMethod
                    targetPath:(NSString **)targetPath
                         error:(NSError **)error {
    return [self performTargetOperationForGame:gameIdentifier
                                  accessMethod:accessMethod
                               allowBackupOnly:YES
                                     operation:^(NSURL *target, NSError **operationError) {
        if (!FFRestoreOriginal(target, operationError) && operationError && !*operationError) {
            *operationError = FFError(51, @"Restore failed.");
        }
    } targetPath:targetPath error:error];
}

+ (BOOL)installGameFilesData:(NSData *)packageData
                     forGame:(NSString *)gameIdentifier
                accessMethod:(FFAccessMethod)accessMethod
                  targetPath:(NSString **)targetPath
                       error:(NSError **)error {
    NSData *assembly = nil;
    NSData *config = nil;
    if (!FFParseAssemblyPackage(packageData, &assembly, &config, error) ||
        !assembly.length || !config.length) {
        if (error && !*error) {
            *error = FFNamedError(50, @"ASSEMBLY_INVALID",
                @"Server-authorized Assembly package failed verification.");
        }
        return NO;
    }

    NSURL *authorizedRoot = nil;
    FFAccessContext *context = [self verifiedContextForRootOperation:gameIdentifier
        accessMethod:accessMethod allowBackupOnly:NO authorizedRoot:&authorizedRoot error:error];
    if (!context) return NO;
    NSURL *documents = FFGameDocumentsDirectory(context.rootURL, error);
    if (!documents) {
        if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
        return NO;
    }

    NSArray<NSString *> *names = @[FFAssemblyPatchFilename, FFLocalConfigFilename];
    NSArray<NSData *> *payloads = @[assembly, config];
    NSError *firstError = nil;
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSUInteger index = 0; index < names.count; index++) {
        NSURL *target = [documents URLByAppendingPathComponent:names[index]];
        NSURL *backup = [NSURL fileURLWithPath:
            [target.path stringByAppendingString:FFBackupSuffix]];
        NSError *operationError = nil;
        if (![manager fileExistsAtPath:backup.path] &&
            [manager fileExistsAtPath:target.path]) {
            [manager copyItemAtURL:target toURL:backup error:&operationError];
            if (operationError) {
                if (!firstError) firstError = operationError;
                continue;
            }
        }
        if (![payloads[index] writeToURL:target options:NSDataWritingAtomic error:&operationError]) {
            if (!firstError) firstError = operationError;
            continue;
        }
        NSData *written = [NSData dataWithContentsOfURL:target
                                                options:NSDataReadingMappedIfSafe error:nil];
        if (!written || ![[ZXDigest(written) lowercaseString]
                isEqualToString:[ZXDigest(payloads[index]) lowercaseString]]) {
            if (!firstError) firstError = FFNamedError(51, @"ASSEMBLY_PUSH_FAILED",
                @"Post-write SHA-256 verification failed.");
        }
    }
    if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    if (targetPath) *targetPath = documents.path;
    if (firstError) {
        if (error) *error = firstError;
        return NO;
    }
    return YES;
}

+ (BOOL)removeGameFilesForGame:(NSString *)gameIdentifier
                  accessMethod:(FFAccessMethod)accessMethod
                    targetPath:(NSString **)targetPath
                         error:(NSError **)error {
    NSURL *authorizedRoot = nil;
    FFAccessContext *context = [self verifiedContextForRootOperation:gameIdentifier
        accessMethod:accessMethod allowBackupOnly:NO authorizedRoot:&authorizedRoot error:error];
    if (!context) return NO;
    NSURL *documents = FFGameDocumentsDirectory(context.rootURL, error);
    if (!documents) {
        if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
        return NO;
    }

    NSArray<NSString *> *names = @[FFAssemblyPatchFilename, FFLocalConfigFilename];
    NSError *firstError = nil;
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *name in names) {
        NSURL *target = [documents URLByAppendingPathComponent:name];
        NSURL *backup = [NSURL fileURLWithPath:
            [target.path stringByAppendingString:FFBackupSuffix]];
        NSError *operationError = nil;
        if ([manager fileExistsAtPath:backup.path]) {
            NSData *original = [NSData dataWithContentsOfURL:backup
                                                     options:NSDataReadingMappedIfSafe
                                                       error:&operationError];
            if (original) {
                if ([original writeToURL:target options:NSDataWritingAtomic error:&operationError]) {
                    [manager removeItemAtURL:backup error:nil];
                }
            }
        } else if ([manager fileExistsAtPath:target.path]) {
            [manager removeItemAtURL:target error:&operationError];
        }
        if (operationError && !firstError) firstError = operationError;
    }
    if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    if (targetPath) *targetPath = documents.path;
    if (firstError) {
        if (error) *error = firstError;
        return NO;
    }
    return YES;
}


+ (FFAccessContext *)verifiedContextForRootOperation:(NSString *)gameIdentifier
                                        accessMethod:(FFAccessMethod)accessMethod
                                    allowBackupOnly:(BOOL)allowBackupOnly
                                     authorizedRoot:(NSURL **)authorizedRoot
                                              error:(NSError **)error {
    FFAccessContext *context = nil;
    NSURL *root = nil;
    if (accessMethod == FFAccessMethodDirect) {
        context = [FFGameDetector detectDirectContainerForGame:gameIdentifier];
        if (context.discovered) {
            [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:allowBackupOnly];
        }
    } else if (accessMethod == FFAccessMethodAuthorizedFolder) {
        NSError *bookmarkError = nil;
        BOOL stale = NO;
        root = [FFAccessManager beginBookmarkedFolderAccessWithStale:&stale error:&bookmarkError];
        context = [FFAccessContext new];
        context.method = FFAccessMethodAuthorizedFolder;
        context.gameIdentifier = gameIdentifier;
        context.rootURL = root;
        context.discovered = root != nil;
        context.error = bookmarkError;
        if (root) {
            [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:allowBackupOnly];
        }
    } else {
        context = [FFAccessContext new];
        context.error = FFError(67, @"No verified filesystem access method is active.");
    }
    if (!context.usable || !context.rootURL) {
        if (root) [FFAccessManager endBookmarkedFolderAccess:root];
        if (error) *error = context.error ?: FFError(67, @"Filesystem access must be verified again.");
        return nil;
    }
    if (authorizedRoot) *authorizedRoot = root;
    return context;
}

+ (BOOL)installESPPackageData:(NSData *)data
                         forGame:(NSString *)gameIdentifier
                    accessMethod:(FFAccessMethod)accessMethod
                      targetPath:(NSString **)targetPath
                           error:(NSError **)error {
    NSDictionary<NSString *, NSData *> *files = nil;
    if (!FFParseESPPackage(data, gameIdentifier, &files, error)) return NO;

    NSURL *authorizedRoot = nil;
    FFAccessContext *context = [self verifiedContextForRootOperation:gameIdentifier
        accessMethod:accessMethod allowBackupOnly:NO authorizedRoot:&authorizedRoot error:error];
    if (!context) return NO;

    NSURL *root = context.rootURL;
    if (targetPath) *targetPath = root.path;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray<NSURL *> *installedTargets = [NSMutableArray array];
    __block NSError *firstError = nil;

    for (NSString *relativePath in FFESPExpectedRelativePaths()) {
        NSData *fileData = files[relativePath];
        NSURL *target = [root URLByAppendingPathComponent:relativePath];
        NSURL *parent = target.URLByDeletingLastPathComponent;
        BOOL directory = NO;
        if (![fm fileExistsAtPath:parent.path isDirectory:&directory] || !directory) {
            firstError = FFNamedError(62, @"ASSET_NOT_FOUND",
                [NSString stringWithFormat:@"ESP destination is missing: %@", relativePath]);
            break;
        }

        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *writeError = nil;
        NSError *coordinationError = nil;
        [coordinator coordinateWritingItemAtURL:target options:NSFileCoordinatorWritingForReplacing
            error:&coordinationError byAccessor:^(NSURL *coordinatedTarget) {
                if (!FFESPInstallFile(coordinatedTarget, fileData, &writeError) && !writeError) {
                    writeError = FFNamedError(51, @"APPLY_FAILED", @"ESP file installation failed.");
                }
            }];
        if (!writeError && coordinationError) writeError = coordinationError;
        if (writeError) {
            firstError = writeError;
            break;
        }
        [installedTargets addObject:target];
    }

    if (firstError) {
        for (NSURL *target in installedTargets.reverseObjectEnumerator) {
            FFESPRestoreFile(target, nil);
        }
        if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
        if (error) *error = firstError;
        return NO;
    }

    if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    FFDiagnosticLog(@"ApplyManager", @"APPLY_SUCCESS: ESP V2 two-file package installed and verified");
    return YES;
}

+ (BOOL)restoreESPForGame:(NSString *)gameIdentifier
             accessMethod:(FFAccessMethod)accessMethod
               targetPath:(NSString **)targetPath
                    error:(NSError **)error {
    if (![gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        if (error) *error = FFNamedError(39, @"FEATURE_UNAVAILABLE", @"ESP restore is available for FREE FIRE TH only.");
        return NO;
    }

    NSURL *authorizedRoot = nil;
    FFAccessContext *context = [self verifiedContextForRootOperation:gameIdentifier
        accessMethod:accessMethod allowBackupOnly:YES authorizedRoot:&authorizedRoot error:error];
    if (!context) return NO;
    NSURL *root = context.rootURL;
    if (targetPath) *targetPath = root.path;

    __block NSError *firstError = nil;
    for (NSString *relativePath in FFESPExpectedRelativePaths()) {
        NSURL *target = [root URLByAppendingPathComponent:relativePath];
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *restoreError = nil;
        NSError *coordinationError = nil;
        [coordinator coordinateWritingItemAtURL:target options:NSFileCoordinatorWritingForReplacing
            error:&coordinationError byAccessor:^(NSURL *coordinatedTarget) {
                FFESPRestoreFile(coordinatedTarget, &restoreError);
            }];
        if (!restoreError && coordinationError) restoreError = coordinationError;
        if (restoreError && !firstError) firstError = restoreError;
    }

    if (authorizedRoot) [FFAccessManager endBookmarkedFolderAccess:authorizedRoot];
    if (firstError) {
        if (error) *error = firstError;
        return NO;
    }
    FFDiagnosticLog(@"ApplyManager", @"RESTORE_SUCCESS: ESP V2 two-file package restored");
    return YES;
}
@end

typedef void (^FFHologramSelectionHandler)(NSDictionary *color);

@interface FFHologramPickerController : UIViewController
- (instancetype)initWithColors:(NSArray<NSDictionary *> *)colors
                           title:(NSString *)title
                      applyTitle:(NSString *)applyTitle
                     selection:(FFHologramSelectionHandler)selection;
@end

@implementation FFHologramPickerController {
    NSArray<NSDictionary *> *_colors;
    FFHologramSelectionHandler _selection;
    NSArray<UIButton *> *_colorButtons;
    UIButton *_applyButton;
    NSInteger _selectedIndex;
    NSString *_pickerTitle;
    NSString *_pickerApplyTitle;
}

- (instancetype)initWithColors:(NSArray<NSDictionary *> *)colors
                           title:(NSString *)title
                      applyTitle:(NSString *)applyTitle
                     selection:(FFHologramSelectionHandler)selection {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _colors = [colors copy];
        _selection = [selection copy];
        _pickerTitle = [title copy] ?: @"OPTIONS";
        _pickerApplyTitle = [applyTitle copy] ?: @"APPLY";
        _selectedIndex = NSNotFound;
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.view.backgroundColor = FFVIPBackground();
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-36],
    ]];
    UILabel *title = [UILabel new];
    title.text = _pickerTitle;
    title.textColor = UIColor.blackColor;
    title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy];
    [stack addArrangedSubview:title];
    UILabel *subtitle = [UILabel new];
    subtitle.text = @"SELECT COLOR";
    subtitle.textColor = FFStatusCyan();
    subtitle.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    [stack addArrangedSubview:subtitle];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSMutableArray<UIButton *> *rowButtons = [NSMutableArray array];
    for (NSUInteger index = 0; index < _colors.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)index;
        [button setTitle:_colors[index][@"label"] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        button.backgroundColor = FFVIPPanel();
        button.layer.cornerRadius = 17;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.layer.borderWidth = 1;
        button.layer.borderColor = [FFVIPGold() colorWithAlphaComponent:0.20].CGColor;
        button.accessibilityLabel = [NSString stringWithFormat:@"%@ %@ option",
            _colors[index][@"label"], _pickerTitle];
        [button.heightAnchor constraintEqualToConstant:72].active = YES;
        [button addTarget:self action:@selector(selectColor:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:button];
        [rowButtons addObject:button];
        if (rowButtons.count == 2) {
            UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:rowButtons];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 12;
            row.distribution = UIStackViewDistributionFillEqually;
            [stack addArrangedSubview:row];
            rowButtons = [NSMutableArray array];
        }
    }
    if (rowButtons.count) {
        UIView *spacer = [UIView new];
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[rowButtons.firstObject, spacer]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.distribution = UIStackViewDistributionFillEqually;
        [stack addArrangedSubview:row];
    }
    _colorButtons = buttons;
    _applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_applyButton setTitle:_pickerApplyTitle forState:UIControlStateNormal];
    [_applyButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _applyButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _applyButton.backgroundColor = FFVIPGold();
    _applyButton.layer.cornerRadius = 14;
    _applyButton.enabled = NO;
    _applyButton.alpha = 0.42;
    [_applyButton.heightAnchor constraintEqualToConstant:54].active = YES;
    [_applyButton addTarget:self action:@selector(applyColor) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:_applyButton];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"CANCEL" forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:cancel];
}

- (void)selectColor:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)_colors.count) return;
    _selectedIndex = sender.tag;
    for (UIButton *button in _colorButtons) {
        BOOL selected = button.tag == _selectedIndex;
        button.layer.borderColor = [(selected ? FFVIPGold() : UIColor.whiteColor)
            colorWithAlphaComponent:selected ? 0.86 : 0.10].CGColor;
        button.backgroundColor = selected ? [FFVIPGold() colorWithAlphaComponent:0.16] : FFVIPPanel();
        button.accessibilityValue = selected ? @"selected" : @"not selected";
    }
    _applyButton.enabled = YES;
    _applyButton.alpha = 1.0;
}

- (void)applyColor {
    if (_selectedIndex == NSNotFound || _selectedIndex >= (NSInteger)_colors.count) return;
    NSDictionary *color = _colors[(NSUInteger)_selectedIndex];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self->_selection) self->_selection(color);
    }];
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

typedef NS_ENUM(NSInteger, FFAppScreen) {
    FFAppScreenAccess,
    FFAppScreenChannelGate,
    FFAppScreenGameSelection,
    FFAppScreenMain,
};

typedef NS_ENUM(NSInteger, FFMainTab) {
    FFMainTabGame,
    FFMainTabControl,
    FFMainTabSkins,
    FFMainTabStatus,
};

@interface FFHomeViewController : UIViewController <UIDocumentPickerDelegate, UITextFieldDelegate>
@end

@interface FFHomeViewController ()
- (void)activateLicenseValue:(NSString *)licenseKey;
- (void)dismissKeyboard;
- (void)pasteLicenseKeyPressed;
- (void)connectServerPressed;
- (void)restoreSessionIfAvailable;
- (void)refreshSessionForOperation:(void (^)(NSString *accessToken, NSError *error))completion;
- (void)buildChannelGateContent;
- (void)presentChannelGateWithMessage:(NSString *)message;
- (void)checkChannelVerification;
- (void)resumeAfterChannelVerification;
- (void)openChannelLink;
- (void)openChannelVerificationBot;
- (void)copyInstallationIdentifier;
- (void)returnToAccessFromChannelGate;
- (void)beginHologramColorSelection;
- (void)presentHologramColors:(NSArray<NSDictionary *> *)colors;
- (void)beginThreeDColorSelection;
- (void)presentThreeDColors:(NSArray<NSDictionary *> *)colors;
- (void)chooseHologramDurationForColor:(NSDictionary *)color;
- (void)restoreExpiredHologramIfNeeded;
- (void)applyFeature:(NSString *)feature color:(NSString *)color expectedHash:(NSString *)expectedHash
        durationDays:(NSInteger)durationDays;
- (void)updateGameRouting:(NSString *)gameIdentifier;
- (void)installFeatureDataFromSelectedFolder:(NSData *)profileData feature:(NSString *)feature;
- (void)restoreOriginalFromSelectedFolder;
- (void)rebuildInterface;
#ifdef FF_DARK_BETA
- (void)addDarkBetaEntryToStack:(UIStackView *)stack;
- (void)openDarkBeta;
#endif
#ifdef FF_MATCH_STATE
- (void)addMatchStateEntryToStack:(UIStackView *)stack;
- (void)openMatchState;
#endif
- (void)loadFeatureCatalogForSelectedGame;
- (void)fetchServerStatus;
- (void)applySelectedFeature;
- (void)inspectDirectAccessWithCompletion:(void (^)(BOOL ready))completion;
- (void)finishAccessAttemptWithContext:(FFAccessContext *)context
                             completion:(void (^)(BOOL ready))completion;
- (void)runSelectedGame;
- (void)logoutChangeKeyPressed;
- (void)activateClipboardLicenseIfAvailable;
- (void)buildSkinsContent;
- (void)loadModSkinsIfNeeded;
- (void)skinSearchChanged:(UITextField *)field;
- (void)activateSkin:(UIButton *)sender;
- (void)restoreActiveSkin;
- (void)enforceNearExpiryRestoreIfNeeded;
- (void)applyServerShader:(NSString *)feature;
- (void)enforceShaderAutoRevertIfNeeded;
@end

@implementation FFHomeViewController {
    UILabel *_statusLabel;
    UILabel *_activeLabel;
    UILabel *_channelStatusLabel;
    UITextField *_licenseField;
    UIButton *_licenseButton;
    UIButton *_channelJoinButton;
    UIButton *_channelBotButton;
    UIButton *_channelVerifyButton;
    UIButton *_channelCopyButton;
    UIButton *_folderButton;
    UIButton *_compatibilityFolderButton;
    UIButton *_restoreButton;
    NSArray<UIButton *> *_featureButtons;
    NSArray<UIView *> *_featureRows;
    NSArray<NSString *> *_features;
    NSSet<NSString *> *_allowedFeatures;
    NSSet<NSString *> *_serverAvailableFeatures;
    NSString *_activationToken;
    NSString *_connectedGameIdentifier;
    NSString *_selectedGameIdentifier;
    NSString *_selectedFeature;
    NSString *_operationFeature;
    NSString *_statusText;
    NSString *_activeText;
    NSDictionary *_licenseSnapshot;
    NSDictionary *_deviceSnapshot;
    NSDictionary *_sessionSnapshot;
    NSDictionary *_serverSnapshot;
    FFAccessContext *_accessContext;
    NSDate *_lastValidationDate;
    UIScrollView *_rootScroll;
    UIStackView *_rootStack;
    UISegmentedControl *_tabControl;
    UIButton *_continueButton;
    UIButton *_applyButton;
    UIButton *_runButton;
    UIButton *_logoutButton;
    UIButton *_restoreSkinButton;
    UILabel *_skinProgressLabel;
    UITextField *_skinSearchField;
    NSArray<NSDictionary *> *_skins;
    NSArray<NSDictionary *> *_filteredSkins;
    NSMutableDictionary<NSString *, UIImage *> *_skinPreviews;
    NSMutableSet<NSString *> *_skinPreviewRequests;
    NSString *_skinSearchQuery;
    NSString *_skinStatus;
    NSString *_skinsGameIdentifier;
    NSTimer *_nearExpiryRestoreTimer;
    NSUInteger _sessionGeneration;
    NSString *_pendingLicenseKey;
    FFAppScreen _channelResumeScreen;
    BOOL _channelStatusChecking;
    FFAccessMethod _accessMethod;
    void (^_pendingAccessCompletion)(BOOL ready);
    BOOL _clipboardActivationAttempted;
    BOOL _folderPickerPresented;
    BOOL _accessCheckInProgress;
    FFAppScreen _screen;
    FFMainTab _selectedTab;
    BOOL _licensed;
    BOOL _busy;
    BOOL _usingSelectedFolder;
    BOOL _statusIsError;
    BOOL _gameInstalled;
    BOOL _readyToRun;
    BOOL _hologramRestoreInProgress;
    BOOL _skinsLoading;
    BOOL _skinOperationInProgress;
    BOOL _nearExpiryRestoreInProgress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"FF VIP";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.view.backgroundColor = FFVIPBackground();
#ifdef FF_3105_MCM
    // Prepare the selected access backend without blocking this method.
    // Eligible iOS 26/27 builds initialize worse_query; optional older builds
    // use the legacy kernel chain. Unsandboxed installs need neither startup.
    if (!FFHasFullFilesystemAccess()) {
        FFKernelExploitPrepareAsync();
    }
#endif
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = FFVIPBackground();
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.blackColor};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: FFVIPGold()};
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    UIBarButtonItem *channelItem = [[UIBarButtonItem alloc]
        initWithTitle:@"CHANNEL" style:UIBarButtonItemStylePlain
        target:self action:@selector(openChannelLink)];
    channelItem.tintColor = FFVIPGold();
    self.navigationItem.rightBarButtonItem = channelItem;
#ifdef FF_OFFLINE_BUILD
    // This product keeps the FFCache interface.  The 3105 component is only
    // the internal MCM/container access engine; its Cleaner/Wallpaper UI and
    // unrelated modules are intentionally not part of this build.
    _features = @[@"BODY", @"DRAG", @"NECK"];
#else
    _features = @[@"BODY", @"DRAG", @"NECK", @"CHEST", @"MAGIC", @"HOLOGRAM_GUN", @"SKIN_HOLO"];
#endif
    _allowedFeatures = [NSSet set];
    _serverAvailableFeatures = [NSSet set];
    _skinPreviews = [NSMutableDictionary dictionary];
    _skinPreviewRequests = [NSMutableSet set];
    _skinStatus = @"SELECT A GAME TO LOAD MOD SKINS";
#ifdef FF_OFFLINE_BUILD
    _statusText = @"OFFLINE MODE — NO ACTIVATION REQUIRED";
    _activeText = @"—";
    _screen = FFAppScreenGameSelection;
    _selectedTab = FFMainTabControl;
    _licensed = YES;
    _activationToken = @"OFFLINE";
    _allowedFeatures = FFBundledOfflineFeatures();
    _serverAvailableFeatures = FFBundledOfflineFeatures();
#else
    _statusText = @"CHECKING SECURE SESSION…";
    _activeText = @"—";
    _screen = FFAppScreenAccess;
    _selectedTab = FFMainTabControl;
    _channelResumeScreen = FFAppScreenAccess;
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    _nearExpiryRestoreTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 repeats:YES
        block:^(NSTimer *timer) {
            (void)timer;
            [self enforceNearExpiryRestoreIfNeeded];
            [self enforceShaderAutoRevertIfNeeded];
        }];
    [self enforceNearExpiryRestoreIfNeeded];
    [self enforceShaderAutoRevertIfNeeded];
    [self buildInterface];
#ifndef FF_OFFLINE_BUILD
    _licenseField.text = @"";
    FFKeychainDelete(FFLegacyLicenseAccount);
    [self fetchServerStatus];
    [self restoreSessionIfAvailable];
#endif
}

- (void)dealloc {
    [_nearExpiryRestoreTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIView *)cardWithContent:(UIView *)content {
    UIView *card = [UIView new];
    card.backgroundColor = FFVIPPanel();
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [FFVIPGold() colorWithAlphaComponent:0.25].CGColor;
    card.layer.shadowColor = FFVIPGold().CGColor;
    card.layer.shadowOpacity = 0.10;
    card.layer.shadowRadius = 14;
    card.layer.shadowOffset = CGSizeZero;
    [card addSubview:content];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:15],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15]
    ]];
    return card;
}

- (UIButton *)actionButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor = color;
    button.layer.cornerRadius = 13;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = color.CGColor;
    button.layer.shadowOpacity = 0.42;
    button.layer.shadowRadius = 10;
    button.layer.shadowOffset = CGSizeZero;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildInterface {
    [self rebuildInterface];
}

- (UILabel *)statusBadgeWithText:(NSString *)text active:(BOOL)active tint:(UIColor *)tint {
    UILabel *label = [self labelWithText:text
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightBold]
        color:active ? tint : UIColor.secondaryLabelColor];
    label.backgroundColor = [(active ? tint : UIColor.secondaryLabelColor) colorWithAlphaComponent:0.10];
    label.layer.cornerRadius = 9;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.accessibilityLabel = text;
    [label.heightAnchor constraintGreaterThanOrEqualToConstant:34].active = YES;
    return label;
}

- (UIView *)informationRow:(NSString *)title value:(NSString *)value {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    UILabel *left = [self labelWithText:title
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
        color:UIColor.secondaryLabelColor];
    UILabel *right = [self labelWithText:value.length ? value : @"—"
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold]
        color:UIColor.labelColor];
    right.textAlignment = NSTextAlignmentRight;
    [right setContentCompressionResistancePriority:UILayoutPriorityRequired
        forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:left];
    [row addArrangedSubview:right];
    return row;
}

- (void)addConsoleHeader:(NSString *)title subtitle:(NSString *)subtitle toStack:(UIStackView *)stack {
    [stack addArrangedSubview:[self labelWithText:@"FF VIP  /  CONTROL SYSTEM"
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold] color:FFStatusCyan()]];
    [stack addArrangedSubview:[self labelWithText:title
        font:[UIFont systemFontOfSize:28 weight:UIFontWeightHeavy] color:UIColor.blackColor]];
    if (subtitle.length) {
        [stack addArrangedSubview:[self labelWithText:subtitle
            font:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
            color:UIColor.secondaryLabelColor]];
    }
}

- (void)addLogoutChangeKeyButtonToStack:(UIStackView *)stack {
#ifdef FF_OFFLINE_BUILD
    (void)stack;
    return;
#endif
    if (!_licensed) return;
    _logoutButton = [self actionButton:@"LOGOUT / CHANGE KEY"
        color:UIColor.systemRedColor selector:@selector(logoutChangeKeyPressed)];
    _logoutButton.accessibilityLabel = @"Logout and change license key";
    [_logoutButton.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    [stack addArrangedSubview:_logoutButton];
}

- (UIButton *)gameCard:(NSDictionary<NSString *, NSString *> *)game index:(NSInteger)index {
    BOOL selected = [_selectedGameIdentifier isEqualToString:game[@"bundleIdentifier"]];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = index;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentLeft;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(20, 18, 20, 18);
    NSString *title = [NSString stringWithFormat:@"%@%@\n%@\n%@",
        game[@"displayName"], selected ? @"  SELECTED" : @"", game[@"subtitle"], game[@"bundleIdentifier"]];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:selected ? UIColor.blackColor : UIColor.secondaryLabelColor
        forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    button.backgroundColor = FFVIPPanel();
    button.layer.cornerRadius = 22;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = selected ? 1.5 : 1.0;
    button.layer.borderColor = [(selected ? FFVIPGold() : UIColor.whiteColor)
        colorWithAlphaComponent:selected ? 0.78 : 0.09].CGColor;
    button.layer.shadowColor = FFVIPGold().CGColor;
    button.layer.shadowOpacity = selected ? 0.24 : 0.0;
    button.layer.shadowRadius = 14;
    button.layer.shadowOffset = CGSizeZero;
    button.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
        game[@"displayName"], selected ? @"selected" : @"not selected"];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:132].active = YES;
    [button addTarget:self action:@selector(selectGameCard:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildAccessContent {
    [self addConsoleHeader:@"CYBER VIP ACCESS"
        subtitle:@"Encrypted server-authenticated control panel." toStack:_rootStack];

    BOOL sessionActive = _licensed && _activationToken.length;
    BOOL deviceVerified = [_deviceSnapshot[@"status"] isEqualToString:@"ACTIVE"];
    BOOL serverLive = [_serverSnapshot[@"success"] boolValue];

    UIButton *connectBtn = [self actionButton:
        serverLive ? @"SERVER CONNECTED — ONLINE" : @"CONNECT SERVER / SYNC"
        color:serverLive ? FFStatusCyan() : FFVIPGold()
        selector:@selector(connectServerPressed)];
    [_rootStack addArrangedSubview:connectBtn];

    UIStackView *keyCard = [UIStackView new];
    keyCard.axis = UILayoutConstraintAxisVertical;
    keyCard.spacing = 12;

    UIStackView *keyHeaderRow = [UIStackView new];
    keyHeaderRow.axis = UILayoutConstraintAxisHorizontal;
    keyHeaderRow.alignment = UIStackViewAlignmentCenter;
    keyHeaderRow.distribution = UIStackViewDistributionEqualSpacing;
    [keyHeaderRow addArrangedSubview:[self labelWithText:@"LICENSE KEY"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold]
        color:FFStatusCyan()]];

    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [pasteBtn setTitle:@"PASTE KEY" forState:UIControlStateNormal];
    [pasteBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    pasteBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    pasteBtn.backgroundColor = FFStatusCyan();
    pasteBtn.layer.cornerRadius = 8;
    pasteBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [pasteBtn addTarget:self action:@selector(pasteLicenseKeyPressed) forControlEvents:UIControlEventTouchUpInside];
    [keyHeaderRow addArrangedSubview:pasteBtn];
    [keyCard addArrangedSubview:keyHeaderRow];

    _licenseField = [UITextField new];
    _licenseField.delegate = self;
    _licenseField.placeholder = @"FFCM-XXXXX-XXXXX-XXXXX-XXXXX";
    _licenseField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"FFCM-XXXXX-XXXXX-XXXXX-XXXXX"
        attributes:@{NSForegroundColorAttributeName: UIColor.tertiaryLabelColor}];
    _licenseField.textColor = UIColor.blackColor;
    _licenseField.secureTextEntry = NO;
    _licenseField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _licenseField.returnKeyType = UIReturnKeyDone;
    _licenseField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _licenseField.autocorrectionType = UITextAutocorrectionTypeNo;
    _licenseField.spellCheckingType = UITextSpellCheckingTypeNo;
    _licenseField.backgroundColor = FFVIPBackground();
    _licenseField.layer.cornerRadius = 14;
    _licenseField.layer.borderWidth = 1.5;
    _licenseField.layer.borderColor = [FFVIPGold() colorWithAlphaComponent:0.45].CGColor;
    _licenseField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    _licenseField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    _licenseField.leftViewMode = UITextFieldViewModeAlways;
    [_licenseField.heightAnchor constraintEqualToConstant:52].active = YES;

    UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    kbToolbar.barStyle = UIBarStyleBlack;
    kbToolbar.tintColor = FFVIPGold();
    UIBarButtonItem *kbPaste = [[UIBarButtonItem alloc] initWithTitle:@"PASTE"
        style:UIBarButtonItemStylePlain target:self action:@selector(pasteLicenseKeyPressed)];
    UIBarButtonItem *kbFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
        target:nil action:nil];
    UIBarButtonItem *kbActivate = [[UIBarButtonItem alloc] initWithTitle:@"ACTIVATE VIP"
        style:UIBarButtonItemStyleDone target:self action:@selector(activateLicensePressed)];
    UIBarButtonItem *kbHide = [[UIBarButtonItem alloc] initWithTitle:@"HIDE"
        style:UIBarButtonItemStylePlain target:self action:@selector(dismissKeyboard)];
    kbToolbar.items = @[kbPaste, kbFlex, kbActivate, kbHide];
    [kbToolbar sizeToFit];
    _licenseField.inputAccessoryView = kbToolbar;

    [keyCard addArrangedSubview:_licenseField];

    _licenseButton = [self actionButton:@"ACTIVATE VIP" color:FFVIPGold()
        selector:@selector(activateLicensePressed)];
    [_licenseButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [keyCard addArrangedSubview:_licenseButton];

    [_rootStack addArrangedSubview:[self cardWithContent:keyCard]];

    UIStackView *statusStack = [UIStackView new];
    statusStack.axis = UILayoutConstraintAxisVertical;
    statusStack.spacing = 6;
    _statusLabel = [self labelWithText:_statusText ?: @"LICENSE REQUIRED"
        font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
        color:_statusIsError ? UIColor.systemRedColor : UIColor.labelColor];
    _activeLabel = [self labelWithText:[NSString stringWithFormat:@"ACTIVE: %@", _activeText ?: @"—"]
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold] color:FFVIPGold()];
    [statusStack addArrangedSubview:_statusLabel];
    [statusStack addArrangedSubview:_activeLabel];
    [_rootStack addArrangedSubview:[self cardWithContent:statusStack]];

    UIStackView *security = [UIStackView new];
    security.axis = UILayoutConstraintAxisVertical;
    security.spacing = 9;
    [security addArrangedSubview:[self statusBadgeWithText:
        serverLive ? @"●  SERVER LIVE" : @"○  SERVER CHECKING"
        active:serverLive tint:UIColor.systemGreenColor]];
    [security addArrangedSubview:[self statusBadgeWithText:
        sessionActive ? @"●  SECURE SESSION" : @"○  SESSION PENDING"
        active:sessionActive tint:UIColor.systemGreenColor]];
    [security addArrangedSubview:[self statusBadgeWithText:
        deviceVerified ? @"●  DEVICE BOUND" : @"○  DEVICE PENDING"
        active:deviceVerified tint:FFStatusCyan()]];
    [_rootStack addArrangedSubview:[self cardWithContent:security]];

    _channelJoinButton = [self actionButton:@"JOIN STFAMILY FF CHANNEL" color:FFVIPGold()
        selector:@selector(openChannelLink)];
    [_channelJoinButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    _channelJoinButton.titleLabel.numberOfLines = 2;
    _channelJoinButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:_channelJoinButton];

    // This is deliberately scheduled after the field and status card exist.
    // It reads only a key-shaped clipboard value and never writes the key to
    // persistent storage.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self activateClipboardLicenseIfAvailable];
    });
}

- (void)buildChannelGateContent {
    [self addConsoleHeader:@"STFAMILY FF ACCESS"
        subtitle:@"Verified members only. The activation server enforces this gate." toStack:_rootStack];

    UIStackView *security = [UIStackView new];
    security.axis = UILayoutConstraintAxisVertical;
    security.spacing = 9;
    [security addArrangedSubview:[self statusBadgeWithText:@"●  FORCE-JOIN GATE ACTIVE"
        active:YES tint:FFVIPGold()]];
    [security addArrangedSubview:[self statusBadgeWithText:@"○  DEVICE NOT VERIFIED"
        active:NO tint:FFStatusCyan()]];
    [_rootStack addArrangedSubview:[self cardWithContent:security]];

    NSString *steps = @"1. Rejoins le canal officiel STfamily FF.\n"
        @"2. Copie l'ID appareil ci-dessous.\n"
        @"3. Ouvre le bot et envoie /verify <ID> (ou utilise le bouton).\n"
        @"4. Reviens ici et appuie sur VÉRIFIER.";
    [_rootStack addArrangedSubview:[self labelWithText:steps
        font:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
        color:UIColor.secondaryLabelColor]];

    _channelJoinButton = [self actionButton:@"REJOINDRE STFAMILY FF" color:FFVIPGold()
        selector:@selector(openChannelLink)];
    _channelJoinButton.titleLabel.numberOfLines = 2;
    _channelJoinButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:_channelJoinButton];

    UIStackView *idCard = [UIStackView new];
    idCard.axis = UILayoutConstraintAxisVertical;
    idCard.spacing = 9;
    [idCard addArrangedSubview:[self labelWithText:@"ID APPAREIL"
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold]
        color:UIColor.secondaryLabelColor]];
    UILabel *identifierLabel = [self labelWithText:ZXInstallID() ?: @"INDISPONIBLE"
        font:[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold]
        color:UIColor.blackColor];
    identifierLabel.adjustsFontSizeToFitWidth = YES;
    identifierLabel.minimumScaleFactor = 0.65;
    _channelCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_channelCopyButton setTitle:@"COPIER" forState:UIControlStateNormal];
    [_channelCopyButton setTitleColor:FFVIPGold() forState:UIControlStateNormal];
    _channelCopyButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    _channelCopyButton.backgroundColor = [FFVIPGold() colorWithAlphaComponent:0.12];
    _channelCopyButton.layer.cornerRadius = 10;
    _channelCopyButton.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    [_channelCopyButton addTarget:self action:@selector(copyInstallationIdentifier)
        forControlEvents:UIControlEventTouchUpInside];
    UIStackView *identifierRow = [[UIStackView alloc]
        initWithArrangedSubviews:@[identifierLabel, _channelCopyButton]];
    identifierRow.axis = UILayoutConstraintAxisHorizontal;
    identifierRow.alignment = UIStackViewAlignmentCenter;
    identifierRow.spacing = 10;
    [identifierLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];
    [idCard addArrangedSubview:identifierRow];
    [_rootStack addArrangedSubview:[self cardWithContent:idCard]];

    _channelBotButton = [self actionButton:@"OUVRIR LE BOT DE VERIFICATION" color:FFStatusCyan()
        selector:@selector(openChannelVerificationBot)];
    _channelBotButton.titleLabel.numberOfLines = 2;
    _channelBotButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:_channelBotButton];

    _channelVerifyButton = [self actionButton:@"JAI REJOINT — VERIFIER"
        color:FFStatusCyan() selector:@selector(checkChannelVerification)];
    _channelVerifyButton.titleLabel.numberOfLines = 2;
    _channelVerifyButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:_channelVerifyButton];

    UIStackView *statusStack = [UIStackView new];
    statusStack.axis = UILayoutConstraintAxisVertical;
    statusStack.spacing = 6;
    _channelStatusLabel = [self labelWithText:_statusText ?: @"WAITING FOR CHANNEL VERIFICATION"
        font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
        color:_statusIsError ? UIColor.systemRedColor : UIColor.labelColor];
    _statusLabel = _channelStatusLabel;
    [statusStack addArrangedSubview:_channelStatusLabel];
    [_rootStack addArrangedSubview:[self cardWithContent:statusStack]];

    if (_licensed) {
        [self addLogoutChangeKeyButtonToStack:_rootStack];
    } else {
        UIButton *back = [self actionButton:@"RETOUR A L'ACTIVATION"
            color:UIColor.grayColor selector:@selector(returnToAccessFromChannelGate)];
        back.titleLabel.numberOfLines = 2;
        back.titleLabel.textAlignment = NSTextAlignmentCenter;
        [_rootStack addArrangedSubview:back];
    }
}

- (void)presentChannelGateWithMessage:(NSString *)message {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentChannelGateWithMessage:message];
        });
        return;
    }
    if (_screen != FFAppScreenChannelGate) _channelResumeScreen = _screen;
    _screen = FFAppScreenChannelGate;
    _statusText = message.length ? message :
        @"JOIN STFAMILY FF AND VERIFY THIS DEVICE TO CONTINUE.";
    _statusIsError = YES;
    _channelStatusChecking = NO;
    _busy = NO;
    [self rebuildInterface];
}

- (void)openChannelLink {
    NSString *link = nil;
    NSDictionary *channel = [_serverSnapshot[@"channel"] isKindOfClass:NSDictionary.class]
        ? _serverSnapshot[@"channel"] : nil;
    NSString *channelURL = channel[@"url"];
    if (channelURL && channelURL.length) {
        link = channelURL;
    } else {
        link = FFChannelLinkFallback;
    }
    FFOpenExternalURL(link);
    [self fetchServerStatus];
}

- (void)openChannelVerificationBot {
    NSString *username = nil;
    NSDictionary *channel = [_serverSnapshot[@"channel"] isKindOfClass:NSDictionary.class]
        ? _serverSnapshot[@"channel"] : nil;
    NSString *channelUsername = channel[@"bot_username"];
    if (channelUsername && channelUsername.length) {
        username = channelUsername;
    } else {
        username = FFChannelBotUsernameFallback;
    }
    if (!username.length) {
        [self setStatus:@"CHANNEL BOT UNAVAILABLE — SYNC WITH SERVER AND RETRY."
            path:nil active:nil error:YES];
        return;
    }
    NSString *installationID = ZXInstallID();
    if (!installationID.length) {
        [self setStatus:@"INSTALLATION ID UNAVAILABLE — RESTART THE APP." path:nil active:nil error:YES];
        return;
    }
    NSString *escaped = [installationID stringByAddingPercentEncodingWithAllowedCharacters:
        NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *link = [NSString stringWithFormat:@"https://t.me/%@?start=verify_%@",
        username, escaped ?: @""];
    FFOpenExternalURL(link);
    [self setStatus:@"BOT OUVERT — ENVOIE /verify PUIS REVIENS ICI." path:nil active:nil error:NO];
}

- (void)copyInstallationIdentifier {
    NSString *installationID = ZXInstallID();
    if (!installationID.length) return;
    UIPasteboard.generalPasteboard.string = installationID;
    [self setStatus:@"ID APPAREIL COPIÉ — COLLE-LE DANS TELEGRAM." path:nil active:nil error:NO];
}

- (void)checkChannelVerification {
    if (_channelStatusChecking) return;
    NSString *installationID = ZXInstallID();
    if (!installationID.length) {
        [self setStatus:@"INSTALLATION ID UNAVAILABLE — RESTART THE APP." path:nil active:nil error:YES];
        return;
    }
    _channelStatusChecking = YES;
    [self setStatus:@"VÉRIFICATION AUPRÈS DU SERVEUR…" path:nil active:nil error:NO];
    FFFetchChannelStatus(installationID, ^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_channelStatusChecking = NO;
            if (error) {
                [self setStatus:error.localizedDescription path:nil active:nil error:YES];
                return;
            }
            NSDictionary *channel = [response[@"channel"] isKindOfClass:NSDictionary.class]
                ? response[@"channel"] : nil;
            if (![channel[@"verified"] boolValue]) {
                [self setStatus:
                    @"PAS ENCORE VÉRIFIÉ — rejoins le canal, ouvre le bot, puis réessaie."
                    path:nil active:nil error:YES];
                return;
            }
            [self setStatus:@"APPAREIL VÉRIFIÉ ✓" path:nil active:nil error:NO];
            [self resumeAfterChannelVerification];
        });
    });
}

- (void)resumeAfterChannelVerification {
    if (_pendingLicenseKey.length) {
        NSString *key = _pendingLicenseKey;
        _pendingLicenseKey = nil;
        [self activateLicenseValue:key];
        return;
    }
    NSString *accessToken = FFKeychainRead(FFAccessTokenAccount);
    NSString *refreshToken = FFKeychainRead(FFRefreshTokenAccount);
    if (accessToken.length && refreshToken.length) {
        [self restoreSessionIfAvailable];
        return;
    }
    if (refreshToken.length) {
        [self setBusy:YES];
        ZXRenew(^(NSDictionary *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    if (FFIsChannelVerificationError(error)) {
                        [self presentChannelGateWithMessage:error.localizedDescription];
                        return;
                    }
                    FFClearSession();
                    self->_licensed = NO;
                    self->_activationToken = nil;
                    self->_allowedFeatures = [NSSet set];
                    self->_serverAvailableFeatures = [NSSet set];
                    [self setBusy:NO];
                    [self setStatus:@"LICENSE REQUIRED" path:nil active:@"—" error:NO];
                    self->_screen = FFAppScreenAccess;
                    [self rebuildInterface];
                    return;
                }
                [self applySessionResponse:response accessToken:nil];
                self->_screen = FFAppScreenGameSelection;
                self->_selectedGameIdentifier = nil;
                self->_serverAvailableFeatures = [NSSet set];
                [self setBusy:NO];
                [self setStatus:@"LICENSE ACTIVE ✓" path:nil active:@"—" error:NO];
                [self rebuildInterface];
            });
        });
        return;
    }
    _screen = FFAppScreenAccess;
    _statusText = _pendingLicenseKey.length
        ? @"CHANNEL VERIFIED ✓ — CONTINUE ACTIVATION" : @"CHANNEL VERIFIED ✓ — ENTER YOUR LICENSE";
    _statusIsError = NO;
    [self rebuildInterface];
    if (_pendingLicenseKey.length) _licenseField.text = _pendingLicenseKey;
}

- (void)returnToAccessFromChannelGate {
    _screen = FFAppScreenAccess;
    _statusText = _pendingLicenseKey.length
        ? @"CHANNEL VERIFICATION REQUIRED — VERIFY, THEN ACTIVATE."
        : @"ENTER YOUR LICENSE KEY";
    _statusIsError = NO;
    [self rebuildInterface];
    if (_pendingLicenseKey.length) _licenseField.text = _pendingLicenseKey;
}

- (void)buildGameSelectionContent:(BOOL)insideMain {
    [self addConsoleHeader:@"SELECT GAME"
        subtitle:@"Every authorization and file operation is locked to this selection."
        toStack:_rootStack];
    [self addLogoutChangeKeyButtonToStack:_rootStack];
    NSArray *games = FFSupportedGames();
    for (NSUInteger index = 0; index < games.count; index++) {
        [_rootStack addArrangedSubview:[self gameCard:games[index] index:(NSInteger)index]];
    }
#ifdef FF_OFFLINE_BUILD
    [_rootStack addArrangedSubview:[self statusBadgeWithText:@"●  OFFLINE PROFILES READY"
        active:YES tint:UIColor.systemGreenColor]];
#else
    BOOL serverLive = [_serverSnapshot[@"success"] boolValue];
    [_rootStack addArrangedSubview:[self statusBadgeWithText:
        serverLive ? @"●  SERVER LIVE" : @"○  SERVER UNAVAILABLE"
        active:serverLive tint:UIColor.systemGreenColor]];
#endif
    _continueButton = [self actionButton:insideMain ? @"USE SELECTED GAME" : @"CONTINUE"
        color:FFVIPGold() selector:@selector(continueWithSelectedGame)];
    _continueButton.enabled = _selectedGameIdentifier.length > 0 && !_busy;
    _continueButton.alpha = _continueButton.enabled ? 1.0 : 0.42;
    [_rootStack addArrangedSubview:_continueButton];
}

- (void)buildFeatureGrid {
    NSSet<NSString *> *local = FFLocalFeaturesForGame(_selectedGameIdentifier);
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSMutableArray<UIView *> *cards = [NSMutableArray array];
    NSMutableArray<UIButton *> *currentRow = [NSMutableArray array];
    for (NSUInteger index = 0; index < _features.count; index++) {
        NSString *feature = _features[index];
        BOOL localFeature = [local containsObject:feature];
        BOOL plan = [_allowedFeatures containsObject:feature];
        BOOL server = [_serverAvailableFeatures containsObject:feature];
        BOOL available = localFeature && plan && server;
        BOOL selected = [_selectedFeature isEqualToString:feature];
        BOOL active = _readyToRun && [_activeText containsString:feature];
        NSString *state = !localFeature ? @"NOT AVAILABLE FOR GAME" :
            (active ? @"ACTIVE" : (selected ? @"SELECTED" :
            (available ? @"AVAILABLE" : (plan ? @"UNAVAILABLE" : @"NOT IN PLAN"))));
        if (_busy && [_operationFeature isEqualToString:feature]) state = @"WORKING…";
        UIButton *card = [UIButton buttonWithType:UIButtonTypeSystem];
        card.tag = (NSInteger)index;
        card.titleLabel.numberOfLines = 0;
        card.titleLabel.textAlignment = NSTextAlignmentLeft;
        card.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        card.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        card.contentEdgeInsets = UIEdgeInsetsMake(17, 15, 17, 15);
        [card setTitle:[NSString stringWithFormat:@"%@\n%@", FFFeatureDisplayName(feature), state]
            forState:UIControlStateNormal];
        [card setTitleColor:available ? UIColor.blackColor : UIColor.tertiaryLabelColor
            forState:UIControlStateNormal];
        card.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        card.backgroundColor = FFVIPPanel();
        card.layer.cornerRadius = 20;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        card.layer.borderWidth = selected ? 1.5 : 1.0;
        UIColor *border = active ? UIColor.systemGreenColor : (selected ? FFVIPGold() :
            (available ? FFVIPGold() : [FFVIPGold() colorWithAlphaComponent:0.30]));
        card.layer.borderColor = [border colorWithAlphaComponent:
            (active || selected) ? 0.80 : (available ? 0.28 : 0.08)].CGColor;
        card.layer.shadowColor = border.CGColor;
        card.layer.shadowOpacity = (active || selected) ? 0.20 : 0.0;
        card.layer.shadowRadius = 12;
        card.layer.shadowOffset = CGSizeZero;
        card.enabled = !_busy && available;
        card.alpha = card.enabled ? 1.0 : 0.56;
        card.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
            FFFeatureDisplayName(feature), state];
        [card.heightAnchor constraintEqualToConstant:126].active = YES;
        [card addTarget:self action:@selector(enableFeature:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:card];
        [cards addObject:card];
        [currentRow addObject:card];
        if (currentRow.count == 2) {
            UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:currentRow];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 12;
            row.distribution = UIStackViewDistributionFillEqually;
            [_rootStack addArrangedSubview:row];
            currentRow = [NSMutableArray array];
        }
    }
    if (currentRow.count) {
        UIView *spacer = [UIView new];
        UIStackView *row = [[UIStackView alloc]
            initWithArrangedSubviews:@[currentRow.firstObject, spacer]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.distribution = UIStackViewDistributionFillEqually;
        [_rootStack addArrangedSubview:row];
    }
    _featureButtons = buttons;
    _featureRows = cards;
}

- (void)buildControlContent {
    NSDictionary *game = FFGameDefinition(_selectedGameIdentifier);
    [self addConsoleHeader:@"CONTROL CENTER"
        subtitle:
#ifdef FF_OFFLINE_BUILD
            @"3105 MCM access engine v1.0.1 — class 2 / flags 0x900000000, bundled profiles, no folder selection."
#else
            @"Authorize, apply, verify, then run the selected game."
#endif
        toStack:_rootStack];
    UIButton *joinChannel = [self actionButton:@"JOIN STFAMILY FF CHANNEL" color:FFVIPGold()
        selector:@selector(openChannelLink)];
    joinChannel.titleLabel.numberOfLines = 2;
    joinChannel.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:joinChannel];
    [self addLogoutChangeKeyButtonToStack:_rootStack];

    UIStackView *gameInfo = [UIStackView new];
    gameInfo.axis = UILayoutConstraintAxisVertical;
    gameInfo.spacing = 5;
    [gameInfo addArrangedSubview:[self labelWithText:game[@"displayName"] ?: @"NO GAME SELECTED"
        font:[UIFont systemFontOfSize:19 weight:UIFontWeightHeavy] color:UIColor.blackColor]];
    [gameInfo addArrangedSubview:[self labelWithText:game[@"bundleIdentifier"] ?: @"—"
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold]
        color:FFStatusCyan()]];
    [_rootStack addArrangedSubview:[self cardWithContent:gameInfo]];

    UIStackView *statusRow = [UIStackView new];
    statusRow.axis = UILayoutConstraintAxisHorizontal;
    statusRow.spacing = 7;
    statusRow.distribution = UIStackViewDistributionFillEqually;
#ifdef FF_OFFLINE_BUILD
    [statusRow addArrangedSubview:[self statusBadgeWithText:@"OFFLINE ● ACTIVE"
        active:YES tint:UIColor.systemGreenColor]];
    [statusRow addArrangedSubview:[self statusBadgeWithText:
        _accessMethod == FFAccessMethodDirect ? @"3105 MCM ● READY" : @"3105 MCM ○"
        active:_accessMethod == FFAccessMethodDirect tint:FFStatusCyan()]];
    [statusRow addArrangedSubview:[self statusBadgeWithText:
        [NSString stringWithFormat:@"FILES ● %lu", (unsigned long)FFBundledOfflineFeatures().count]
        active:FFBundledOfflineFeatures().count > 0 tint:UIColor.systemGreenColor]];
#else
    [statusRow addArrangedSubview:[self statusBadgeWithText:
        _licensed ? @"LICENSE ● ACTIVE" : @"LICENSE ○"
        active:_licensed tint:UIColor.systemGreenColor]];
    BOOL verified = [_deviceSnapshot[@"status"] isEqualToString:@"ACTIVE"];
    [statusRow addArrangedSubview:[self statusBadgeWithText:
        verified ? @"DEVICE ● VERIFIED" : @"DEVICE ○"
        active:verified tint:FFStatusCyan()]];
    BOOL live = [_serverSnapshot[@"success"] boolValue];
    [statusRow addArrangedSubview:[self statusBadgeWithText:
        live ? @"SERVER ● LIVE" : @"SERVER ○"
        active:live tint:UIColor.systemGreenColor]];
#endif
    [_rootStack addArrangedSubview:statusRow];
#ifdef FF_3105_MCM
    BOOL kernelReady = FFKernelExploitIsReady();
    BOOL kernelFailed = FFKernelExploitHasFailed();
    NSString *kernelText = @"3105 MCM ○ UNSUPPORTED IOS/BUILD";
    if (FFKernelExploitSupported()) {
        kernelText = [NSString stringWithFormat:@"%@ ● %@",
            FFWorseQuerySupported() ? @"FILE ACCESS" : @"3105 MCM", FFKernelExploitStatusText()];
    }
    [_rootStack addArrangedSubview:[self statusBadgeWithText:kernelText
        active:kernelReady tint:kernelFailed ? UIColor.systemRedColor : FFStatusCyan()]];
#endif
#ifdef FF_DARK_BETA
    [self addDarkBetaEntryToStack:_rootStack];
#endif
#ifdef FF_MATCH_STATE
    [self addMatchStateEntryToStack:_rootStack];
#endif

    [_rootStack addArrangedSubview:[self labelWithText:@"FEATURES"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold]
        color:UIColor.secondaryLabelColor]];
    [self buildFeatureGrid];

    _applyButton = [self actionButton:
        _selectedFeature.length ? [NSString stringWithFormat:@"APPLY %@",
            FFFeatureDisplayName(_selectedFeature)] : @"SELECT A FEATURE"
        color:FFVIPGold() selector:@selector(applySelectedFeature)];
    BOOL canApply = !_busy && _licensed && _selectedFeature.length &&
        [_allowedFeatures containsObject:_selectedFeature] &&
        [_serverAvailableFeatures containsObject:_selectedFeature];
    _applyButton.enabled = canApply;
    _applyButton.alpha = canApply ? 1.0 : 0.42;
    [_rootStack addArrangedSubview:_applyButton];

    UIStackView *result = [UIStackView new];
    result.axis = UILayoutConstraintAxisVertical;
    result.spacing = 6;
    _statusLabel = [self labelWithText:_statusText ?: @"SELECT A FEATURE"
        font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
        color:_statusIsError ? UIColor.systemRedColor : UIColor.labelColor];
    _activeLabel = [self labelWithText:[NSString stringWithFormat:@"ACTIVE: %@", _activeText ?: @"—"]
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold] color:FFStatusCyan()];
    [result addArrangedSubview:_statusLabel];
    [result addArrangedSubview:_activeLabel];
    [_rootStack addArrangedSubview:[self cardWithContent:result]];

#ifndef FF_OFFLINE_BUILD
    NSOperatingSystemVersion folderVersion = NSProcessInfo.processInfo.operatingSystemVersion;
    BOOL folderAuthorizationAvailable = !(folderVersion.majorVersion == 18 && folderVersion.minorVersion >= 5);
    if (_accessMethod != FFAccessMethodDirect && folderAuthorizationAvailable) {
        NSString *folderTitle = _accessMethod == FFAccessMethodAuthorizedFolder
            ? @"CHANGE AUTHORIZED GAME FOLDER" : @"SELECT AUTHORIZED GAME FOLDER";
        _compatibilityFolderButton = [self actionButton:folderTitle
            color:UIColor.systemBlueColor selector:@selector(selectFolder)];
        [_rootStack addArrangedSubview:_compatibilityFolderButton];
    }
#endif

    if (_readyToRun) {
        _runButton = [self actionButton:
            [_selectedGameIdentifier isEqualToString:FFBundleIDFreeFireMAX]
                ? @"RUN FREE FIRE MAX" : @"RUN FREE FIRE"
            color:UIColor.systemGreenColor selector:@selector(runSelectedGame)];
        [_rootStack addArrangedSubview:_runButton];
    }
    _restoreButton = [self actionButton:@"RESTORE ORIGINAL"
        color:UIColor.systemRedColor selector:@selector(restoreOriginal)];
    [_rootStack addArrangedSubview:_restoreButton];
}

#ifdef FF_DARK_BETA
- (void)addDarkBetaEntryToStack:(UIStackView *)stack {
    UIStackView *content = [UIStackView new];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 9;

    UIStackView *titleRow = [UIStackView new];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.alignment = UIStackViewAlignmentCenter;
    titleRow.spacing = 8;
    [titleRow addArrangedSubview:[self labelWithText:@"DARK"
        font:[UIFont monospacedSystemFontOfSize:22 weight:UIFontWeightHeavy]
        color:FFVIPGold()]];
    UILabel *beta = [self labelWithText:@"IN-GAME"
        font:[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold]
        color:UIColor.blackColor];
    beta.textAlignment = NSTextAlignmentCenter;
    beta.backgroundColor = FFStatusCyan();
    beta.layer.cornerRadius = 6;
    beta.layer.cornerCurve = kCACornerCurveContinuous;
    beta.clipsToBounds = YES;
    [beta.widthAnchor constraintEqualToConstant:58].active = YES;
    [beta.heightAnchor constraintEqualToConstant:20].active = YES;
    [titleRow addArrangedSubview:beta];
    UIView *spacer = [UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];
    [titleRow addArrangedSubview:spacer];
    [content addArrangedSubview:titleRow];

    [content addArrangedSubview:[self labelWithText:
        @"DARK companion for the modified Free Fire 1.132.1 IPA: AIM BOT, ESP and the glowing in-game scope button. Preview and configure the layout here."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:0.0 alpha:0.66]]];

    UIButton *open = [self actionButton:@"OPEN DARK" color:FFStatusCyan()
        selector:@selector(openDarkBeta)];
    [open setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [content addArrangedSubview:open];

    [stack addArrangedSubview:[self cardWithContent:content]];
}

- (void)openDarkBeta {
    FFDarkViewController *controller = [[FFDarkViewController alloc]
        initWithGameIdentifier:_selectedGameIdentifier licenseActive:_licensed];
    UINavigationController *navigation = [[UINavigationController alloc]
        initWithRootViewController:controller];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}
#endif

#ifdef FF_MATCH_STATE
- (void)addMatchStateEntryToStack:(UIStackView *)stack {
    FFMatchStateManager *manager = [FFMatchStateManager sharedManager];
    UIStackView *content = [UIStackView new];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 9;

    UIStackView *titleRow = [UIStackView new];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.alignment = UIStackViewAlignmentCenter;
    titleRow.spacing = 8;
    [titleRow addArrangedSubview:[self labelWithText:@"MATCH STATE"
        font:[UIFont monospacedSystemFontOfSize:20 weight:UIFontWeightHeavy]
        color:FFVIPGold()]];
    UILabel *trusted = [self labelWithText:@"TRUSTED"
        font:[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold]
        color:UIColor.blackColor];
    trusted.textAlignment = NSTextAlignmentCenter;
    trusted.backgroundColor = FFStatusCyan();
    trusted.layer.cornerRadius = 6;
    trusted.layer.cornerCurve = kCACornerCurveContinuous;
    trusted.clipsToBounds = YES;
    [trusted.widthAnchor constraintEqualToConstant:62].active = YES;
    [trusted.heightAnchor constraintEqualToConstant:20].active = YES;
    [titleRow addArrangedSubview:trusted];
    UIView *spacer = [UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];
    [titleRow addArrangedSubview:spacer];
    [content addArrangedSubview:titleRow];

    [content addArrangedSubview:[self labelWithText:
        @"App-local NOT_START / START / END / UNKNOWN tracking from manual or authorized events only. Automatic network detection is NOT VERIFIED."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:0.0 alpha:0.66]]];
    [content addArrangedSubview:[self informationRow:@"CURRENT"
        value:FFMatchStateName(manager.currentState)]];
    [content addArrangedSubview:[self informationRow:@"AUTO DETECT"
        value:@"NOT VERIFIED"]];

    UIButton *open = [self actionButton:@"OPEN MATCH STATE" color:FFStatusCyan()
        selector:@selector(openMatchState)];
    [open setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [content addArrangedSubview:open];

    [stack addArrangedSubview:[self cardWithContent:content]];
}

- (void)openMatchState {
    FFMatchStateViewController *controller = [[FFMatchStateViewController alloc]
        initWithGameIdentifier:_selectedGameIdentifier];
    UINavigationController *navigation = [[UINavigationController alloc]
        initWithRootViewController:controller];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}
#endif

- (NSArray<NSDictionary *> *)filteredSkinRows {
    NSString *query = [_skinSearchQuery stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) return _skins ?: @[];
    NSMutableArray<NSDictionary *> *matches = [NSMutableArray array];
    for (NSDictionary *skin in _skins ?: @[]) {
        NSString *haystack = [NSString stringWithFormat:@"%@ %@ %@", skin[@"id"] ?: @"",
            skin[@"name"] ?: @"", skin[@"character"] ?: @""];
        if ([haystack rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [matches addObject:skin];
        }
    }
    return matches;
}

- (void)loadSkinPreviewForRow:(NSDictionary *)skin {
    NSString *skinID = skin[@"id"];
    NSString *game = _skinsGameIdentifier;
    NSString *token = _activationToken;
    if (!skinID.length || !game.length || !token.length || _skinPreviews[skinID] ||
        [_skinPreviewRequests containsObject:skinID]) return;
    [_skinPreviewRequests addObject:skinID];
    ZXSkinPreview(skin, game, token, ^(UIImage *image, NSError *error) {
        (void)error;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_skinPreviewRequests removeObject:skinID];
            if (image && [self->_skinsGameIdentifier isEqualToString:game]) {
                self->_skinPreviews[skinID] = image;
                if (self->_screen == FFAppScreenMain && self->_selectedTab == FFMainTabSkins) {
                    [self rebuildInterface];
                }
            }
        });
    });
}

- (UIView *)skinCardForRow:(NSDictionary *)skin activeID:(NSString *)activeID {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 9;
    NSString *skinID = skin[@"id"];
    UIImageView *preview = [UIImageView new];
    preview.contentMode = UIViewContentModeScaleAspectFill;
    preview.clipsToBounds = YES;
    preview.layer.cornerRadius = 12;
    preview.layer.cornerCurve = kCACornerCurveContinuous;
    preview.backgroundColor = [FFVIPGold() colorWithAlphaComponent:0.12];
    preview.image = _skinPreviews[skinID];
    [preview.heightAnchor constraintEqualToConstant:142].active = YES;
    [stack addArrangedSubview:preview];
    if (!preview.image) [self loadSkinPreviewForRow:skin];

    [stack addArrangedSubview:[self labelWithText:skin[@"name"] ?: skinID
        font:[UIFont systemFontOfSize:18 weight:UIFontWeightHeavy] color:UIColor.blackColor]];
    NSString *details = [NSString stringWithFormat:@"%@  •  %@ KB", skin[@"character"] ?: @"MOD SKINS",
        @([skin[@"payload_size"] integerValue] / 1024)];
    [stack addArrangedSubview:[self labelWithText:details
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold] color:FFStatusCyan()]];
    BOOL active = [activeID isEqualToString:skinID];
    UILabel *state = [self labelWithText:active ? @"ACTIVE ✓" : @"READY TO DOWNLOAD"
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold]
        color:active ? UIColor.systemGreenColor : UIColor.secondaryLabelColor];
    [stack addArrangedSubview:state];
    UIButton *activate = [self actionButton:active ? @"ACTIVE SKIN" : @"ACTIVATE"
        color:active ? UIColor.systemGreenColor : FFVIPGold() selector:@selector(activateSkin:)];
    activate.accessibilityIdentifier = skinID;
    BOOL available = !_busy && !_skinOperationInProgress && _licensed &&
        [_allowedFeatures containsObject:@"MOD_SKINS"] && [_serverAvailableFeatures containsObject:@"MOD_SKINS"];
    activate.enabled = available && !active;
    activate.alpha = activate.enabled ? 1.0 : 0.48;
    [stack addArrangedSubview:activate];
    return [self cardWithContent:stack];
}

- (void)buildSkinsContent {
    [self addConsoleHeader:@"MOD SKINS"
        subtitle:@"Browse server-hosted skins. Only the selected skin is downloaded and applied."
        toStack:_rootStack];
    [self addLogoutChangeKeyButtonToStack:_rootStack];
    if (!FFGameDefinition(_selectedGameIdentifier)) {
        [_rootStack addArrangedSubview:[self cardWithContent:[self labelWithText:
            @"SELECT A GAME FIRST\nChoose FREE FIRE TH or FREE FIRE MAX from the GAME tab."
            font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody] color:UIColor.secondaryLabelColor]]];
        return;
    }
    if (![_allowedFeatures containsObject:@"MOD_SKINS"]) {
        [_rootStack addArrangedSubview:[self cardWithContent:[self labelWithText:
            @"MOD SKINS IS NOT ENABLED FOR THIS LICENSE."
            font:[UIFont systemFontOfSize:14 weight:UIFontWeightBold] color:UIColor.systemRedColor]]];
        return;
    }
    if (![_serverAvailableFeatures containsObject:@"MOD_SKINS"]) {
        [_rootStack addArrangedSubview:[self cardWithContent:[self labelWithText:
            @"MOD SKINS CATALOG IS TEMPORARILY UNAVAILABLE."
            font:[UIFont systemFontOfSize:14 weight:UIFontWeightBold] color:UIColor.secondaryLabelColor]]];
        return;
    }

    _skinSearchField = [UITextField new];
    _skinSearchField.placeholder = @"Search Alok, Dimitri, Skin 01…";
    _skinSearchField.text = _skinSearchQuery ?: @"";
    _skinSearchField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _skinSearchField.textColor = UIColor.blackColor;
    _skinSearchField.tintColor = FFVIPGold();
    _skinSearchField.backgroundColor = [UIColor colorWithRed:0.90 green:0.90 blue:0.90 alpha:1.0];
    _skinSearchField.layer.cornerRadius = 13;
    _skinSearchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    _skinSearchField.leftViewMode = UITextFieldViewModeAlways;
    _skinSearchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _skinSearchField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [_skinSearchField.heightAnchor constraintEqualToConstant:48].active = YES;
    [_skinSearchField addTarget:self action:@selector(skinSearchChanged:)
               forControlEvents:UIControlEventEditingChanged];
    [_rootStack addArrangedSubview:_skinSearchField];

    _skinProgressLabel = [self labelWithText:_skinStatus ?: @"LOADING MOD SKINS…"
        font:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
        color:_statusIsError ? UIColor.systemRedColor : FFStatusCyan()];
    [_rootStack addArrangedSubview:_skinProgressLabel];

    NSDictionary *activeState = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey:FFModSkinDefaultsKey(_selectedGameIdentifier)];
    NSString *activeID = [activeState[@"id"] isKindOfClass:NSString.class] ? activeState[@"id"] : nil;
    _filteredSkins = [self filteredSkinRows];
    if (!_skinsLoading && _skins.count && !_filteredSkins.count) {
        [_rootStack addArrangedSubview:[self labelWithText:@"NO SKINS MATCH YOUR SEARCH."
            font:[UIFont systemFontOfSize:14 weight:UIFontWeightBold] color:UIColor.secondaryLabelColor]];
    }
    for (NSDictionary *skin in _filteredSkins) {
        [_rootStack addArrangedSubview:[self skinCardForRow:skin activeID:activeID]];
    }
    if (activeID.length) {
        _restoreSkinButton = [self actionButton:@"RESTORE ORIGINAL SKIN"
            color:UIColor.systemRedColor selector:@selector(restoreActiveSkin)];
        _restoreSkinButton.enabled = !_busy && !_skinOperationInProgress;
        _restoreSkinButton.alpha = _restoreSkinButton.enabled ? 1.0 : 0.48;
        [_rootStack addArrangedSubview:_restoreSkinButton];
    }
    [self loadModSkinsIfNeeded];
}

- (void)skinSearchChanged:(UITextField *)field {
    _skinSearchQuery = field.text ?: @"";
    [self rebuildInterface];
}

- (void)loadModSkinsIfNeeded {
#ifdef FF_OFFLINE_BUILD
    return;
#endif
    NSString *game = _selectedGameIdentifier;
    if (!FFGameDefinition(game) || _skinsLoading ||
        ![_allowedFeatures containsObject:@"MOD_SKINS"] ||
        ![_serverAvailableFeatures containsObject:@"MOD_SKINS"]) return;
    if ([_skinsGameIdentifier isEqualToString:game] && _skins.count) return;
    NSString *token = _activationToken;
    if (!token.length) return;
    _skinsLoading = YES;
    _skinStatus = @"LOADING SKINS FROM SERVER…";
    ZXSkinCatalog(game, token, ^(NSArray<NSDictionary *> *skins, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self->_selectedGameIdentifier isEqualToString:game]) return;
            self->_skinsLoading = NO;
            if (error) {
                self->_skins = @[];
                self->_filteredSkins = @[];
                self->_skinStatus = error.localizedDescription ?: @"MOD SKINS CATALOG FAILED.";
                self->_statusIsError = YES;
            } else {
                self->_skins = skins;
                self->_skinsGameIdentifier = game;
                self->_skinStatus = [NSString stringWithFormat:@"%lu VERIFIED SKINS READY", (unsigned long)skins.count];
                self->_statusIsError = NO;
            }
            if (self->_screen == FFAppScreenMain && self->_selectedTab == FFMainTabSkins) [self rebuildInterface];
        });
    });
}

- (void)activateSkin:(UIButton *)sender {
    NSString *skinID = sender.accessibilityIdentifier;
    NSDictionary *skin = nil;
    for (NSDictionary *candidate in _skins ?: @[]) {
        if ([candidate[@"id"] isEqualToString:skinID]) {
            skin = candidate;
            break;
        }
    }
    NSString *game = _selectedGameIdentifier;
    if (_busy || _skinOperationInProgress || !skin || !FFGameDefinition(game) ||
        ![_allowedFeatures containsObject:@"MOD_SKINS"] ||
        ![_serverAvailableFeatures containsObject:@"MOD_SKINS"]) return;
    _skinOperationInProgress = YES;
    [self setBusy:YES];
    _skinStatus = [NSString stringWithFormat:@"AUTHORIZING %@…", skin[@"name"]];
    [self rebuildInterface];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        if (sessionError) {
            self->_skinOperationInProgress = NO;
            [self setBusy:NO];
            self->_skinStatus = sessionError.localizedDescription;
            self->_statusIsError = YES;
            [self rebuildInterface];
            return;
        }
        ZXGrant(@"MOD_SKINS", game, accessToken, ^(NSString *featureToken, NSString *profileHash, NSError *grantError) {
            (void)profileHash;
            if (grantError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_skinOperationInProgress = NO;
                    [self setBusy:NO];
                    self->_skinStatus = grantError.localizedDescription;
                    self->_statusIsError = YES;
                    [self rebuildInterface];
                });
                return;
            }
            ZXSkinDownload(skin, game, accessToken, featureToken, ^(int64_t received, int64_t expected) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!self->_skinOperationInProgress) return;
                    if (expected > 0) {
                        self->_skinStatus = [NSString stringWithFormat:@"DOWNLOADING %@… %lld%%", skin[@"name"],
                            (long long)MIN(100, (received * 100) / expected)];
                    } else {
                        unsigned long long downloadedKB = received > 0 ? (unsigned long long)received / 1024ULL : 0ULL;
                        self->_skinStatus = [NSString stringWithFormat:@"DOWNLOADING %@… %llu KB", skin[@"name"], downloadedKB];
                    }
                    self->_skinProgressLabel.text = self->_skinStatus;
                });
            }, ^(NSData *data, NSError *downloadError) {
                if (downloadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_skinOperationInProgress = NO;
                        [self setBusy:NO];
                        self->_skinStatus = downloadError.localizedDescription;
                        self->_statusIsError = YES;
                        [self rebuildInterface];
                    });
                    return;
                }
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSError *installError = nil;
                    NSString *targetPath = nil;
                    BOOL installed = FFInstallSkinData(data, game, skin[@"target_filename"], &targetPath, &installError);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_skinOperationInProgress = NO;
                        [self setBusy:NO];
                        if (!installed) {
                            self->_skinStatus = installError.localizedDescription ?: @"MOD SKINS activation failed.";
                            self->_statusIsError = YES;
                        } else {
                            NSString *key = FFModSkinDefaultsKey(game);
                            if (key) [[NSUserDefaults standardUserDefaults] setObject:@{
                                @"id": skin[@"id"] ?: @"", @"target_filename": skin[@"target_filename"] ?: @"",
                                @"sha256": skin[@"payload_sha256"] ?: @"", @"path": targetPath ?: @"",
                                @"applied_at": @([NSDate date].timeIntervalSince1970),
                            } forKey:key];
                            self->_skinStatus = [NSString stringWithFormat:@"%@ ACTIVE ✓", skin[@"name"]];
                            self->_statusIsError = NO;
                        }
                        [self rebuildInterface];
                    });
                });
            });
        });
    }];
}

- (void)restoreActiveSkin {
    NSString *game = _selectedGameIdentifier;
    NSDictionary *state = [[NSUserDefaults standardUserDefaults] dictionaryForKey:FFModSkinDefaultsKey(game)];
    NSString *target = [state[@"target_filename"] isKindOfClass:NSString.class] ? state[@"target_filename"] : nil;
    if (_busy || _skinOperationInProgress || !FFGameDefinition(game) || !FFSkinFilenameIsSafe(target)) {
        _skinStatus = @"NO RESTORABLE MOD SKIN STATE WAS FOUND.";
        _statusIsError = YES;
        [self rebuildInterface];
        return;
    }
    _skinOperationInProgress = YES;
    [self setBusy:YES];
    _skinStatus = @"RESTORING ORIGINAL SKIN…";
    [self rebuildInterface];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSString *path = nil;
        BOOL restored = FFRestoreSkinData(game, target, &path, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_skinOperationInProgress = NO;
            [self setBusy:NO];
            if (!restored) {
                self->_skinStatus = error.localizedDescription ?: @"Original skin restore failed.";
                self->_statusIsError = YES;
            } else {
                NSString *key = FFModSkinDefaultsKey(game);
                if (key) [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
                self->_skinStatus = @"ORIGINAL SKIN RESTORED ✓";
                self->_statusIsError = NO;
            }
            [self rebuildInterface];
        });
    });
}

- (NSString *)formattedEpoch:(id)value {
    if (![value respondsToSelector:@selector(doubleValue)] || [value doubleValue] <= 0) return @"—";
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[value doubleValue]]];
}

- (UIView *)statusSection:(NSString *)title rows:(NSArray<UIView *> *)rows {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    [stack addArrangedSubview:[self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold] color:FFVIPGold()]];
    for (UIView *row in rows) [stack addArrangedSubview:row];
    return [self cardWithContent:stack];
}

- (void)buildStatusContent {
    [self addConsoleHeader:@"SYSTEM STATUS"
        subtitle:@"Only server and secure-session values are shown." toStack:_rootStack];
    [self addLogoutChangeKeyButtonToStack:_rootStack];
    NSString *used = [_licenseSnapshot[@"devices_used"] stringValue] ?: @"—";
    NSString *maximum = [_licenseSnapshot[@"max_devices"] stringValue] ?: @"—";
    [_rootStack addArrangedSubview:[self statusSection:@"LICENSE" rows:@[
        [self informationRow:@"STATUS" value:_licenseSnapshot[@"status"] ?: (_licensed ? @"ACTIVE" : @"INACTIVE")],
        [self informationRow:@"PLAN" value:_licenseSnapshot[@"plan"] ?: @"—"],
        [self informationRow:@"EXPIRES" value:[self formattedEpoch:_licenseSnapshot[@"expires_at"]]],
        [self informationRow:@"DEVICE LIMIT" value:[NSString stringWithFormat:@"%@ / %@", used, maximum]],
    ]]];
    NSString *slot = [_deviceSnapshot[@"slot"] stringValue] ?: @"—";
    [_rootStack addArrangedSubview:[self statusSection:@"DEVICE" rows:@[
        [self informationRow:@"REGISTERED" value:
            [_deviceSnapshot[@"status"] isEqualToString:@"ACTIVE"] ? @"YES" : @"NO"],
        [self informationRow:@"DEVICE SLOT" value:slot],
        [self informationRow:@"INSTALLATION STATUS" value:_gameInstalled ? @"GAME FOUND" : @"NOT VERIFIED"],
    ]]];
    NSDateFormatter *validationFormatter = [NSDateFormatter new];
    validationFormatter.dateStyle = NSDateFormatterMediumStyle;
    validationFormatter.timeStyle = NSDateFormatterMediumStyle;
    [_rootStack addArrangedSubview:[self statusSection:@"SESSION" rows:@[
        [self informationRow:@"STATUS" value:_licensed ? @"ACTIVE" : @"EXPIRED"],
        [self informationRow:@"LAST VALIDATION" value:
            _lastValidationDate ? [validationFormatter stringFromDate:_lastValidationDate] : @"—"],
    ]]];
    NSOperatingSystemVersion os = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *osVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)os.majorVersion,
        (long)os.minorVersion, (long)os.patchVersion];
    [_rootStack addArrangedSubview:[self statusSection:@"ACCESS COMPATIBILITY" rows:@[
        [self informationRow:@"iOS" value:osVersion],
        [self informationRow:@"ROUTING" value:@"CAPABILITY-BASED"],
        [self informationRow:@"ACCESS METHOD" value:FFAccessMethodName(_accessMethod)],
        [self informationRow:@"FILESYSTEM" value:_gameInstalled ? @"VERIFIED / READY" : @"NOT VERIFIED"],
    ]]];
    BOOL live = [_serverSnapshot[@"success"] boolValue];
    BOOL maintenance = [_serverSnapshot[@"maintenance"] boolValue];
    [_rootStack addArrangedSubview:[self statusSection:@"SERVER" rows:@[
        [self informationRow:@"STATUS" value:live ? @"ONLINE" : @"UNAVAILABLE"],
        [self informationRow:@"APP VERSION STATUS" value:_licensed ? @"ACCEPTED" : @"NOT VALIDATED"],
        [self informationRow:@"MAINTENANCE STATUS" value:maintenance ? @"ACTIVE" : @"NORMAL"],
    ]]];
}

- (void)rebuildInterface {
    NSString *pendingLicense = _licenseField.text;
    [_rootScroll removeFromSuperview];
    [_tabControl removeFromSuperview];
    _rootScroll = nil;
    _rootStack = nil;
    _tabControl = nil;
    _licenseField = nil;
    _licenseButton = nil;
    _channelStatusLabel = nil;
    _channelJoinButton = nil;
    _channelBotButton = nil;
    _channelVerifyButton = nil;
    _channelCopyButton = nil;
    _folderButton = nil;
    _compatibilityFolderButton = nil;
    _continueButton = nil;
    _applyButton = nil;
    _runButton = nil;
    _logoutButton = nil;
    _restoreButton = nil;
    _restoreSkinButton = nil;
    _skinProgressLabel = nil;
    _skinSearchField = nil;
    _featureButtons = @[];
    _featureRows = @[];
    _statusLabel = nil;
    _activeLabel = nil;

    _rootScroll = [UIScrollView new];
    _rootScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _rootScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(dismissKeyboard)];
    dismissTap.cancelsTouchesInView = NO;
    [_rootScroll addGestureRecognizer:dismissTap];
    [self.view addSubview:_rootScroll];

    NSLayoutYAxisAnchor *bottomAnchor = self.view.bottomAnchor;
    if (_screen == FFAppScreenMain) {
        _tabControl = [[UISegmentedControl alloc] initWithItems:@[@"GAME", @"CONTROL", @"MOD SKINS", @"STATUS"]];
        _tabControl.selectedSegmentIndex = _selectedTab;
        _tabControl.selectedSegmentTintColor = FFVIPGold();
        _tabControl.translatesAutoresizingMaskIntoConstraints = NO;
        [_tabControl addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:_tabControl];
        [NSLayoutConstraint activateConstraints:@[
            [_tabControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
            [_tabControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
            [_tabControl.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
            [_tabControl.heightAnchor constraintEqualToConstant:42],
        ]];
        bottomAnchor = _tabControl.topAnchor;
    }
    [NSLayoutConstraint activateConstraints:@[
        [_rootScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_rootScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_rootScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_rootScroll.bottomAnchor constraintEqualToAnchor:bottomAnchor
            constant:_screen == FFAppScreenMain ? -10 : 0],
    ]];

    _rootStack = [UIStackView new];
    _rootStack.axis = UILayoutConstraintAxisVertical;
    _rootStack.spacing = 14;
    _rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_rootScroll addSubview:_rootStack];
    [NSLayoutConstraint activateConstraints:@[
        [_rootStack.leadingAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.leadingAnchor constant:16],
        [_rootStack.trailingAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.trailingAnchor constant:-16],
        [_rootStack.topAnchor constraintEqualToAnchor:_rootScroll.contentLayoutGuide.topAnchor constant:18],
        [_rootStack.bottomAnchor constraintEqualToAnchor:_rootScroll.contentLayoutGuide.bottomAnchor constant:-28],
        [_rootStack.widthAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    if (_screen == FFAppScreenAccess) {
        [self buildAccessContent];
        _licenseField.text = pendingLicense ?: @"";
    } else if (_screen == FFAppScreenChannelGate) {
        [self buildChannelGateContent];
    } else if (_screen == FFAppScreenGameSelection) {
        [self buildGameSelectionContent:NO];
    } else if (_selectedTab == FFMainTabGame) {
        [self buildGameSelectionContent:YES];
    } else if (_selectedTab == FFMainTabSkins) {
        [self buildSkinsContent];
    } else if (_selectedTab == FFMainTabStatus) {
        [self buildStatusContent];
    } else {
        [self buildControlContent];
    }
    [self setBusy:_busy];
}

- (void)selectGameCard:(UIButton *)sender {
    if (_busy || !_licensed || sender.tag < 0 ||
        sender.tag >= (NSInteger)FFSupportedGames().count) return;
    NSString *newGame = FFSupportedGames()[(NSUInteger)sender.tag][@"bundleIdentifier"];
    if (!FFGameDefinition(newGame)) return;
    if (![_selectedGameIdentifier isEqualToString:newGame]) {
        _selectedGameIdentifier = newGame;
        _connectedGameIdentifier = nil;
        _selectedFeature = nil;
        _operationFeature = nil;
        _serverAvailableFeatures = [NSSet set];
        _accessContext = nil;
        _accessMethod = FFAccessMethodNone;
        _gameInstalled = NO;
        _readyToRun = NO;
        _skins = nil;
        _filteredSkins = nil;
        _skinsGameIdentifier = nil;
        [_skinPreviews removeAllObjects];
        [_skinPreviewRequests removeAllObjects];
        _skinSearchQuery = nil;
        _skinStatus = @"SELECT A GAME TO LOAD MOD SKINS";
        _activeText = @"—";
        _statusText = @"GAME SELECTED — CONTINUE TO VERIFY";
        _statusIsError = NO;
    }
    [self rebuildInterface];
}

- (void)continueWithSelectedGame {
    if (_busy || !_licensed || !FFGameDefinition(_selectedGameIdentifier)) return;
    _screen = FFAppScreenMain;
    _selectedTab = FFMainTabControl;
    // Optimistic local feature set: the grid renders instantly with every
    // local feature shown, then the signed server catalog refines the list.
    NSSet<NSString *> *local = FFLocalFeaturesForGame(_selectedGameIdentifier);
    _allowedFeatures = local;
    _serverAvailableFeatures = local;
    _statusText = @"FEATURES READY — SYNCING…";
    _statusIsError = NO;
    [self rebuildInterface];
    [self loadFeatureCatalogForSelectedGame];
}

- (void)tabChanged:(UISegmentedControl *)control {
    if (_busy) {
        control.selectedSegmentIndex = _selectedTab;
        return;
    }
    _selectedTab = (FFMainTab)control.selectedSegmentIndex;
    [self rebuildInterface];
}

- (void)fetchServerStatus {
#ifdef FF_OFFLINE_BUILD
    _serverSnapshot = nil;
    return;
#endif
    FFFetchServiceStatus(^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_serverSnapshot = error ? nil : response;
            if (self->_screen != FFAppScreenMain || self->_selectedTab == FFMainTabStatus) {
                [self rebuildInterface];
            }
        });
    });
}

- (void)loadFeatureCatalogForSelectedGame {
    NSString *game = _selectedGameIdentifier;
#ifdef FF_OFFLINE_BUILD
    if (!FFGameDefinition(game)) return;
    NSMutableSet<NSString *> *available = [FFBundledOfflineFeatures() mutableCopy];
    [available intersectSet:FFLocalFeaturesForGame(game)];
    _allowedFeatures = available.copy;
    _serverAvailableFeatures = available.copy;
    [self setBusy:NO];
    [self rebuildInterface];
    return;
#endif
    NSString *token = _activationToken;
    if (!FFGameDefinition(game) || !token.length) return;
    FFFetchFeatureCatalog(game, token, ^(NSSet<NSString *> *planFeatures,
                                         NSSet<NSString *> *serverFeatures, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self->_selectedGameIdentifier isEqualToString:game]) return;
            if (error) {
                if (FFIsChannelVerificationError(error)) {
                    [self presentChannelGateWithMessage:error.localizedDescription];
                    return;
                }
                // Keep the optimistic local feature set visible instead of
                // wiping the grid when the catalog sync fails.
                self->_allowedFeatures = FFLocalFeaturesForGame(game);
                self->_serverAvailableFeatures = FFLocalFeaturesForGame(game);
                [self setBusy:NO];
                [self setStatus:error.localizedDescription path:nil active:nil error:YES];
                [self rebuildInterface];
                return;
            }
            self->_allowedFeatures = planFeatures ?: [NSSet set];
            self->_serverAvailableFeatures = serverFeatures ?: [NSSet set];
            [self setBusy:NO];
            [self rebuildInterface];
            // The filesystem access check is deliberately lazy: it runs only
            // when the user applies a feature or runs the game, and its result
            // is cached so it never blocks or repeats on its own.
        });
    });
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    _licenseField.enabled = !busy;
    _licenseButton.enabled = !busy;
    _channelJoinButton.enabled = !busy;
    _channelBotButton.enabled = !busy;
    _channelVerifyButton.enabled = !busy;
    _channelCopyButton.enabled = !busy;
    _continueButton.enabled = !busy && _selectedGameIdentifier.length > 0;
    _continueButton.alpha = _continueButton.enabled ? 1.0 : 0.42;
    _tabControl.enabled = !busy;
    _logoutButton.enabled = !busy && _licensed;
    _logoutButton.alpha = _logoutButton.enabled ? 1.0 : 0.42;
    _restoreButton.enabled = !busy && _licensed && _selectedGameIdentifier.length > 0;
    _restoreButton.alpha = _restoreButton.enabled ? 1.0 : 0.42;
    _compatibilityFolderButton.enabled = !busy && _licensed && _selectedGameIdentifier.length > 0;
    _compatibilityFolderButton.alpha = _compatibilityFolderButton.enabled ? 1.0 : 0.42;
    _runButton.enabled = !busy && _readyToRun && _gameInstalled;
    for (UIButton *button in _featureButtons) {
        NSInteger index = button.tag;
        NSString *feature = index >= 0 && index < (NSInteger)_features.count
            ? _features[(NSUInteger)index] : nil;
        BOOL allowed = feature && [_allowedFeatures containsObject:feature] &&
            [_serverAvailableFeatures containsObject:feature] &&
            [FFLocalFeaturesForGame(_selectedGameIdentifier) containsObject:feature];
        button.enabled = !busy && _licensed && allowed;
        button.alpha = button.enabled ? 1.0 : 0.56;
    }
    BOOL canApply = !busy && _licensed && _selectedFeature.length &&
        [_allowedFeatures containsObject:_selectedFeature] &&
        [_serverAvailableFeatures containsObject:_selectedFeature];
    _applyButton.enabled = canApply;
    _applyButton.alpha = canApply ? 1.0 : 0.42;
    self.navigationItem.hidesBackButton = busy;
}

- (void)updateGameRouting:(NSString *)gameIdentifier {
    if (gameIdentifier.length && ![gameIdentifier isEqualToString:_selectedGameIdentifier]) {
        _connectedGameIdentifier = nil;
        _gameInstalled = NO;
        [self setStatus:@"GAME ROUTING MISMATCH" path:nil active:nil error:YES];
        return;
    }
    BOOL verified = gameIdentifier.length > 0 && _accessContext.usable &&
        [_accessContext.gameIdentifier isEqualToString:gameIdentifier];
    _connectedGameIdentifier = verified ? gameIdentifier : nil;
    _gameInstalled = verified;
    FFDiagnosticLog(@"Compatibility", @"CONNECTED: %@", verified ? @"YES" : @"NO");
    [self setBusy:_busy];
}

- (void)setStatus:(NSString *)status path:(NSString *)path active:(NSString *)active error:(BOOL)isError {
    (void)path;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusText = status ?: @"";
        self->_statusIsError = isError;
        self->_statusLabel.text = self->_statusText;
        self->_statusLabel.textColor = isError ? UIColor.systemRedColor : UIColor.labelColor;
        if (active) {
            self->_activeText = active;
            self->_activeLabel.text = [NSString stringWithFormat:@"ACTIVE: %@", active];
        }
    });
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)pasteLicenseKeyPressed {
    NSString *raw = UIPasteboard.generalPasteboard.string;
    if (![raw isKindOfClass:NSString.class] || !raw.length) {
        [self setStatus:@"CLIPBOARD IS EMPTY — COPY YOUR KEY FIRST" path:nil active:nil error:YES];
        return;
    }
    NSString *trimmed = [[raw stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    _licenseField.text = trimmed;
    [self setStatus:@"KEY PASTED — TAP ACTIVATE VIP" path:nil active:nil error:NO];
}

- (void)connectServerPressed {
    [self dismissKeyboard];
    [self setStatus:@"CONNECTING TO SERVER…" path:nil active:nil error:NO];
    FFFetchServiceStatus(^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self->_serverSnapshot = nil;
                [self setStatus:error.localizedDescription path:nil active:nil error:YES];
            } else {
                self->_serverSnapshot = response;
                [self setStatus:@"SERVER CONNECTED ✓ — READY" path:nil active:nil error:NO];
            }
            if (self->_screen != FFAppScreenMain || self->_selectedTab == FFMainTabStatus) {
                [self rebuildInterface];
            }
        });
    });
}

- (void)activateLicensePressed {
    [self dismissKeyboard];
    if (_busy) return;
    [self activateLicenseValue:_licenseField.text ?: @""];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self restoreExpiredHologramIfNeeded];
    [self enforceNearExpiryRestoreIfNeeded];
    if (_screen == FFAppScreenChannelGate) {
        if (!_busy && !_channelStatusChecking) [self checkChannelVerification];
        return;
    }
    if (_screen != FFAppScreenAccess || _busy || _licensed) return;
    _clipboardActivationAttempted = NO;
    [self activateClipboardLicenseIfAvailable];
}

- (void)restoreExpiredHologramIfNeeded {
    if (_hologramRestoreInProgress) return;
    NSDictionary *state = [NSUserDefaults.standardUserDefaults dictionaryForKey:FFHologramStateKey];
    NSNumber *expires = [state[@"expires_at"] isKindOfClass:NSNumber.class] ? state[@"expires_at"] : nil;
    if (!expires || expires.doubleValue > NSDate.date.timeIntervalSince1970) return;
    _hologramRestoreInProgress = YES;
    [self setStatus:@"HOLOGRAM_EXPIRED — RESTORING ORIGINAL…" path:nil active:nil error:NO];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        NSString *game = nil;
        NSString *path = nil;
        BOOL needed = NO;
        BOOL restored = FFRestoreExpiredHologram(&needed, &game, &path, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_hologramRestoreInProgress = NO;
            if (!needed) return;
            if (!restored) {
                [self setStatus:error.localizedDescription ?: @"RESTORE_FAILED: expired Hologram state retained."
                    path:path active:nil error:YES];
                return;
            }
            if ([self->_selectedGameIdentifier isEqualToString:game]) self->_readyToRun = NO;
            [self setStatus:@"RESTORE_SUCCESS — EXPIRED HOLOGRAM RESTORED"
                path:path active:@"ORIGINAL" error:NO];
            [self rebuildInterface];
        });
    });
}

- (void)enforceNearExpiryRestoreIfNeeded {
    if (_nearExpiryRestoreInProgress || _busy) return;
    NSNumber *expires = [[NSUserDefaults standardUserDefaults] objectForKey:FFKnownLicenseExpiryKey];
    if (![expires respondsToSelector:@selector(doubleValue)] || expires.doubleValue <= 0) return;
    NSTimeInterval remaining = expires.doubleValue - NSDate.date.timeIntervalSince1970;
    if (remaining > 2.0 * 86400.0) return;
    _nearExpiryRestoreInProgress = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSString *> *restored = [NSMutableArray array];
        for (NSDictionary *game in FFSupportedGames()) {
            NSString *identifier = game[@"bundleIdentifier"];
            if (!identifier.length) continue;
            NSError *error = nil;
            NSString *path = nil;
            // All calls below restore only an existing .ffbackup sidecar. They
            // never delete a game file and never create a new target.
            if ([FFFeatureManager restoreOriginalForGame:identifier accessMethod:FFAccessMethodDirect
                                              targetPath:&path error:&error]) {
                [restored addObject:[NSString stringWithFormat:@"%@ cache", game[@"displayName"]]];
            }
            error = nil;
            if (FFRestoreDirectAsset(identifier, FFHologramShaderFilename, @"Hologram shader", &path, &error)) {
                [restored addObject:[NSString stringWithFormat:@"%@ Hologram", game[@"displayName"]]];
            }
            error = nil;
            if (FFRestoreDirectAsset(identifier, FFThreeDShaderFilename, @"3D shader", &path, &error)) {
                [restored addObject:[NSString stringWithFormat:@"%@ 3D", game[@"displayName"]]];
            }
            NSDictionary *skin = [[NSUserDefaults standardUserDefaults]
                dictionaryForKey:FFModSkinDefaultsKey(identifier)];
            NSString *target = [skin[@"target_filename"] isKindOfClass:NSString.class]
                ? skin[@"target_filename"] : nil;
            error = nil;
            if (FFSkinFilenameIsSafe(target) && FFRestoreSkinData(identifier, target, &path, &error)) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:FFModSkinDefaultsKey(identifier)];
                [restored addObject:[NSString stringWithFormat:@"%@ skin", game[@"displayName"]]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_nearExpiryRestoreInProgress = NO;
            if (!restored.count) return;
            NSString *message = [NSString stringWithFormat:@"LICENSE EXPIRING — CLEAN FILES RESTORED (%@)",
                [restored componentsJoinedByString:@", "]];
            self->_statusText = message;
            self->_skinStatus = message;
            self->_statusIsError = NO;
            if (self->_screen == FFAppScreenMain) [self rebuildInterface];
        });
    });
}

- (void)applyServerShader:(NSString *)feature {
    if (_busy || !_licensed || !_activationToken.length) return;
    NSString *game = _selectedGameIdentifier;
    if (![game isEqualToString:FFBundleIDFreeFireTH]) {
        [self setStatus:@"SHADER AVAILABLE FOR FREE FIRE TH ONLY" path:nil active:nil error:YES];
        return;
    }
    BOOL gun = [feature isEqualToString:@"HOLOGRAM_GUN"];
    [self setBusy:YES];
    [self setStatus:gun ? @"AUTHORIZING HOLOGRAM GUN SHADER…" : @"AUTHORIZING SKIN HOLO SHADER…"
        path:nil active:nil error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        if (sessionError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setBusy:NO];
                [self setStatus:sessionError.localizedDescription path:nil active:nil error:YES];
                [self rebuildInterface];
            });
            return;
        }
        ZXGrant(feature, game, accessToken, ^(NSString *featureToken, NSString *profileHash, NSError *grantError) {
            if (grantError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setBusy:NO];
                    [self setStatus:grantError.localizedDescription path:nil active:nil error:YES];
                    [self rebuildInterface];
                });
                return;
            }
            void (^fetchAndInstall)(NSString *color, NSString *expectedHash) = ^(NSString *color, NSString *expectedHash) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setStatus:gun ? @"DOWNLOADING HOLOGRAM GUN SHADER…" : @"DOWNLOADING SKIN HOLO SHADER…"
                        path:nil active:nil error:NO];
                });
                ZXFetch(feature, game, color, expectedHash, accessToken, featureToken,
                    ^(NSData *shaderData, NSError *downloadError) {
                    if (downloadError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setBusy:NO];
                            [self setStatus:downloadError.localizedDescription path:nil active:nil error:YES];
                            [self rebuildInterface];
                        });
                        return;
                    }
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                        NSError *error = nil;
                        NSString *path = nil;
                        BOOL installed = FFInstallServerShaderData(shaderData, gun ? @"GUN" : @"SKIN",
                            game, &path, &error);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setBusy:NO];
                            if (installed) {
                                NSString *label = gun ? @"HOLOGRAM GUN" : @"SKIN HOLO";
                                [self setStatus:[NSString stringWithFormat:@"%@ ACTIVE — ORIGINAL RESTORES IN 1 MINUTE", label]
                                    path:path active:feature error:NO];
                            } else {
                                [self setStatus:error.localizedDescription ?: @"SHADER INSTALL FAILED"
                                    path:nil active:nil error:YES];
                            }
                            [self rebuildInterface];
                        });
                    });
                });
            };
            if (gun) {
                // Single server catalog entry: auto-select it, no color picker.
                ZXFeatureColors(@"HOLOGRAM_GUN", game, accessToken,
                    ^(NSArray<NSDictionary *> *colors, NSError *colorError) {
                    if (colorError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setBusy:NO];
                            [self setStatus:colorError.localizedDescription path:nil active:nil error:YES];
                            [self rebuildInterface];
                        });
                        return;
                    }
                    NSDictionary *selected = colors.firstObject;
                    if (![selected[@"name"] isKindOfClass:NSString.class] ||
                        ![selected[@"sha256"] isKindOfClass:NSString.class]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setBusy:NO];
                            [self setStatus:@"NO HOLOGRAM SHADER AVAILABLE ON THE SERVER"
                                path:nil active:nil error:YES];
                            [self rebuildInterface];
                        });
                        return;
                    }
                    fetchAndInstall(selected[@"name"], selected[@"sha256"]);
                });
            } else {
                fetchAndInstall(nil, profileHash);
            }
        });
    }];
}

- (void)enforceShaderAutoRevertIfNeeded {
    if (_nearExpiryRestoreInProgress || _busy) return;
    BOOL needed = NO;
    FFRestoreExpiredShader(&needed, NULL, NULL);
    if (!needed) return;
    _nearExpiryRestoreInProgress = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        NSString *path = nil;
        FFRestoreExpiredShader(NULL, &path, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_nearExpiryRestoreInProgress = NO;
            NSString *message = error ? @"SHADER AUTO-REVERT FAILED — RETRYING"
                                      : @"ORIGINAL FILE RESTORED AUTOMATICALLY";
            [self setStatus:message path:path active:@"ORIGINAL" error:error != nil];
            if (self->_screen == FFAppScreenMain) [self rebuildInterface];
        });
    });
}

- (void)activateClipboardLicenseIfAvailable {
    if (_clipboardActivationAttempted || _busy || _licensed ||
        _screen != FFAppScreenAccess) return;
    // Existing session tokens have priority.  restoreSessionIfAvailable will
    // rebuild the Access screen after a failed refresh, at which point this
    // clipboard flow can safely run without racing a valid saved session.
    if (FFKeychainRead(FFAccessTokenAccount).length ||
        FFKeychainRead(FFRefreshTokenAccount).length) return;
    NSString *licenseKey = FFClipboardLicenseKey();
    if (!licenseKey.length) return;
    NSString *digest = ZXDigest([licenseKey dataUsingEncoding:NSUTF8StringEncoding]);
    NSString *blockedDigest = [NSUserDefaults.standardUserDefaults
        stringForKey:FFAutoClipboardLicenseDigestKey];
    // Logout must not immediately sign the user back in with the old key that
    // is still on the system clipboard. Copying a different key changes this
    // digest and enables the automatic flow again.
    if (digest.length && [digest isEqualToString:blockedDigest]) return;
    _clipboardActivationAttempted = YES;
    _licenseField.text = licenseKey;
    [self setStatus:@"LICENSE KEY DETECTED — ACTIVATING…" path:nil active:@"—" error:NO];
    [self activateLicenseValue:licenseKey];
}

- (void)logoutChangeKeyPressed {
    if (_busy) return;
    NSString *oldAccessToken = [_activationToken copy] ?: FFKeychainRead(FFAccessTokenAccount);
    NSString *clipboardLicense = FFClipboardLicenseKey();
    if (clipboardLicense.length) {
        NSString *digest = ZXDigest([clipboardLicense dataUsingEncoding:NSUTF8StringEncoding]);
        if (digest.length) [NSUserDefaults.standardUserDefaults setObject:digest
            forKey:FFAutoClipboardLicenseDigestKey];
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FFAutoClipboardLicenseDigestKey];
    }
    ++_sessionGeneration;
    FFClearSession();
    _licensed = NO;
    _activationToken = nil;
    _licenseSnapshot = nil;
    _deviceSnapshot = nil;
    _sessionSnapshot = nil;
    _allowedFeatures = [NSSet set];
    _serverAvailableFeatures = [NSSet set];
    _accessContext = nil;
    _accessMethod = FFAccessMethodNone;
    _pendingAccessCompletion = nil;
    _connectedGameIdentifier = nil;
    _selectedGameIdentifier = nil;
    _selectedFeature = nil;
    _operationFeature = nil;
    _activeText = @"—";
    _statusText = @"LICENSE CLEARED — ENTER A NEW KEY";
    _statusIsError = NO;
    _gameInstalled = NO;
    _readyToRun = NO;
    _usingSelectedFolder = NO;
    _folderPickerPresented = NO;
    _clipboardActivationAttempted = NO;
    _pendingLicenseKey = nil;
    _channelStatusChecking = NO;
    _channelResumeScreen = FFAppScreenAccess;
    _screen = FFAppScreenAccess;
    _selectedTab = FFMainTabControl;
    [self rebuildInterface];
    _licenseField.text = @"";
    _licenseField.enabled = YES;
    [_licenseField becomeFirstResponder];
    FFLogoutSession(oldAccessToken, ^(NSError *error) {
        (void)error; // Local logout is immediate; server revocation is best effort when offline.
    });
}

- (void)activateLicenseValue:(NSString *)licenseKey {
    if (_busy) return;
    NSString *trimmed = [licenseKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        [self setStatus:@"ENTER A NEW LICENSE KEY" path:nil active:@"—" error:YES];
        return;
    }
    NSUInteger generation = ++_sessionGeneration;
    _pendingLicenseKey = trimmed;
    [self setBusy:YES];
    [self setStatus:@"ACTIVATING LICENSE…" path:nil active:nil error:NO];
    FFActivateLicense(trimmed, ^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_sessionGeneration) return;
            if (error) {
                if (FFIsChannelVerificationError(error)) {
                    [self presentChannelGateWithMessage:error.localizedDescription];
                    return;
                }
                self->_pendingLicenseKey = nil;
                self->_licensed = NO;
                self->_activationToken = nil;
                self->_allowedFeatures = [NSSet set];
                self->_serverAvailableFeatures = [NSSet set];
                FFClearSession();
                [self setBusy:NO];
                [self setStatus:error.localizedDescription path:nil active:@"—" error:YES];
                return;
            }
            NSDictionary *session = [response[@"session"] isKindOfClass:NSDictionary.class] ? response[@"session"] : nil;
            if (!session || !ZXPersist(session)) {
                self->_pendingLicenseKey = nil;
                self->_licensed = NO;
                self->_activationToken = nil;
                [self setBusy:NO];
                [self setStatus:@"Could not store the secure session." path:nil active:@"—" error:YES];
                return;
            }
            self->_pendingLicenseKey = nil;
            self->_licenseField.text = @"";
            [NSUserDefaults.standardUserDefaults removeObjectForKey:FFAutoClipboardLicenseDigestKey];
            [self applySessionResponse:response accessToken:session[@"access_token"]];
            self->_serverAvailableFeatures = [NSSet set];
            self->_selectedGameIdentifier = nil;
            self->_selectedFeature = nil;
            self->_readyToRun = NO;
            self->_screen = FFAppScreenGameSelection;
            [self setBusy:NO];
            [self setStatus:@"LICENSE ACTIVE ✓" path:nil active:@"—" error:NO];
            [self rebuildInterface];
        });
    });
}

- (void)applySessionResponse:(NSDictionary *)response accessToken:(NSString *)accessToken {
    NSDictionary *session = [response[@"session"] isKindOfClass:NSDictionary.class] ? response[@"session"] : nil;
    if ([session[@"access_token"] isKindOfClass:NSString.class]) {
        if (!ZXPersist(session)) {
            FFClearSession();
            _licensed = NO;
            _activationToken = nil;
            return;
        }
        accessToken = session[@"access_token"];
    }
    NSDictionary *license = [response[@"license"] isKindOfClass:NSDictionary.class]
        ? response[@"license"] : nil;
    NSDictionary *device = [response[@"device"] isKindOfClass:NSDictionary.class]
        ? response[@"device"] : nil;
    if (license) _licenseSnapshot = license;
    id expiry = license[@"expires_at"];
    if ([expiry respondsToSelector:@selector(doubleValue)] && [expiry doubleValue] > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@([expiry doubleValue]) forKey:FFKnownLicenseExpiryKey];
    } else if (license) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:FFKnownLicenseExpiryKey];
    }
    if (device) _deviceSnapshot = device;
    if (session) _sessionSnapshot = session;
    NSDictionary *features = [response[@"features"] isKindOfClass:NSDictionary.class] ? response[@"features"] : nil;
    if (features) {
        NSMutableSet *allowed = [NSMutableSet set];
        for (NSString *feature in @[@"BODY", @"DRAG", @"NECK", @"CHEST", @"MAGIC", @"HOLOGRAM_GUN", @"THREE_D", @"MOD_SKINS", @"ESP"]) {
            NSString *wireFeature = ZXWireFeature(feature);
            if ([features[wireFeature] boolValue] || [features[feature] boolValue]) [allowed addObject:feature];
        }
        _allowedFeatures = allowed;
    }
    _activationToken = accessToken;
    _licensed = accessToken.length > 0;
    if (_licensed) _lastValidationDate = [NSDate date];
    [self setBusy:_busy];
    [self enforceNearExpiryRestoreIfNeeded];
}

- (void)restoreSessionIfAvailable {
    NSString *accessToken = FFKeychainRead(FFAccessTokenAccount);
    NSString *refreshToken = FFKeychainRead(FFRefreshTokenAccount);
    if (!accessToken.length || !refreshToken.length) return;
    NSUInteger generation = ++_sessionGeneration;
    [self setStatus:@"CHECKING SAVED SESSION…" path:nil active:nil error:NO];
    FFValidateSession(accessToken, ^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_sessionGeneration) return;
            if (!error) {
                [self applySessionResponse:response accessToken:accessToken];
                self->_screen = FFAppScreenGameSelection;
                self->_selectedGameIdentifier = nil;
                self->_serverAvailableFeatures = [NSSet set];
                [self setBusy:NO];
                [self setStatus:@"LICENSE ACTIVE ✓" path:nil active:@"—" error:NO];
                [self rebuildInterface];
                return;
            }
            if (FFIsChannelVerificationError(error)) {
                [self presentChannelGateWithMessage:error.localizedDescription];
                return;
            }
            ZXRenew(^(NSDictionary *refreshResponse, NSError *refreshError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation != self->_sessionGeneration) return;
                    if (refreshError) {
                        if (FFIsChannelVerificationError(refreshError)) {
                            [self presentChannelGateWithMessage:refreshError.localizedDescription];
                            return;
                        }
                        FFClearSession();
                        self->_licensed = NO;
                        self->_activationToken = nil;
                        self->_allowedFeatures = [NSSet set];
                        self->_serverAvailableFeatures = [NSSet set];
                        self->_screen = FFAppScreenAccess;
                        [self setBusy:NO];
                        [self setStatus:@"LICENSE REQUIRED" path:nil active:@"—" error:NO];
                        [self rebuildInterface];
                        return;
                    }
                    [self applySessionResponse:refreshResponse accessToken:nil];
                    self->_screen = FFAppScreenGameSelection;
                    self->_selectedGameIdentifier = nil;
                    self->_serverAvailableFeatures = [NSSet set];
                    [self setBusy:NO];
                    [self setStatus:@"LICENSE ACTIVE ✓" path:nil active:@"—" error:NO];
                    [self rebuildInterface];
                });
            });
        });
    });
}

- (void)refreshSessionForOperation:(void (^)(NSString *accessToken, NSError *error))completion {
#ifdef FF_OFFLINE_BUILD
    _activationToken = @"OFFLINE";
    _licensed = YES;
    completion(_activationToken, nil);
    return;
#endif
    ZXRenew(^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (FFIsChannelVerificationError(error)) {
                    [self presentChannelGateWithMessage:error.localizedDescription];
                    completion(nil, error);
                    return;
                }
                FFClearSession();
                self->_licensed = NO;
                self->_activationToken = nil;
                self->_allowedFeatures = [NSSet set];
                self->_serverAvailableFeatures = [NSSet set];
                completion(nil, error);
                return;
            }
            [self applySessionResponse:response accessToken:nil];
            completion(self->_activationToken, nil);
        });
    });
}

- (void)selectFolder {
    // Folder selection was intentionally removed: modern iOS does not expose
    // another app's private container in Files, so the picker can never
    // authorize the game folder. Direct (kernel/MCM/unsandboxed) access is
    // the only supported path.
    [self setStatus:@"FOLDER SELECTION REMOVED — DIRECT ACCESS ONLY. If access is not ready, wait for the kernel chain and retry."
        path:@"" active:@"—" error:YES];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    _folderPickerPresented = NO;
    NSURL *url = urls.firstObject;
    if (!url) {
        void (^pending)(BOOL) = _pendingAccessCompletion;
        _pendingAccessCompletion = nil;
        if (pending) pending(NO);
        return;
    }
    BOOL accessed = [url startAccessingSecurityScopedResource];
    FFDiagnosticLog(@"AuthorizedFolderAccess", @"Security-scoped resource: %@", accessed ? @"STARTED" : @"FAILED");
    if (!accessed) {
        NSError *accessError = FFError(66, @"The selected folder did not grant security-scoped access.");
        [self setStatus:accessError.localizedDescription path:@"" active:@"—" error:YES];
        void (^pending)(BOOL) = _pendingAccessCompletion;
        _pendingAccessCompletion = nil;
        if (pending) pending(NO);
        return;
    }
    NSString *selectedGame = [_selectedGameIdentifier copy];
    [self setBusy:YES];
    [self setStatus:@"VERIFYING AUTHORIZED GAME FOLDER…" path:@"" active:@"—" error:NO];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FFAccessContext *context = [FFCompatibilityRouter verifyAuthorizedURL:url
                                                                     forGame:selectedGame
                                                               requiresWrite:YES];
        NSError *bookmarkError = nil;
        if (context.usable && ![FFAccessManager storeBookmarkForAuthorizedURL:url error:&bookmarkError]) {
            context.usable = NO;
            context.error = bookmarkError ?: FFError(65, @"Could not save folder authorization.");
        }
        [url stopAccessingSecurityScopedResource];
        FFDiagnosticLog(@"AuthorizedFolderAccess", @"Security-scoped resource: STOPPED");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self->_selectedGameIdentifier isEqualToString:selectedGame]) return;
            void (^pending)(BOOL) = self->_pendingAccessCompletion;
            self->_pendingAccessCompletion = nil;
            [self finishAccessAttemptWithContext:context completion:pending];
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
    _folderPickerPresented = NO;
    [self setBusy:NO];
    [self setStatus:@"FOLDER AUTHORIZATION CANCELLED — NO FILE WAS CHANGED"
        path:@"" active:@"—" error:YES];
    void (^pending)(BOOL) = _pendingAccessCompletion;
    _pendingAccessCompletion = nil;
    if (pending) pending(NO);
}

- (NSURL *)resolvedRoot:(BOOL *)stale error:(NSError **)error {
    NSData *bookmark = [NSUserDefaults.standardUserDefaults dataForKey:FFBookmarkKey];
    if (!bookmark) {
        if (error) *error = FFError(20, @"Select the Free Fire folder first.");
        return nil;
    }
    return [NSURL URLByResolvingBookmarkData:bookmark
                                     options:0
                               relativeToURL:nil bookmarkDataIsStale:stale error:error];
}

- (void)withSelectedRoot:(void (^)(NSURL *root, NSError **operationError))operation completion:(void (^)(NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        BOOL stale = NO;
        NSURL *root = [FFAccessManager beginBookmarkedFolderAccessWithStale:&stale error:&error];
        if (!root) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
            return;
        }
        operation(root, &error);
        [FFAccessManager endBookmarkedFolderAccess:root];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}

- (NSString *)activeFeatureForTarget:(NSURL *)target {
    return FFActiveFeatureAtTarget(target, _selectedGameIdentifier);
}

- (void)reconnectAutomatically {
    [self inspectDirectAccess];
}

- (void)inspectSelectedFolder {
    [self inspectDirectAccessWithCompletion:nil];
}

- (void)inspectDirectAccess {
    [self inspectDirectAccessWithCompletion:nil];
}

static NSMutableDictionary<NSString *, NSArray *> *FFAccessCheckCache(void) {
    static NSMutableDictionary<NSString *, NSArray *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    return cache;
}

- (void)finishAccessAttemptWithContext:(FFAccessContext *)context
                             completion:(void (^)(BOOL ready))completion {
    [self setBusy:NO];
    _accessCheckInProgress = NO;
    NSString *cacheKey = _selectedGameIdentifier ?: @"";
    if (context && cacheKey.length) {
        FFAccessCheckCache()[cacheKey] = @[@([NSDate.date timeIntervalSince1970]), context];
    }
    if (context.usable && [context.gameIdentifier isEqualToString:_selectedGameIdentifier]) {
        _accessContext = context;
        _accessMethod = context.method;
        _usingSelectedFolder = context.method == FFAccessMethodAuthorizedFolder;
        [self updateGameRouting:context.gameIdentifier];
        NSString *gameName = FFGameDefinition(context.gameIdentifier)[@"displayName"] ?: @"FREE FIRE";
        NSString *methodName = context.method == FFAccessMethodDirect ? @"DIRECT ACCESS" : @"AUTHORIZED FOLDER";
        [self setStatus:[NSString stringWithFormat:@"%@ READY — %@", gameName, methodName]
            path:context.targetURL.path active:context.activeFeature ?: @"UNKNOWN" error:NO];
        [self rebuildInterface];
        if (completion) completion(YES);
        return;
    }

    _accessContext = nil;
    _accessMethod = FFAccessMethodNone;
    _usingSelectedFolder = NO;
    _connectedGameIdentifier = nil;
    _gameInstalled = NO;
    _readyToRun = NO;
    NSString *message = context.error.localizedDescription ?: @"No usable filesystem access method is available.";
#ifndef FF_OFFLINE_BUILD
    if (context.needsFolderSelection) {
        NSString *fallback = context.fallbackReason.length
            ? [NSString stringWithFormat:@"Direct access failed: %@", context.fallbackReason]
            : @"Direct access failed. Wait for the kernel chain and retry.";
        // No Files picker: it cannot authorize a private game container.
        [self setStatus:fallback path:@"" active:@"—" error:YES];
        _pendingAccessCompletion = [completion copy];
        [self rebuildInterface];
        if (completion) completion(NO);
        return;
    }
#endif
    [self setStatus:message path:@"" active:@"—" error:YES];
    [self rebuildInterface];
    if (completion) completion(NO);
}

- (void)inspectDirectAccessWithCompletion:(void (^)(BOOL ready))completion {
    if (_busy || _accessCheckInProgress) {
        if (completion) completion(NO);
        return;
    }
    NSString *selectedGame = _selectedGameIdentifier;
    if (!_licensed || !_activationToken.length || !FFGameDefinition(selectedGame)) {
        [self setStatus:@"LICENSE AND GAME SELECTION REQUIRED" path:nil active:@"—" error:YES];
        if (completion) completion(NO);
        return;
    }
    // Reuse a fresh result (success or failure) so the compatibility check
    // never repeats itself: at most one run per game every 120 seconds.
    NSArray *cached = FFAccessCheckCache()[selectedGame];
    if (cached.count == 2) {
        NSTimeInterval elapsed = [NSDate.date timeIntervalSince1970] - [cached[0] doubleValue];
        if (elapsed >= 0 && elapsed < 120.0) {
            FFAccessContext *context = cached[1];
            if (context.usable && [context.gameIdentifier isEqualToString:selectedGame]) {
                _accessContext = context;
                _accessMethod = context.method;
                _usingSelectedFolder = context.method == FFAccessMethodAuthorizedFolder;
                [self updateGameRouting:context.gameIdentifier];
                NSString *gameName = FFGameDefinition(context.gameIdentifier)[@"displayName"] ?: @"FREE FIRE";
                [self setStatus:[NSString stringWithFormat:@"%@ READY — %@", gameName,
                    context.method == FFAccessMethodDirect ? @"DIRECT ACCESS" : @"AUTHORIZED FOLDER"]
                    path:context.targetURL.path active:context.activeFeature ?: @"UNKNOWN" error:NO];
                [self rebuildInterface];
                if (completion) completion(YES);
                return;
            }
            [self setStatus:context.error.localizedDescription ?:
                @"No usable filesystem access method is available."
                path:@"" active:@"—" error:YES];
            [self rebuildInterface];
            if (completion) completion(NO);
            return;
        }
    }
    _accessCheckInProgress = YES;
    [self setBusy:YES];
    [self setStatus:@"VERIFYING SESSION…" path:@"" active:@"—" error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        (void)accessToken;
        if (sessionError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_accessCheckInProgress = NO;
                [self setBusy:NO];
                [self setStatus:sessionError.localizedDescription path:@"" active:@"—" error:YES];
                if (completion) completion(NO);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStatus:@"CHECKING FILESYSTEM ACCESS COMPATIBILITY…" path:@"" active:@"—" error:NO];
        });
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            FFAccessContext *context = [FFCompatibilityRouter routeGame:selectedGame requiresWrite:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![self->_selectedGameIdentifier isEqualToString:selectedGame]) return;
                [self finishAccessAttemptWithContext:context completion:completion];
            });
        });
    }];
}

- (void)enableFeature:(UIButton *)sender {
    if (_busy || !_licensed || sender.tag < 0 || sender.tag >= (NSInteger)_features.count) return;
    NSString *feature = _features[(NSUInteger)sender.tag];
    if (![FFLocalFeaturesForGame(_selectedGameIdentifier) containsObject:feature] ||
        ![_allowedFeatures containsObject:feature] ||
        ![_serverAvailableFeatures containsObject:feature]) return;
    if ([feature isEqualToString:@"MOD_SKINS"]) {
        _selectedFeature = nil;
        _readyToRun = NO;
        _selectedTab = FFMainTabSkins;
        _statusText = @"MOD SKINS — SERVER CATALOG";
        _statusIsError = NO;
        [self rebuildInterface];
        return;
    }
    _selectedFeature = feature;
    _readyToRun = NO;
    _statusText = [NSString stringWithFormat:@"%@ SELECTED — ACCESS WILL BE VERIFIED ON APPLY",
        FFFeatureDisplayName(feature)];
    _statusIsError = NO;
    [self rebuildInterface];
}

- (void)applySelectedFeature {
    if (_busy || !_licensed || !_selectedFeature.length) return;
    NSString *feature = [_selectedFeature copy];
    if ([feature isEqualToString:@"HOLOGRAM_GUN"] || [feature isEqualToString:@"SKIN_HOLO"]) {
        // Server-delivered shaders: authorize, download, install and
        // auto-revert after 60 seconds. No bundled payloads, no color picker.
        [self applyServerShader:feature];
        return;
    }
    if (!_gameInstalled) {
        [self setStatus:@"VERIFYING GAME BEFORE APPLY…" path:nil active:nil error:NO];
        [self inspectDirectAccessWithCompletion:^(BOOL ready) {
            if (ready && [self->_selectedFeature isEqualToString:feature]) {
                [self applySelectedFeature];
            }
        }];
        return;
    }
    if ([_selectedFeature isEqualToString:@"THREE_D"]) {
        [self beginThreeDColorSelection];
    } else {
        [self applyFeature:_selectedFeature color:nil expectedHash:nil durationDays:0];
    }
}

- (void)runSelectedGame {
    if (_busy || !_readyToRun || !_gameInstalled || !FFGameDefinition(_selectedGameIdentifier)) {
        [self setStatus:@"GAME NOT READY" path:nil active:nil error:YES];
        return;
    }
    NSError *error = nil;
    if (!FFLaunchGame(_selectedGameIdentifier, &error)) {
        _gameInstalled = NO;
        _readyToRun = NO;
        [self setStatus:error.localizedDescription ?: @"GAME NOT INSTALLED"
            path:nil active:nil error:YES];
        [self rebuildInterface];
        return;
    }
    [self setStatus:@"GAME LAUNCHED" path:nil active:_activeText error:NO];
}

- (void)beginHologramColorSelection {
    NSString *selectedGame = _selectedGameIdentifier;
#ifdef FF_OFFLINE_BUILD
    (void)selectedGame;
    [self setStatus:@"HOLOGRAM is disabled in offline builds." path:nil active:nil error:YES];
    return;
#endif
    if (![selectedGame isEqualToString:FFBundleIDFreeFireTH] ||
        ![_connectedGameIdentifier isEqualToString:selectedGame] ||
        _accessMethod != FFAccessMethodDirect) {
        [self setStatus:@"Hologram is available only for verified FREE FIRE TH."
            path:nil active:nil error:YES];
        return;
    }
    [self setBusy:YES];
    [self setStatus:@"VERIFYING FREE FIRE FOR HOLOGRAM…" path:nil active:nil error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        if (sessionError) {
            [self setBusy:NO];
            [self setStatus:sessionError.localizedDescription path:nil active:nil error:YES];
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            FFAccessContext *context = [FFGameDetector detectDirectContainerForGame:selectedGame];
            if (context.discovered) {
                [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:NO];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!context.usable) {
                    [self setBusy:NO];
                    [self setStatus:context.error.localizedDescription ?: @"Direct access verification failed."
                        path:nil active:nil error:YES];
                    return;
                }
                self->_accessContext = context;
                self->_accessMethod = FFAccessMethodDirect;
                [self updateGameRouting:context.gameIdentifier];
                if (![context.gameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
                    [self setBusy:NO];
                    [self setStatus:@"Hologram is available only for Free Fire, not Free Fire MAX." path:nil active:nil error:YES];
                    return;
                }
                [self setStatus:@"LOADING HOLOGRAM COLORS…" path:nil active:nil error:NO];
                ZXFeatureColors(@"HOLOGRAM_GUN", selectedGame, accessToken,
                    ^(NSArray<NSDictionary *> *colors, NSError *colorError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setBusy:NO];
                        if (colorError) {
                            [self setStatus:colorError.localizedDescription path:nil active:nil error:YES];
                            return;
                        }
                        [self presentHologramColors:colors];
                    });
                });
            });
        });
    }];
}

- (void)presentHologramColors:(NSArray<NSDictionary *> *)colors {
    if (!colors.count || ![_selectedGameIdentifier isEqualToString:FFBundleIDFreeFireTH]) {
        [self setStatus:@"NO VALID HOLOGRAM COLORS AVAILABLE" path:nil active:nil error:YES];
        return;
    }
    FFHologramPickerController *picker = [[FFHologramPickerController alloc]
        initWithColors:colors title:@"HOLOGRAM" applyTitle:@"NEXT — DURATION"
        selection:^(NSDictionary *color) {
            [self chooseHologramDurationForColor:color];
        }];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)chooseHologramDurationForColor:(NSDictionary *)color {
    if (![color[@"name"] isKindOfClass:NSString.class] || ![color[@"sha256"] isKindOfClass:NSString.class]) return;
    UIAlertController *duration = [UIAlertController alertControllerWithTitle:@"HOLOGRAM DURATION"
        message:@"Original will restore automatically after expiration."
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *days in @[@1, @3]) {
        NSString *title = [NSString stringWithFormat:@"%@ Day%@", days, days.integerValue == 1 ? @"" : @"s"];
        [duration addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                (void)action;
                [self applyFeature:@"HOLOGRAM_GUN" color:color[@"name"]
                    expectedHash:color[@"sha256"] durationDays:days.integerValue];
            }]];
    }
    [duration addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = duration.popoverPresentationController;
    if (popover) { popover.sourceView = self.view; popover.sourceRect = self.view.bounds; }
    [self presentViewController:duration animated:YES completion:nil];
}

- (void)beginThreeDColorSelection {
    NSString *selectedGame = _selectedGameIdentifier;
#ifdef FF_OFFLINE_BUILD
    (void)selectedGame;
    [self setStatus:@"3D is disabled in offline builds." path:nil active:nil error:YES];
    return;
#endif
    if (!FFGameDefinition(selectedGame) || ![_connectedGameIdentifier isEqualToString:selectedGame] ||
        _accessMethod != FFAccessMethodDirect) {
        [self setStatus:@"CONTAINER_FOUND_ACCESS_DENIED: 3D requires verified direct game access."
            path:nil active:nil error:YES];
        return;
    }
    [self setBusy:YES];
    [self setStatus:@"VERIFYING GAME FOR 3D…" path:nil active:nil error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        if (sessionError) {
            [self setBusy:NO];
            [self setStatus:sessionError.localizedDescription path:nil active:nil error:YES];
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            FFAccessContext *context = [FFGameDetector detectDirectContainerForGame:selectedGame];
            if (context.discovered) [FFAccessVerifier verifyContext:context requiresWrite:YES allowBackupOnly:NO];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!context.usable) {
                    [self setBusy:NO];
                    [self setStatus:context.error.localizedDescription ?: @"CONTAINER_FOUND_ACCESS_DENIED"
                        path:nil active:nil error:YES];
                    return;
                }
                self->_accessContext = context;
                self->_accessMethod = FFAccessMethodDirect;
                [self updateGameRouting:context.gameIdentifier];
                [self setStatus:@"LOADING 3D OPTIONS…" path:nil active:nil error:NO];
                ZXFeatureColors(@"THREE_D", selectedGame, accessToken,
                    ^(NSArray<NSDictionary *> *colors, NSError *colorError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setBusy:NO];
                        if (colorError) {
                            [self setStatus:colorError.localizedDescription path:nil active:nil error:YES];
                            return;
                        }
                        [self presentThreeDColors:colors];
                    });
                });
            });
        });
    }];
}

- (void)presentThreeDColors:(NSArray<NSDictionary *> *)colors {
    NSArray *received = [colors valueForKey:@"name"];
    if (![received isEqualToArray:@[@"BLACK", @"PINK", @"BLUE"]]) {
        [self setStatus:@"ASSET_NOT_FOUND: Black, Pink, Blue catalog verification failed."
            path:nil active:nil error:YES];
        return;
    }
    FFHologramPickerController *picker = [[FFHologramPickerController alloc]
        initWithColors:colors title:@"3D" applyTitle:@"APPLY 3D"
        selection:^(NSDictionary *color) {
            [self applyFeature:@"THREE_D" color:color[@"name"]
                expectedHash:color[@"sha256"] durationDays:0];
        }];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)applyFeature:(NSString *)feature color:(NSString *)color expectedHash:(NSString *)expectedHash
        durationDays:(NSInteger)durationDays {
    NSString *selectedGame = _selectedGameIdentifier;
    if (_busy || !_gameInstalled || !FFGameDefinition(selectedGame) ||
        ![FFLocalFeaturesForGame(selectedGame) containsObject:feature] ||
        ![_allowedFeatures containsObject:feature] ||
        ![_serverAvailableFeatures containsObject:feature]) {
        [self setStatus:@"FEATURE UNAVAILABLE FOR SELECTED GAME" path:nil active:nil error:YES];
        return;
    }
    if ([feature isEqualToString:@"HOLOGRAM_GUN"] && durationDays != 1 && durationDays != 3) {
        [self setStatus:@"APPLY_FAILED: Hologram duration must be 1 Day or 3 Days."
            path:nil active:nil error:YES];
        return;
    }
    _operationFeature = feature;
    _readyToRun = NO;
    [self setBusy:YES];
    BOOL coloredFeature = [@[@"HOLOGRAM_GUN", @"THREE_D"] containsObject:feature];
    NSString *operation = coloredFeature && color.length
        ? [NSString stringWithFormat:@"%@ %@", FFFeatureDisplayName(feature), color] : feature;
    _statusText = [NSString stringWithFormat:@"AUTHORIZING %@…", operation];
    _statusIsError = NO;
    [self rebuildInterface];
    [self setStatus:_statusText path:nil active:nil error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        if (sessionError) {
            self->_operationFeature = nil;
            [self setBusy:NO];
            [self setStatus:sessionError.localizedDescription path:nil active:nil error:YES];
            [self rebuildInterface];
            return;
        }
        ZXGrant(feature, selectedGame, accessToken, ^(NSString *featureToken, NSString *profileHash, NSError *authorizationError) {
            if (authorizationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_operationFeature = nil;
                    [self setBusy:NO];
                    [self setStatus:authorizationError.localizedDescription path:nil active:nil error:YES];
                    [self rebuildInterface];
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setStatus:[NSString stringWithFormat:@"APPLYING %@…", operation]
                    path:nil active:nil error:NO];
            });
            NSString *downloadHash = coloredFeature ? expectedHash : profileHash;
            ZXFetch(feature, selectedGame, color, downloadHash, accessToken, featureToken,
                ^(NSData *profileData, NSError *downloadError) {
                if (downloadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_operationFeature = nil;
                        [self setBusy:NO];
                        [self setStatus:downloadError.localizedDescription path:nil active:nil error:YES];
                        [self rebuildInterface];
                    });
                    return;
                }
                if (coloredFeature &&
                    self->_accessMethod != FFAccessMethodDirect) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_operationFeature = nil;
                        [self setBusy:NO];
                        [self setStatus:@"CONTAINER_FOUND_ACCESS_DENIED: selected option requires verified direct game access."
                            path:nil active:nil error:YES];
                        [self rebuildInterface];
                    });
                    return;
                }
                FFAccessMethod accessMethod = self->_accessMethod;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSError *error = nil;
                    NSString *path = nil;
                    BOOL installed = NO;
                    if ([feature isEqualToString:@"HOLOGRAM_GUN"]) {
                        FFAccessContext *direct = [FFGameDetector detectDirectContainerForGame:selectedGame];
                        if (direct.discovered) {
                            [FFAccessVerifier verifyContext:direct requiresWrite:YES allowBackupOnly:NO];
                        }
                        if (!direct.usable) {
                            error = direct.error ?: FFNamedError(67, @"CONTAINER_FOUND_ACCESS_DENIED", @"Direct filesystem access is no longer usable.");
                        } else {
                            installed = FFInstallHologramPackage(profileData, selectedGame, &path, &error);
                        }
                    } else if ([feature isEqualToString:@"THREE_D"]) {
                        installed = FFInstallThreeDData(profileData, selectedGame, &path, &error);
                    } else if ([feature isEqualToString:@"ESP"]) {
                        installed = [FFFeatureManager installESPPackageData:profileData
                            forGame:selectedGame accessMethod:accessMethod targetPath:&path error:&error];
                    } else {
                        installed = [FFFeatureManager installProfileData:profileData
                            forGame:selectedGame accessMethod:accessMethod targetPath:&path error:&error];
                    }
                    if (!installed && !error) error = FFNamedError(51, @"APPLY_FAILED", @"Option installation failed safely.");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (![self->_selectedGameIdentifier isEqualToString:selectedGame]) return;
                        self->_operationFeature = nil;
                        [self setBusy:NO];
                        if (error) {
                            if ([error.domain isEqualToString:@"com.fakherddin.ffcachemanager"] &&
                                error.code >= 60 && error.code <= 67) {
                                self->_accessContext = nil;
                                self->_accessMethod = FFAccessMethodNone;
                                self->_usingSelectedFolder = NO;
                                self->_connectedGameIdentifier = nil;
                                self->_gameInstalled = NO;
                                self->_readyToRun = NO;
                            }
                            [self setStatus:error.localizedDescription path:path active:nil error:YES];
                        } else {
                            NSString *active = coloredFeature && color.length
                                ? [NSString stringWithFormat:@"%@ / %@", FFFeatureDisplayName(feature), color] : feature;
                            NSString *key = FFActiveProfileDefaultsKey(selectedGame);
                            if (key) [NSUserDefaults.standardUserDefaults setObject:active forKey:key];
                            if ([feature isEqualToString:@"HOLOGRAM_GUN"]) {
                                FFSaveHologramState(selectedGame, color, path, durationDays);
                            }
                            self->_readyToRun = YES;
                            [self setStatus:[NSString stringWithFormat:@"APPLY_SUCCESS — %@ ACTIVE", active]
                                path:path active:active error:NO];
                        }
                        [self rebuildInterface];
                    });
                });
            });
        });
    }];
}

- (void)installFeatureDataFromSelectedFolder:(NSData *)profileData feature:(NSString *)feature {
    __block NSString *path = nil;
    [self setStatus:[NSString stringWithFormat:@"APPLYING %@…", feature] path:nil active:nil error:NO];
    [self withSelectedRoot:^(NSURL *root, NSError **operationError) {
        NSFileCoordinator *rootCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *inner = nil;
        [rootCoordinator coordinateReadingItemAtURL:root options:0 error:&inner byAccessor:^(NSURL *coordinatedRoot) {
            NSURL *directory = FFFindGameAssetBundles(coordinatedRoot, &inner);
            NSURL *target = directory ? FFTargetFile(directory, self->_selectedGameIdentifier, NO, &inner) : nil;
            if (!target) return;
            path = target.path;
            NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [fileCoordinator coordinateWritingItemAtURL:target options:NSFileCoordinatorWritingForReplacing error:&inner byAccessor:^(NSURL *coordinatedTarget) {
                if (!FFInstallFeatureData(profileData, coordinatedTarget, &inner) && !inner) {
                    inner = FFError(51, @"Option installation failed.");
                }
            }];
        }];
        if (inner) *operationError = inner;
    } completion:^(NSError *error) {
        [self setBusy:NO];
        if (error) {
            [self setStatus:error.localizedDescription path:path active:nil error:YES];
            return;
        }
        NSString *key = FFActiveProfileDefaultsKey(self->_selectedGameIdentifier);
        if (key) [NSUserDefaults.standardUserDefaults setObject:feature forKey:key];
        [self setStatus:[NSString stringWithFormat:@"%@ ACTIVE", feature] path:path active:feature error:NO];
    }];
}

- (void)restoreOriginal {
    NSString *selectedGame = _selectedGameIdentifier;
    if (_busy || !_licensed || !_activationToken.length ||
        !FFGameDefinition(selectedGame)) {
        if (!_busy) [self setStatus:@"LICENSE AND INSTALLED GAME REQUIRED"
            path:nil active:@"—" error:YES];
        return;
    }
    if (!_gameInstalled) {
        [self setStatus:@"VERIFYING GAME BEFORE RESTORE…" path:nil active:nil error:NO];
        [self inspectDirectAccessWithCompletion:^(BOOL ready) {
            if (ready && [self->_selectedGameIdentifier isEqualToString:selectedGame]) {
                [self restoreOriginal];
            }
        }];
        return;
    }
    [self setBusy:YES];
    [self setStatus:@"VERIFYING SESSION…" path:nil active:nil error:NO];
    [self refreshSessionForOperation:^(NSString *accessToken, NSError *sessionError) {
        (void)accessToken;
        if (sessionError) {
            [self setBusy:NO];
            [self setStatus:sessionError.localizedDescription path:nil active:nil error:YES];
            return;
        }
        [self setStatus:@"Restoring original cache…" path:nil active:nil error:NO];
        FFAccessMethod accessMethod = self->_accessMethod;
        NSString *activeKey = FFActiveProfileDefaultsKey(selectedGame);
        NSString *activeProfile = activeKey ? [NSUserDefaults.standardUserDefaults stringForKey:activeKey] : nil;
        __block NSString *path = nil;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *error = nil;
            BOOL restored = NO;
            if ([activeProfile hasPrefix:@"HOLOGRAM"]) {
                restored = FFRestoreDirectAsset(selectedGame, FFHologramShaderFilename,
                    @"Hologram shader", &path, &error);
            } else if ([activeProfile hasPrefix:@"3D"]) {
                restored = FFRestoreDirectAsset(selectedGame, FFThreeDShaderFilename,
                    @"3D shader", &path, &error);
            } else if ([activeProfile isEqualToString:@"ESP"]) {
                restored = [FFFeatureManager restoreESPForGame:selectedGame
                    accessMethod:accessMethod targetPath:&path error:&error];
            } else {
                restored = [FFFeatureManager restoreOriginalForGame:selectedGame
                    accessMethod:accessMethod targetPath:&path error:&error];
            }
            if (!restored && !error) error = FFNamedError(51, @"RESTORE_FAILED", @"Restore failed safely.");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![self->_selectedGameIdentifier isEqualToString:selectedGame]) return;
                [self setBusy:NO];
                if (error) {
                    if ([error.domain isEqualToString:@"com.fakherddin.ffcachemanager"] &&
                        error.code >= 60 && error.code <= 67) {
                        self->_accessContext = nil;
                        self->_accessMethod = FFAccessMethodNone;
                        self->_usingSelectedFolder = NO;
                        self->_connectedGameIdentifier = nil;
                        self->_gameInstalled = NO;
                    }
                    [self setStatus:error.localizedDescription path:path active:nil error:YES];
                }
                else {
                    NSString *key = FFActiveProfileDefaultsKey(selectedGame);
                    if (key) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
                    if ([activeProfile hasPrefix:@"HOLOGRAM"]) {
                        [NSUserDefaults.standardUserDefaults removeObjectForKey:FFHologramStateKey];
                    }
                    self->_readyToRun = NO;
                    [self setStatus:@"RESTORE_SUCCESS — ORIGINAL RESTORED" path:path active:@"ORIGINAL" error:NO];
                }
                [self rebuildInterface];
            });
        });
    }];
}

- (void)restoreOriginalFromSelectedFolder {
    __block NSString *path = nil;
    [self withSelectedRoot:^(NSURL *root, NSError **operationError) {
        NSFileCoordinator *rootCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *inner = nil;
        [rootCoordinator coordinateReadingItemAtURL:root options:0 error:&inner byAccessor:^(NSURL *coordinatedRoot) {
            NSURL *directory = FFFindGameAssetBundles(coordinatedRoot, &inner);
            NSURL *target = directory ? FFTargetFile(directory, self->_selectedGameIdentifier, YES, &inner) : nil;
            if (!target) return;
            path = target.path;
            NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [fileCoordinator coordinateWritingItemAtURL:target options:NSFileCoordinatorWritingForReplacing error:&inner byAccessor:^(NSURL *coordinatedTarget) {
                FFRestoreOriginal(coordinatedTarget, &inner);
            }];
        }];
        if (inner) *operationError = inner;
    } completion:^(NSError *error) {
        [self setBusy:NO];
        if (error) {
            [self setStatus:error.localizedDescription path:path active:nil error:YES];
            return;
        }
        NSString *key = FFActiveProfileDefaultsKey(self->_selectedGameIdentifier);
        if (key) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
        [self setStatus:@"Original cache restored" path:path active:@"ORIGINAL" error:NO];
    }];
}

@end


@interface FFAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end


@implementation FFAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *navigation = [[UINavigationController alloc]
        initWithRootViewController:[FFHomeViewController new]];
    navigation.navigationBar.tintColor = FFVIPGold();
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    FFDenyDebugger();
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(FFAppDelegate.class));
    }
}
