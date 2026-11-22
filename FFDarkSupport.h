#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFDarkSupportVerdict) {
    FFDarkSupportVerdictBlocked = 0,
    FFDarkSupportVerdictLimited,
    FFDarkSupportVerdictPreviewReady,
};

/// Human-readable verdict used by the DARK screen.
NSString *FFDarkSupportVerdictText(FFDarkSupportVerdict verdict);

/// Current iOS version, for example "18.5" or "26.0.1".
NSString *FFDarkSupportIOSVersion(void);

/// Hardware identifier, for example "iPhone15,2".
NSString *FFDarkSupportDeviceModel(void);

/// YES when the current idiom is iPad.
BOOL FFDarkSupportIsIPad(void);

/// Version-gated policy tier.  This is the only DarkSword-inspired idea used
/// here: separate policies per OS range, with explicit unsupported ranges.
/// No DarkSword code is copied or executed.
NSString *FFDarkSupportPolicyTier(void);

/// Informational DarkSword reference for the current OS.  Never an activation
/// condition and never a promise of overlay/ESP/AIM support.
NSString *FFDarkSupportDarkSwordReference(void);

/// 3105 kernel exploit status when available in this build.
NSString *FFDarkSupportKernelLabel(void);

/// YES when a jailbreak root is visible.  The DARK beta still does not inject
/// into Free Fire on jailbroken devices; it only reports the condition.
BOOL FFDarkSupportJailbreakDetected(void);

/// Complete compatibility report consumed by FFDarkViewController.
/// The dictionary contains only display strings, booleans and a verdict.
NSDictionary<NSString *, id> *FFDarkSupportReport(NSString * _Nullable gameIdentifier,
                                                  BOOL licenseActive);

NS_ASSUME_NONNULL_END
