#import <UIKit/UIKit.h>

@class FFDarkConfig;

NS_ASSUME_NONNULL_BEGIN

/// A self-contained rendering of the DARK in-game layout.  It previews what the
/// injected dylib draws inside Free Fire; this view itself has no connection to
/// the game, ReplayKit or any game process.
@interface FFDarkPreviewView : UIView

@property (nonatomic, strong) FFDarkConfig *config;
@property (nonatomic, copy, nullable) NSString *compatibilityBadgeText;
/// Reveals the animated glowing scope button that toggles the DARK panel inside
/// Free Fire.  The button is a preview only in this companion app.
@property (nonatomic, assign) BOOL showFloatingButton;

- (void)refresh;

@end

NS_ASSUME_NONNULL_END
