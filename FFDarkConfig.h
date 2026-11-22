#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFDarkAccent) {
    FFDarkAccentGold = 0,
    FFDarkAccentCyan,
    FFDarkAccentRed,
    FFDarkAccentGreen,
};

typedef NS_ENUM(NSInteger, FFDarkLanguage) {
    FFDarkLanguageEnglish = 0,
    FFDarkLanguageArabic,
    FFDarkLanguageFrench,
};

typedef NS_ENUM(NSInteger, FFDarkBoardStyle) {
    FFDarkBoardStyleFull = 0,
    FFDarkBoardStyleCompact,
    FFDarkBoardStyleMinimal,
};

typedef NS_ENUM(NSInteger, FFDarkBoardPosition) {
    FFDarkBoardPositionTopLeft = 0,
    FFDarkBoardPositionTopRight,
    FFDarkBoardPositionBottomLeft,
    FFDarkBoardPositionBottomRight,
};

typedef NS_ENUM(NSInteger, FFDarkAimTarget) {
    FFDarkAimTargetHead = 0,
    FFDarkAimTargetChest,
    FFDarkAimTargetNearest,
};

/// Local, device-only DARK settings.  This model drives the companion preview
/// and layout editor.  The in-game DARK dylib keeps its own runtime state; the
/// companion app never sends this model to the game process.
@interface FFDarkConfig : NSObject

@property (nonatomic, assign) BOOL masterEnabled;

@property (nonatomic, assign) BOOL boardEnabled;
@property (nonatomic, assign) FFDarkBoardStyle boardStyle;
@property (nonatomic, assign) FFDarkBoardPosition boardPosition;
@property (nonatomic, assign) CGFloat boardOpacity;
@property (nonatomic, assign) CGFloat boardScale;
@property (nonatomic, assign) BOOL boardShowFPS;
@property (nonatomic, assign) BOOL boardShowPing;
@property (nonatomic, assign) BOOL boardShowClock;

@property (nonatomic, assign) BOOL espEnabled;
@property (nonatomic, assign) BOOL espBoxes;
@property (nonatomic, assign) BOOL espSkeleton;
@property (nonatomic, assign) BOOL espNames;
@property (nonatomic, assign) BOOL espDistance;
@property (nonatomic, assign) BOOL espHealth;
@property (nonatomic, assign) BOOL espTeamCheck;
@property (nonatomic, assign) BOOL espSnaplines;
@property (nonatomic, assign) CGFloat espMaxDistance;
@property (nonatomic, assign) CGFloat espOpacity;

@property (nonatomic, assign) BOOL aimEnabled;
@property (nonatomic, assign) CGFloat aimFOV;
@property (nonatomic, assign) CGFloat aimSmoothing;
@property (nonatomic, assign) FFDarkAimTarget aimTarget;
@property (nonatomic, assign) BOOL aimVisibilityCheck;
@property (nonatomic, assign) BOOL aimAutoFire;
@property (nonatomic, assign) BOOL aimBotEnabled;
@property (nonatomic, assign) CGFloat aimSensitivity;

@property (nonatomic, assign) CGFloat displayScale;
@property (nonatomic, assign) CGFloat displayOpacity;
@property (nonatomic, assign) FFDarkAccent accent;
@property (nonatomic, assign) FFDarkLanguage language;
@property (nonatomic, assign) BOOL displayShowCompatibilityBadge;
@property (nonatomic, assign) BOOL displayShowGrid;
@property (nonatomic, assign) BOOL displayShowScanlines;

/// Loads the persisted model, or returns a model with safe defaults.
+ (instancetype)loadConfig;

/// Persists the clamped model in NSUserDefaults.
- (void)save;

/// Restores every field to its beta default.
- (void)resetToDefaults;

/// Serialises the model for diagnostics/export.  It contains no secrets.
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
- (NSString *)jsonString;

/// Imports a previously exported model.  Unknown keys are ignored.
- (BOOL)applyJSONString:(NSString *)json error:(NSError **)error;

/// Clamps values that may have come from an older build or a hand-edited file.
- (void)clampValues;

@end

NS_ASSUME_NONNULL_END
