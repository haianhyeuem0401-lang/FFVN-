#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Independent DARK beta screen.  It edits a local layout/simulation model and
/// never opens, attaches to or modifies Free Fire.
@interface FFDarkViewController : UIViewController

- (instancetype)initWithGameIdentifier:(NSString * _Nullable)gameIdentifier
                        licenseActive:(BOOL)licenseActive;

@end

NS_ASSUME_NONNULL_END
