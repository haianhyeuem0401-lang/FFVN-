#import "FFMatchStateManager.h"

NSString *const FFMatchStateDidChangeNotification = @"FFMatchStateDidChangeNotification";

static NSString *const FFMatchStateHistoryKey = @"FFMatchStateHistory.v1";
static const NSUInteger FFMatchStateHistoryLimit = 200;

NSString *FFMatchStateName(FFMatchState state) {
    switch (state) {
        case FFMatchStateNotStart: return @"NOT_START";
        case FFMatchStateStart: return @"START";
        case FFMatchStateEnd: return @"END";
        case FFMatchStateUnknown:
        default:
            return @"UNKNOWN";
    }
}

NSString *FFMatchStateSourceName(FFMatchStateSource source) {
    switch (source) {
        case FFMatchStateSourceManual: return @"MANUAL";
        case FFMatchStateSourceAuthorized: return @"AUTHORIZED";
        case FFMatchStateSourceNetwork: return @"NETWORK";
        case FFMatchStateSourceUnknown:
        default:
            return @"UNKNOWN";
    }
}

BOOL FFMatchStateIsTrustedSource(FFMatchStateSource source) {
    // The app itself (manual operator action) and a future explicitly
    // authorized source are trusted.  Raw network observations are never
    // trusted because the capture did not prove a state signal.
    return source == FFMatchStateSourceManual || source == FFMatchStateSourceAuthorized;
}

@interface FFMatchStateManager ()
@property (nonatomic, readwrite) FFMatchState currentState;
@property (nonatomic, readwrite) FFMatchStateSource source;
@property (nonatomic, readwrite, copy) NSString *reason;
@property (nonatomic, readwrite, strong, nullable) NSDate *lastTransitionDate;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *mutableHistory;
@end

@implementation FFMatchStateManager

+ (instancetype)sharedManager {
    static FFMatchStateManager *manager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [FFMatchStateManager new];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    // A new process has no trusted information about a live match, so the
    // session always starts UNKNOWN.  Historical transitions are kept for
    // auditing, but never restored as the current state.
    _currentState = FFMatchStateUnknown;
    _source = FFMatchStateSourceUnknown;
    _reason = @"No trusted match event received in this session";
    _lastTransitionDate = nil;
    _mutableHistory = [NSMutableArray array];
    [self loadHistory];
    return self;
}

- (NSArray<NSDictionary *> *)history {
    @synchronized (self) {
        return [_mutableHistory copy];
    }
}

- (void)transitionToState:(FFMatchState)state
                   reason:(NSString *)reason
                   source:(FFMatchStateSource)source {
    if (!FFMatchStateIsTrustedSource(source)) {
        // Untrusted network observations are deliberately rejected.  They are
        // not logged as transitions so the UI can never present them as proof.
        return;
    }
    if (state != FFMatchStateUnknown && state != FFMatchStateNotStart &&
        state != FFMatchStateStart && state != FFMatchStateEnd) {
        return;
    }

    NSString *cleanReason = [reason stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!cleanReason.length) {
        cleanReason = @"No reason supplied";
    }

    NSDictionary *entry = nil;
    @synchronized (self) {
        if (state == _currentState && source == _source) {
            // Duplicate manual presses do not create a new transition.
            return;
        }
        NSDate *now = [NSDate date];
        _currentState = state;
        _source = source;
        _reason = [cleanReason copy];
        _lastTransitionDate = now;
        entry = @{
            @"state": FFMatchStateName(state),
            @"state_value": @(state),
            @"source": FFMatchStateSourceName(source),
            @"source_value": @(source),
            @"reason": _reason,
            @"timestamp": now,
        };
        [_mutableHistory addObject:entry];
        if (_mutableHistory.count > FFMatchStateHistoryLimit) {
            [_mutableHistory removeObjectsInRange:
                NSMakeRange(0, _mutableHistory.count - FFMatchStateHistoryLimit)];
        }
        [self persistHistoryLocked];
    }

    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:FFMatchStateDidChangeNotification object:self];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFMatchStateDidChangeNotification object:self];
        });
    }
}

- (void)resetToUnknownWithReason:(NSString *)reason
                          source:(FFMatchStateSource)source {
    [self transitionToState:FFMatchStateUnknown reason:reason source:source];
}

- (NSDictionary *)snapshot {
    NSDate *last = nil;
    NSArray<NSDictionary *> *history = nil;
    FFMatchState state;
    FFMatchStateSource source;
    NSString *reason = nil;
    @synchronized (self) {
        state = _currentState;
        source = _source;
        reason = _reason;
        last = _lastTransitionDate;
        history = [_mutableHistory copy];
    }

    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSMutableArray<NSDictionary *> *sanitized = [NSMutableArray arrayWithCapacity:history.count];
    NSDateFormatter *logFormatter = [NSDateFormatter new];
    logFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    logFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    logFormatter.timeZone = [NSTimeZone localTimeZone];
    for (NSDictionary *entry in history) {
        NSDate *timestamp = entry[@"timestamp"];
        [sanitized addObject:@{
            @"state": entry[@"state"] ?: @"UNKNOWN",
            @"state_value": entry[@"state_value"] ?: @(FFMatchStateUnknown),
            @"source": entry[@"source"] ?: @"UNKNOWN",
            @"source_value": entry[@"source_value"] ?: @(FFMatchStateSourceUnknown),
            @"reason": entry[@"reason"] ?: @"",
            @"timestamp_iso8601": timestamp ? [formatter stringFromDate:timestamp] : @"",
            @"timestamp_local": timestamp ? [logFormatter stringFromDate:timestamp] : @"",
        }];
    }

    return @{
        @"state": FFMatchStateName(state),
        @"state_value": @(state),
        @"source": FFMatchStateSourceName(source),
        @"source_value": @(source),
        @"reason": reason ?: @"",
        @"last_transition_iso8601": last ? [formatter stringFromDate:last] : @"",
        @"last_transition_local": last ? [logFormatter stringFromDate:last] : @"",
        @"history": sanitized,
        @"history_count": @(sanitized.count),
        @"trusted_sources": @[@"MANUAL", @"AUTHORIZED"],
        @"automatic_detection": @"NOT VERIFIED",
        @"network_signals_used": @NO,
    };
}

#pragma mark - History persistence

- (void)loadHistory {
    NSArray *stored = [[NSUserDefaults standardUserDefaults]
        arrayForKey:FFMatchStateHistoryKey];
    if (![stored isKindOfClass:[NSArray class]]) return;
    for (id item in stored) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *entry = item;
        if (![entry[@"state"] isKindOfClass:[NSString class]] ||
            ![entry[@"reason"] isKindOfClass:[NSString class]]) {
            continue;
        }
        [_mutableHistory addObject:entry];
    }
    if (_mutableHistory.count > FFMatchStateHistoryLimit) {
        [_mutableHistory removeObjectsInRange:
            NSMakeRange(0, _mutableHistory.count - FFMatchStateHistoryLimit)];
    }
}

- (void)persistHistoryLocked {
    // NSUserDefaults handles property-list values.  Timestamps stay as NSDate
    // and are converted to strings only when a snapshot is exported.
    [[NSUserDefaults standardUserDefaults] setObject:[_mutableHistory copy]
                                              forKey:FFMatchStateHistoryKey];
}

@end
