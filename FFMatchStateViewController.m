#import "FFMatchStateViewController.h"
#import "FFMatchStateManager.h"

static UIColor *FFMatchBackground(void) {
    return [UIColor colorWithRed:0.035 green:0.045 blue:0.060 alpha:1.0];
}

static UIColor *FFMatchPanel(void) {
    return [UIColor colorWithRed:0.075 green:0.085 blue:0.105 alpha:1.0];
}

static UIColor *FFMatchGold(void) {
    return [UIColor colorWithRed:1.00 green:0.78 blue:0.24 alpha:1.0];
}

static UIColor *FFMatchCyan(void) {
    return [UIColor colorWithRed:0.20 green:0.90 blue:0.96 alpha:1.0];
}

static UIColor *FFMatchGreen(void) {
    return [UIColor colorWithRed:0.30 green:1.00 blue:0.52 alpha:1.0];
}

static UIColor *FFMatchOrange(void) {
    return [UIColor colorWithRed:1.00 green:0.55 blue:0.22 alpha:1.0];
}

static UIColor *FFMatchGray(void) {
    return [UIColor colorWithWhite:0.68 alpha:1.0];
}

static UIColor *FFMatchRed(void) {
    return [UIColor colorWithRed:1.00 green:0.32 blue:0.32 alpha:1.0];
}

@interface FFMatchStateViewController ()
- (void)dismissSelf;
- (void)buildInterface;
- (void)rebuildContent;
- (void)buildContent;
- (void)stateDidChange:(NSNotification *)notification;
- (void)markNotStart;
- (void)markStart;
- (void)markEnd;
- (void)resetUnknown;
- (void)copySnapshot;
- (void)recordState:(FFMatchState)state label:(NSString *)label;
- (UIColor *)colorForState:(FFMatchState)state;
- (NSString *)timestampText:(NSDate *)date;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UIView *)cardWithContent:(UIView *)content;
- (UIButton *)actionButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector;
- (UIButton *)stateButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector;
- (UIView *)informationRow:(NSString *)title value:(NSString *)value;
- (UIView *)sectionTitle:(NSString *)title;
@end

@implementation FFMatchStateViewController {
    NSString *_gameIdentifier;
    UIScrollView *_rootScroll;
    UIStackView *_rootStack;
    NSString *_feedbackText;
}

- (instancetype)initWithGameIdentifier:(NSString *)gameIdentifier {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _gameIdentifier = [gameIdentifier copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = FFMatchBackground();
    self.title = @"MATCH STATE";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"CLOSE"
        style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = FFMatchBackground();
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.tintColor = FFMatchGold();

    _rootScroll = [UIScrollView new];
    _rootScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _rootScroll.alwaysBounceVertical = YES;
    [self.view addSubview:_rootScroll];

    _rootStack = [UIStackView new];
    _rootStack.axis = UILayoutConstraintAxisVertical;
    _rootStack.spacing = 14;
    _rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_rootScroll addSubview:_rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [_rootScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_rootScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_rootScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_rootScroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_rootStack.leadingAnchor constraintEqualToAnchor:_rootScroll.leadingAnchor constant:18],
        [_rootStack.trailingAnchor constraintEqualToAnchor:_rootScroll.trailingAnchor constant:-18],
        [_rootStack.topAnchor constraintEqualToAnchor:_rootScroll.topAnchor constant:16],
        [_rootStack.bottomAnchor constraintEqualToAnchor:_rootScroll.bottomAnchor constant:-24],
        [_rootStack.widthAnchor constraintEqualToAnchor:_rootScroll.widthAnchor constant:-36],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(stateDidChange:)
        name:FFMatchStateDidChangeNotification object:nil];
    [self buildInterface];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildInterface {
    [self rebuildContent];
}

- (void)rebuildContent {
    NSArray<UIView *> *existing = [_rootStack.arrangedSubviews copy];
    for (UIView *view in existing) {
        [_rootStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self buildContent];
}

- (void)stateDidChange:(NSNotification *)notification {
    (void)notification;
    [self rebuildContent];
}

- (void)buildContent {
    FFMatchStateManager *manager = [FFMatchStateManager sharedManager];
    FFMatchState state = manager.currentState;
    UIColor *stateColor = [self colorForState:state];

    // Header
    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisVertical;
    header.spacing = 7;
    UIStackView *titleRow = [UIStackView new];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.alignment = UIStackViewAlignmentCenter;
    titleRow.spacing = 8;
    [titleRow addArrangedSubview:[self labelWithText:@"MATCH STATE"
        font:[UIFont monospacedSystemFontOfSize:23 weight:UIFontWeightHeavy]
        color:FFMatchGold()]];
    UILabel *appLocal = [self labelWithText:@"APP-LOCAL"
        font:[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold]
        color:UIColor.blackColor];
    appLocal.textAlignment = NSTextAlignmentCenter;
    appLocal.backgroundColor = FFMatchCyan();
    appLocal.layer.cornerRadius = 6;
    appLocal.layer.cornerCurve = kCACornerCurveContinuous;
    appLocal.clipsToBounds = YES;
    [appLocal.widthAnchor constraintEqualToConstant:72].active = YES;
    [appLocal.heightAnchor constraintEqualToConstant:20].active = YES;
    [titleRow addArrangedSubview:appLocal];
    UIView *headerSpacer = [UIView new];
    [headerSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];
    [titleRow addArrangedSubview:headerSpacer];
    [header addArrangedSubview:titleRow];
    [header addArrangedSubview:[self labelWithText:
        @"Trusted event interface for NOT_START / START / END / UNKNOWN. Every transition is timestamped and logged."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.66]]];
    [_rootStack addArrangedSubview:[self cardWithContent:header]];

    // Current state
    UIStackView *status = [UIStackView new];
    status.axis = UILayoutConstraintAxisVertical;
    status.spacing = 10;
    [status addArrangedSubview:[self labelWithText:@"CURRENT STATE"
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold]
        color:UIColor.secondaryLabelColor]];
    [status addArrangedSubview:[self labelWithText:FFMatchStateName(state)
        font:[UIFont monospacedSystemFontOfSize:36 weight:UIFontWeightHeavy]
        color:stateColor]];
    [status addArrangedSubview:[self informationRow:@"SOURCE"
        value:FFMatchStateSourceName(manager.source)]];
    [status addArrangedSubview:[self informationRow:@"REASON"
        value:manager.reason.length ? manager.reason : @"No trusted event"]];
    [status addArrangedSubview:[self informationRow:@"LAST TRANSITION (SESSION)"
        value:manager.lastTransitionDate ? [self timestampText:manager.lastTransitionDate] : @"—"]];
    [status addArrangedSubview:[self informationRow:@"GAME"
        value:_gameIdentifier.length ? _gameIdentifier : @"—"]];
    [status addArrangedSubview:[self labelWithText:
        @"The current state starts as UNKNOWN on every app launch. The transition log below is stored locally and survives relaunches."
        font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.55]]];
    [_rootStack addArrangedSubview:[self cardWithContent:status]];

    // Automatic detection warning
    UIStackView *warning = [UIStackView new];
    warning.axis = UILayoutConstraintAxisVertical;
    warning.spacing = 7;
    [warning addArrangedSubview:[self labelWithText:@"AUTOMATIC DETECTION: NOT VERIFIED"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFMatchRed()]];
    [warning addArrangedSubview:[self labelWithText:
        @"HTTP 206 traffic, POST 200 bursts and UDP server changes from the VPN capture are not used as match signals. They were not proven to mark START or END."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.72]]];
    [warning addArrangedSubview:[self labelWithText:
        @"The state below changes only when this app records a manual or authorized event."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
        color:FFMatchOrange()]];
    [_rootStack addArrangedSubview:[self cardWithContent:warning]];

    // Manual controls
    UIStackView *controls = [UIStackView new];
    controls.axis = UILayoutConstraintAxisVertical;
    controls.spacing = 9;
    [controls addArrangedSubview:[self sectionTitle:@"TRUSTED EVENTS"]];
    [controls addArrangedSubview:[self labelWithText:
        @"Use these controls only while observing the real match. Each press records the current time and a manual reason."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.62]]];
    UIButton *notStart = [self stateButton:@"NOT_START  —  LOBBY" color:FFMatchCyan()
        selector:@selector(markNotStart)];
    notStart.accessibilityIdentifier = @"match_state_not_start";
    [controls addArrangedSubview:notStart];
    UIButton *start = [self stateButton:@"START  —  MATCH ENTERED" color:FFMatchGreen()
        selector:@selector(markStart)];
    start.accessibilityIdentifier = @"match_state_start";
    [controls addArrangedSubview:start];
    UIButton *end = [self stateButton:@"END  —  MATCH FINISHED" color:FFMatchGold()
        selector:@selector(markEnd)];
    end.accessibilityIdentifier = @"match_state_end";
    [controls addArrangedSubview:end];
    UIButton *reset = [self stateButton:@"RESET  —  UNKNOWN" color:FFMatchGray()
        selector:@selector(resetUnknown)];
    reset.accessibilityIdentifier = @"match_state_reset";
    [controls addArrangedSubview:reset];
    if (_feedbackText.length) {
        [controls addArrangedSubview:[self labelWithText:_feedbackText
            font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold]
            color:FFMatchCyan()]];
    }
    [_rootStack addArrangedSubview:[self cardWithContent:controls]];

    // Transition log
    UIStackView *log = [UIStackView new];
    log.axis = UILayoutConstraintAxisVertical;
    log.spacing = 9;
    [log addArrangedSubview:[self sectionTitle:@"TRANSITION LOG"]];
    NSArray<NSDictionary *> *history = manager.history;
    if (!history.count) {
        [log addArrangedSubview:[self labelWithText:@"NO TRANSITIONS RECORDED"
            font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold]
            color:UIColor.secondaryLabelColor]];
    } else {
        NSInteger shown = 0;
        for (NSDictionary *entry in [history reverseObjectEnumerator]) {
            if (shown >= 20) break;
            NSDate *date = entry[@"timestamp"];
            NSInteger entryState = [entry[@"state_value"] integerValue];
            NSString *line = [NSString stringWithFormat:@"%@  %@  [%@]\n%@",
                date ? [self timestampText:date] : @"—",
                entry[@"state"] ?: @"UNKNOWN",
                entry[@"source"] ?: @"UNKNOWN",
                entry[@"reason"] ?: @""];
            UILabel *row = [self labelWithText:line
                font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular]
                color:[self colorForState:(FFMatchState)entryState]];
            [log addArrangedSubview:row];
            shown += 1;
        }
        [log addArrangedSubview:[self labelWithText:
            [NSString stringWithFormat:@"Showing %ld of %lu stored transitions.",
                (long)MIN((NSInteger)history.count, 20), (unsigned long)history.count]
            font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
            color:UIColor.secondaryLabelColor]];
    }
    [_rootStack addArrangedSubview:[self cardWithContent:log]];

    // Capture evidence reference
    UIStackView *evidence = [UIStackView new];
    evidence.axis = UILayoutConstraintAxisVertical;
    evidence.spacing = 7;
    [evidence addArrangedSubview:[self sectionTitle:@"CAPTURE EVIDENCE — REFERENCE ONLY"]];
    [evidence addArrangedSubview:[self informationRow:@"CAPTURE" value:@"match_vpn_4.mitm"]];
    [evidence addArrangedSubview:[self informationRow:@"DATE" value:@"2026-11-08"]];
    [evidence addArrangedSubview:[self informationRow:@"LABELED WINDOW"
        value:@"16:11:30.900 → 16:11:51.210 → 16:12:02.320"]];
    [evidence addArrangedSubview:[self informationRow:@"HTTP / DNS / UDP FLOWS"
        value:@"182 / 85 / 2"]];
    [evidence addArrangedSubview:[self labelWithText:
        @"Endpoints are intentionally not embedded: observed IP addresses and ports change between sessions and are not state signals. Capture gaps (QUIC, IndexError) mean some packets may be missing."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.62]]];
    [_rootStack addArrangedSubview:[self cardWithContent:evidence]];

    // Validation status
    UIStackView *validation = [UIStackView new];
    validation.axis = UILayoutConstraintAxisVertical;
    validation.spacing = 6;
    [validation addArrangedSubview:[self sectionTitle:@"VALIDATION STATUS"]];
    [validation addArrangedSubview:[self labelWithText:@"NOT RUN ON DEVICE"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFMatchOrange()]];
    [validation addArrangedSubview:[self labelWithText:
        @"Required before any automatic claim: multiple matches, false-positive/false-negative measurement, and timing comparison against the real match clock."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.66]]];
    [_rootStack addArrangedSubview:[self cardWithContent:validation]];

    UIButton *copy = [self actionButton:@"COPY JSON SNAPSHOT" color:FFMatchCyan()
        selector:@selector(copySnapshot)];
    [copy setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_rootStack addArrangedSubview:copy];

    [_rootStack addArrangedSubview:[self labelWithText:
        @"Match State is app-local. It does not read Free Fire traffic, modify another app, or bypass the iOS sandbox."
        font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.45]]];
}

#pragma mark - Actions

- (void)markNotStart {
    [self recordState:FFMatchStateNotStart label:@"NOT_START"];
}

- (void)markStart {
    [self recordState:FFMatchStateStart label:@"START"];
}

- (void)markEnd {
    [self recordState:FFMatchStateEnd label:@"END"];
}

- (void)resetUnknown {
    [self recordState:FFMatchStateUnknown label:@"UNKNOWN"];
}

- (void)recordState:(FFMatchState)state label:(NSString *)label {
    FFMatchStateManager *manager = [FFMatchStateManager sharedManager];
    BOOL changed = manager.currentState != state ||
        manager.source != FFMatchStateSourceManual;
    _feedbackText = [NSString stringWithFormat:@"RECORDED %@ — %@",
        label, [self timestampText:[NSDate date]]];
    [manager transitionToState:state
        reason:[NSString stringWithFormat:@"Manual operator action: %@", label]
        source:FFMatchStateSourceManual];
    if (!changed) {
        _feedbackText = [NSString stringWithFormat:@"NO CHANGE — already %@", label];
        [self rebuildContent];
    }
}

- (void)copySnapshot {
    NSDictionary *snapshot = [[FFMatchStateManager sharedManager] snapshot];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot
        options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || error) {
        _feedbackText = @"SNAPSHOT COPY FAILED";
        [self rebuildContent];
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = json ?: @"";
    _feedbackText = @"JSON SNAPSHOT COPIED";
    [self rebuildContent];
}

#pragma mark - Helpers

- (UIColor *)colorForState:(FFMatchState)state {
    switch (state) {
        case FFMatchStateNotStart: return FFMatchCyan();
        case FFMatchStateStart: return FFMatchGreen();
        case FFMatchStateEnd: return FFMatchGold();
        case FFMatchStateUnknown:
        default: return FFMatchGray();
    }
}

- (NSString *)timestampText:(NSDate *)date {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone localTimeZone];
    return [formatter stringFromDate:date];
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
    card.backgroundColor = FFMatchPanel();
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [FFMatchGold() colorWithAlphaComponent:0.25].CGColor;
    card.layer.shadowColor = FFMatchGold().CGColor;
    card.layer.shadowOpacity = 0.10;
    card.layer.shadowRadius = 14;
    card.layer.shadowOffset = CGSizeZero;
    [card addSubview:content];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:15],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15],
    ]];
    return card;
}

- (UIButton *)actionButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor = color;
    button.layer.cornerRadius = 13;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = color.CGColor;
    button.layer.shadowOpacity = 0.35;
    button.layer.shadowRadius = 9;
    button.layer.shadowOffset = CGSizeZero;
    button.contentEdgeInsets = UIEdgeInsetsMake(13, 16, 13, 16);
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)stateButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
    UIButton *button = [self actionButton:title color:color selector:selector];
    if (CGColorGetAlpha(color.CGColor) > 0.5) {
        UIColor *luminance = color;
        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
        if ([luminance getRed:&red green:&green blue:&blue alpha:&alpha] &&
            (red * 0.299 + green * 0.587 + blue * 0.114) > 0.62) {
            [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        }
    }
    return button;
}

- (UIView *)informationRow:(NSString *)title value:(NSString *)value {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 12;
    UILabel *left = [self labelWithText:title
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]
        color:UIColor.secondaryLabelColor];
    UILabel *right = [self labelWithText:value.length ? value : @"—"
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightBold]
        color:UIColor.labelColor];
    right.textAlignment = NSTextAlignmentRight;
    [right setContentCompressionResistancePriority:UILayoutPriorityRequired
        forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:left];
    [row addArrangedSubview:right];
    return row;
}

- (UIView *)sectionTitle:(NSString *)title {
    return [self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold]
        color:FFMatchGold()];
}

@end
