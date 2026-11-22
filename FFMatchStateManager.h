#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFMatchState) {
    FFMatchStateUnknown = 0,
    FFMatchStateNotStart,
    FFMatchStateStart,
    FFMatchStateEnd,
};

typedef NS_ENUM(NSInteger, FFMatchStateSource) {
    FFMatchStateSourceUnknown = 0,
    FFMatchStateSourceManual,
    FFMatchStateSourceAuthorized,
    FFMatchStateSourceNetwork,
};

extern NSString *const FFMatchStateDidChangeNotification;

NSString *FFMatchStateName(FFMatchState state);
NSString *FFMatchStateSourceName(FFMatchStateSource source);
BOOL FFMatchStateIsTrustedSource(FFMatchStateSource source);

/// App-local match state store.
///
/// The automatic network heuristics from the VPN capture are intentionally not
/// connected here: HTTP 206, POST bursts and UDP server changes were not
/// verified as START/END signals.  Only an in-app manual action or a future
/// authorized source should call the transition methods.
@interface FFMatchStateManager : NSObject

@property (nonatomic, readonly) FFMatchState currentState;
@property (nonatomic, readonly) FFMatchStateSource source;
@property (nonatomic, readonly, copy) NSString *reason;
@property (nonatomic, readonly, strong, nullable) NSDate *lastTransitionDate;
@property (nonatomic, readonly, copy) NSArray<NSDictionary *> *history;

+ (instancetype)sharedManager;

- (void)transitionToState:(FFMatchState)state
                   reason:(NSString *)reason
                   source:(FFMatchStateSource)source;

- (void)resetToUnknownWithReason:(NSString *)reason
                          source:(FFMatchStateSource)source;

- (NSDictionary *)snapshot;

@end

NS_ASSUME_NONNULL_END
