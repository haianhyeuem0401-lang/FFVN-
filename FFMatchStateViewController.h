#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// App-local Match State screen.  It records manual/authorized events only and
/// never derives START/END from network traffic.
@interface FFMatchStateViewController : UIViewController

- (instancetype)initWithGameIdentifier:(nullable NSString *)gameIdentifier;

@end

NS_ASSUME_NONNULL_END
