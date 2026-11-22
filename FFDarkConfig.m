#import "FFDarkConfig.h"

@interface FFDarkConfig ()
- (void)applyDictionary:(NSDictionary *)dictionary;
@end

static NSString *const FFDarkConfigDefaultsKey = @"FFDarkConfig.v1";

static BOOL FFDarkReadBool(NSDictionary *dictionary, NSString *key, BOOL fallback) {
    id value = dictionary[key];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : fallback;
}

static NSInteger FFDarkReadInteger(NSDictionary *dictionary, NSString *key, NSInteger fallback) {
    id value = dictionary[key];
    return [value isKindOfClass:NSNumber.class] ? [value integerValue] : fallback;
}

static CGFloat FFDarkReadFloat(NSDictionary *dictionary, NSString *key, CGFloat fallback) {
    id value = dictionary[key];
    return [value isKindOfClass:NSNumber.class] ? (CGFloat)[value doubleValue] : fallback;
}

static CGFloat FFDarkClamp(CGFloat value, CGFloat minimum, CGFloat maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

@implementation FFDarkConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetToDefaults];
    }
    return self;
}

+ (instancetype)loadConfig {
    FFDarkConfig *config = [FFDarkConfig new];
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey:FFDarkConfigDefaultsKey];
    if ([stored isKindOfClass:NSDictionary.class]) {
        [config applyDictionary:stored];
        [config clampValues];
    }
    return config;
}

- (void)resetToDefaults {
    _masterEnabled = YES;

    _boardEnabled = YES;
    _boardStyle = FFDarkBoardStyleCompact;
    _boardPosition = FFDarkBoardPositionTopLeft;
    _boardOpacity = 0.86;
    _boardScale = 1.0;
    _boardShowFPS = YES;
    _boardShowPing = YES;
    _boardShowClock = YES;

    _espEnabled = YES;
    _espBoxes = YES;
    _espSkeleton = YES;
    _espNames = YES;
    _espDistance = YES;
    _espHealth = YES;
    _espTeamCheck = YES;
    _espSnaplines = NO;
    _espMaxDistance = 120.0;
    _espOpacity = 0.90;

    _aimEnabled = NO;
    _aimFOV = 140.0;
    _aimSmoothing = 0.35;
    _aimTarget = FFDarkAimTargetHead;
    _aimVisibilityCheck = YES;
    _aimAutoFire = NO;
    _aimBotEnabled = YES;
    _aimSensitivity = 0.80;

    _displayScale = 1.0;
    _displayOpacity = 0.95;
    _accent = FFDarkAccentGold;
    _language = FFDarkLanguageEnglish;
    _displayShowCompatibilityBadge = YES;
    _displayShowGrid = YES;
    _displayShowScanlines = NO;
}

- (void)clampValues {
    _boardOpacity = FFDarkClamp(_boardOpacity, 0.35, 1.0);
    _boardScale = FFDarkClamp(_boardScale, 0.80, 1.45);
    _espMaxDistance = FFDarkClamp(_espMaxDistance, 25.0, 300.0);
    _espOpacity = FFDarkClamp(_espOpacity, 0.30, 1.0);
    _aimFOV = FFDarkClamp(_aimFOV, 30.0, 300.0);
    _aimSmoothing = FFDarkClamp(_aimSmoothing, 0.0, 0.95);
    _aimSensitivity = FFDarkClamp(_aimSensitivity, 0.10, 2.0);
    _displayScale = FFDarkClamp(_displayScale, 0.75, 1.50);
    _displayOpacity = FFDarkClamp(_displayOpacity, 0.40, 1.0);

    if (_boardStyle < FFDarkBoardStyleFull || _boardStyle > FFDarkBoardStyleMinimal) {
        _boardStyle = FFDarkBoardStyleCompact;
    }
    if (_boardPosition < FFDarkBoardPositionTopLeft ||
        _boardPosition > FFDarkBoardPositionBottomRight) {
        _boardPosition = FFDarkBoardPositionTopLeft;
    }
    if (_aimTarget < FFDarkAimTargetHead || _aimTarget > FFDarkAimTargetNearest) {
        _aimTarget = FFDarkAimTargetHead;
    }
    if (_accent < FFDarkAccentGold || _accent > FFDarkAccentGreen) {
        _accent = FFDarkAccentGold;
    }
    if (_language < FFDarkLanguageEnglish || _language > FFDarkLanguageFrench) {
        _language = FFDarkLanguageEnglish;
    }
}

- (void)save {
    [self clampValues];
    [[NSUserDefaults standardUserDefaults] setObject:[self dictionaryRepresentation]
                                              forKey:FFDarkConfigDefaultsKey];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"schema": @1,
        @"master_enabled": @(_masterEnabled),
        @"board_enabled": @(_boardEnabled),
        @"board_style": @(_boardStyle),
        @"board_position": @(_boardPosition),
        @"board_opacity": @(_boardOpacity),
        @"board_scale": @(_boardScale),
        @"board_show_fps": @(_boardShowFPS),
        @"board_show_ping": @(_boardShowPing),
        @"board_show_clock": @(_boardShowClock),
        @"esp_enabled": @(_espEnabled),
        @"esp_boxes": @(_espBoxes),
        @"esp_skeleton": @(_espSkeleton),
        @"esp_names": @(_espNames),
        @"esp_distance": @(_espDistance),
        @"esp_health": @(_espHealth),
        @"esp_team_check": @(_espTeamCheck),
        @"esp_snaplines": @(_espSnaplines),
        @"esp_max_distance": @(_espMaxDistance),
        @"esp_opacity": @(_espOpacity),
        @"aim_enabled": @(_aimEnabled),
        @"aim_fov": @(_aimFOV),
        @"aim_smoothing": @(_aimSmoothing),
        @"aim_target": @(_aimTarget),
        @"aim_visibility_check": @(_aimVisibilityCheck),
        @"aim_auto_fire": @(_aimAutoFire),
        @"aim_bot_enabled": @(_aimBotEnabled),
        @"aim_sensitivity": @(_aimSensitivity),
        @"display_scale": @(_displayScale),
        @"display_opacity": @(_displayOpacity),
        @"accent": @(_accent),
        @"language": @(_language),
        @"display_compat_badge": @(_displayShowCompatibilityBadge),
        @"display_grid": @(_displayShowGrid),
        @"display_scanlines": @(_displayShowScanlines),
    };
}

- (void)applyDictionary:(NSDictionary *)dictionary {
    _masterEnabled = FFDarkReadBool(dictionary, @"master_enabled", _masterEnabled);

    _boardEnabled = FFDarkReadBool(dictionary, @"board_enabled", _boardEnabled);
    _boardStyle = (FFDarkBoardStyle)FFDarkReadInteger(dictionary, @"board_style", _boardStyle);
    _boardPosition = (FFDarkBoardPosition)FFDarkReadInteger(dictionary, @"board_position", _boardPosition);
    _boardOpacity = FFDarkReadFloat(dictionary, @"board_opacity", _boardOpacity);
    _boardScale = FFDarkReadFloat(dictionary, @"board_scale", _boardScale);
    _boardShowFPS = FFDarkReadBool(dictionary, @"board_show_fps", _boardShowFPS);
    _boardShowPing = FFDarkReadBool(dictionary, @"board_show_ping", _boardShowPing);
    _boardShowClock = FFDarkReadBool(dictionary, @"board_show_clock", _boardShowClock);

    _espEnabled = FFDarkReadBool(dictionary, @"esp_enabled", _espEnabled);
    _espBoxes = FFDarkReadBool(dictionary, @"esp_boxes", _espBoxes);
    _espSkeleton = FFDarkReadBool(dictionary, @"esp_skeleton", _espSkeleton);
    _espNames = FFDarkReadBool(dictionary, @"esp_names", _espNames);
    _espDistance = FFDarkReadBool(dictionary, @"esp_distance", _espDistance);
    _espHealth = FFDarkReadBool(dictionary, @"esp_health", _espHealth);
    _espTeamCheck = FFDarkReadBool(dictionary, @"esp_team_check", _espTeamCheck);
    _espSnaplines = FFDarkReadBool(dictionary, @"esp_snaplines", _espSnaplines);
    _espMaxDistance = FFDarkReadFloat(dictionary, @"esp_max_distance", _espMaxDistance);
    _espOpacity = FFDarkReadFloat(dictionary, @"esp_opacity", _espOpacity);

    _aimEnabled = FFDarkReadBool(dictionary, @"aim_enabled", _aimEnabled);
    _aimFOV = FFDarkReadFloat(dictionary, @"aim_fov", _aimFOV);
    _aimSmoothing = FFDarkReadFloat(dictionary, @"aim_smoothing", _aimSmoothing);
    _aimTarget = (FFDarkAimTarget)FFDarkReadInteger(dictionary, @"aim_target", _aimTarget);
    _aimVisibilityCheck = FFDarkReadBool(dictionary, @"aim_visibility_check", _aimVisibilityCheck);
    _aimAutoFire = FFDarkReadBool(dictionary, @"aim_auto_fire", _aimAutoFire);
    _aimBotEnabled = FFDarkReadBool(dictionary, @"aim_bot_enabled", _aimBotEnabled);
    _aimSensitivity = FFDarkReadFloat(dictionary, @"aim_sensitivity", _aimSensitivity);

    _displayScale = FFDarkReadFloat(dictionary, @"display_scale", _displayScale);
    _displayOpacity = FFDarkReadFloat(dictionary, @"display_opacity", _displayOpacity);
    _accent = (FFDarkAccent)FFDarkReadInteger(dictionary, @"accent", _accent);
    _language = (FFDarkLanguage)FFDarkReadInteger(dictionary, @"language", _language);
    _displayShowCompatibilityBadge = FFDarkReadBool(dictionary, @"display_compat_badge",
        _displayShowCompatibilityBadge);
    _displayShowGrid = FFDarkReadBool(dictionary, @"display_grid", _displayShowGrid);
    _displayShowScanlines = FFDarkReadBool(dictionary, @"display_scanlines", _displayShowScanlines);
}

- (NSString *)jsonString {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self dictionaryRepresentation]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if (!data || error) return @"{}";
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string ?: @"{}";
}

- (BOOL)applyJSONString:(NSString *)json error:(NSError **)error {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:@"FFDarkConfig"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Empty configuration."}];
        }
        return NO;
    }
    NSError *parseError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (![object isKindOfClass:NSDictionary.class]) {
        if (error) {
            *error = parseError ?: [NSError errorWithDomain:@"FFDarkConfig"
                                                       code:2
                                                   userInfo:@{
                NSLocalizedDescriptionKey: @"Configuration is not a JSON object."
            }];
        }
        return NO;
    }
    [self applyDictionary:object];
    [self clampValues];
    return YES;
}

@end
