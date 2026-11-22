#import "FFDarkViewController.h"
#import "FFDarkConfig.h"
#import "FFDarkPreviewView.h"
#import "FFDarkSupport.h"

typedef NS_ENUM(NSInteger, FFDarkSection) {
    FFDarkSectionBoard = 0,
    FFDarkSectionESP,
    FFDarkSectionAim,
    FFDarkSectionDisplay,
};

typedef NS_ENUM(NSInteger, FFDarkControlTag) {
    FFDarkControlMaster = 200,
    FFDarkControlBoardEnabled,
    FFDarkControlBoardFPS,
    FFDarkControlBoardPing,
    FFDarkControlBoardClock,
    FFDarkControlBoardOpacity,
    FFDarkControlBoardScale,
    FFDarkControlBoardStyle,
    FFDarkControlBoardPosition,
    FFDarkControlESPEnabled,
    FFDarkControlESPBoxes,
    FFDarkControlESPSkeleton,
    FFDarkControlESPNames,
    FFDarkControlESPDistance,
    FFDarkControlESPHealth,
    FFDarkControlESPTeamCheck,
    FFDarkControlESPSnaplines,
    FFDarkControlESPMaxDistance,
    FFDarkControlESPOpacity,
    FFDarkControlAimEnabled,
    FFDarkControlAimBot,
    FFDarkControlAimFOV,
    FFDarkControlAimSmoothing,
    FFDarkControlAimTarget,
    FFDarkControlAimVisibility,
    FFDarkControlAimAutoFire,
    FFDarkControlAimSensitivity,
    FFDarkControlDisplayScale,
    FFDarkControlDisplayOpacity,
    FFDarkControlDisplayAccent,
    FFDarkControlDisplayLanguage,
    FFDarkControlDisplayCompatBadge,
    FFDarkControlDisplayGrid,
    FFDarkControlDisplayScanlines,
};

@interface FFDarkViewController ()
- (void)dismissSelf;
- (void)buildInterface;
- (UIView *)buildHeaderCard;
- (void)rebuildSection;
- (void)buildBoardSection;
- (void)buildESPSection;
- (void)buildAimSection;
- (void)buildDisplaySection;
- (void)sectionChanged:(UISegmentedControl *)sender;
- (UIView *)cardWithContent:(UIView *)content;
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color;
- (UIView *)informationRow:(NSString *)title value:(NSString *)value;
- (UIView *)bulletRow:(NSString *)text;
- (UIView *)switchRow:(NSString *)title subtitle:(NSString *)subtitle
                  tag:(NSInteger)tag on:(BOOL)on;
- (UIView *)aimBotRow;
- (UIView *)sliderRow:(NSString *)title subtitle:(NSString *)subtitle
                  tag:(NSInteger)tag value:(CGFloat)value minimum:(CGFloat)minimum
              maximum:(CGFloat)maximum;
- (UIView *)segmentRow:(NSString *)title items:(NSArray<NSString *> *)items
                   tag:(NSInteger)tag selected:(NSInteger)selected;
- (void)switchChanged:(UISwitch *)sender;
- (void)sliderChanged:(UISlider *)sender;
- (void)segmentChanged:(UISegmentedControl *)sender;
- (void)savePressed;
- (void)applyPressed;
- (void)installPressed;
- (void)resetPressed;
- (void)persistAndRefresh;
- (void)refreshPreview;
- (NSString *)valueTextForTag:(NSInteger)tag value:(CGFloat)value;
@end

static UIColor *FFDarkBackground(void) {
    return [UIColor colorWithRed:0.035 green:0.045 blue:0.060 alpha:1.0];
}

static UIColor *FFDarkPanel(void) {
    return [UIColor colorWithRed:0.075 green:0.085 blue:0.105 alpha:1.0];
}

static UIColor *FFDarkGold(void) {
    return [UIColor colorWithRed:1.00 green:0.78 blue:0.24 alpha:1.0];
}

static UIColor *FFDarkCyan(void) {
    return [UIColor colorWithRed:0.20 green:0.90 blue:0.96 alpha:1.0];
}

static UIColor *FFDarkRed(void) {
    return [UIColor colorWithRed:1.00 green:0.32 blue:0.32 alpha:1.0];
}

static UIColor *FFDarkGreen(void) {
    return [UIColor colorWithRed:0.30 green:1.00 blue:0.52 alpha:1.0];
}

@implementation FFDarkViewController {
    FFDarkConfig *_config;
    NSDictionary<NSString *, id> *_report;
    NSString *_gameIdentifier;
    BOOL _licenseActive;
    FFDarkSection _section;
    UIScrollView *_rootScroll;
    UIStackView *_rootStack;
    UIStackView *_sectionStack;
    UISegmentedControl *_sectionControl;
    FFDarkPreviewView *_preview;
    UILabel *_savedLabel;
    NSMutableDictionary<NSNumber *, UILabel *> *_sliderValueLabels;
    BOOL _floatingButtonVisible;
}

- (instancetype)initWithGameIdentifier:(NSString *)gameIdentifier licenseActive:(BOOL)licenseActive {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _gameIdentifier = [gameIdentifier copy];
        _licenseActive = licenseActive;
        _section = FFDarkSectionBoard;
        _config = [FFDarkConfig loadConfig];
        _report = FFDarkSupportReport(gameIdentifier, licenseActive);
        _sliderValueLabels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DARK";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = FFDarkBackground();

    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = FFDarkBackground();
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: FFDarkGold(),
        NSFontAttributeName: [UIFont monospacedSystemFontOfSize:17 weight:UIFontWeightHeavy],
    };
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"DONE"
        style:UIBarButtonItemStyleDone target:self action:@selector(dismissSelf)];
    done.tintColor = FFDarkGold();
    self.navigationItem.rightBarButtonItem = done;

    [self buildInterface];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildInterface {
    [_rootScroll removeFromSuperview];
    _rootScroll = [UIScrollView new];
    _rootScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _rootScroll.alwaysBounceVertical = YES;
    _rootScroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_rootScroll];
    [NSLayoutConstraint activateConstraints:@[
        [_rootScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_rootScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_rootScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_rootScroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    _rootStack = [UIStackView new];
    _rootStack.axis = UILayoutConstraintAxisVertical;
    _rootStack.spacing = 14;
    _rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_rootScroll addSubview:_rootStack];
    [NSLayoutConstraint activateConstraints:@[
        [_rootStack.leadingAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.leadingAnchor
            constant:16],
        [_rootStack.trailingAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.trailingAnchor
            constant:-16],
        [_rootStack.topAnchor constraintEqualToAnchor:_rootScroll.contentLayoutGuide.topAnchor
            constant:16],
        [_rootStack.bottomAnchor constraintEqualToAnchor:_rootScroll.contentLayoutGuide.bottomAnchor
            constant:-28],
        [_rootStack.widthAnchor constraintEqualToAnchor:_rootScroll.frameLayoutGuide.widthAnchor
            constant:-32],
    ]];

    [_rootStack addArrangedSubview:[self buildHeaderCard]];

    _sectionControl = [[UISegmentedControl alloc] initWithItems:
        @[@"M BOARD", @"ESP", @"AIM", @"DISPLAY"]];
    _sectionControl.selectedSegmentIndex = _section;
    _sectionControl.selectedSegmentTintColor = FFDarkGold();
    _sectionControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    _sectionControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_sectionControl addTarget:self action:@selector(sectionChanged:)
              forControlEvents:UIControlEventValueChanged];
    [_rootStack addArrangedSubview:_sectionControl];

    _preview = [[FFDarkPreviewView alloc] initWithFrame:CGRectZero];
    _preview.config = _config;
    _preview.compatibilityBadgeText = @"IN-GAME READY";
    _preview.translatesAutoresizingMaskIntoConstraints = NO;
    [_preview.heightAnchor constraintEqualToConstant:208].active = YES;
    [_rootStack addArrangedSubview:_preview];

    UIButton *apply = [UIButton buttonWithType:UIButtonTypeSystem];
    [apply setTitle:@"APPLY & SHOW GLOWING BUTTON" forState:UIControlStateNormal];
    apply.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    [apply setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    apply.backgroundColor = FFDarkCyan();
    apply.layer.cornerRadius = 13;
    apply.layer.cornerCurve = kCACornerCurveContinuous;
    apply.layer.shadowColor = FFDarkCyan().CGColor;
    apply.layer.shadowOpacity = 0.55f;
    apply.layer.shadowRadius = 12.0f;
    apply.layer.shadowOffset = CGSizeZero;
    [apply addTarget:self action:@selector(applyPressed) forControlEvents:UIControlEventTouchUpInside];
    [apply.heightAnchor constraintEqualToConstant:50].active = YES;
    [_rootStack addArrangedSubview:apply];

    UIButton *install = [UIButton buttonWithType:UIButtonTypeSystem];
    [install setTitle:@"HOW TO INSTALL THE DARK FREE FIRE IPA" forState:UIControlStateNormal];
    install.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [install setTitleColor:FFDarkCyan() forState:UIControlStateNormal];
    install.backgroundColor = [FFDarkCyan() colorWithAlphaComponent:0.10];
    install.layer.cornerRadius = 11;
    [install addTarget:self action:@selector(installPressed) forControlEvents:UIControlEventTouchUpInside];
    [install.heightAnchor constraintEqualToConstant:40].active = YES;
    [_rootStack addArrangedSubview:install];

    _sectionStack = [UIStackView new];
    _sectionStack.axis = UILayoutConstraintAxisVertical;
    _sectionStack.spacing = 12;
    [_rootStack addArrangedSubview:_sectionStack];
    [self rebuildSection];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"SAVE CONFIG" forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [save setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    save.backgroundColor = FFDarkGold();
    save.layer.cornerRadius = 13;
    save.layer.cornerCurve = kCACornerCurveContinuous;
    [save addTarget:self action:@selector(savePressed) forControlEvents:UIControlEventTouchUpInside];
    [save.heightAnchor constraintEqualToConstant:48].active = YES;
    [_rootStack addArrangedSubview:save];

    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"RESET DEFAULTS" forState:UIControlStateNormal];
    reset.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [reset setTitleColor:FFDarkRed() forState:UIControlStateNormal];
    reset.backgroundColor = [FFDarkRed() colorWithAlphaComponent:0.10];
    reset.layer.cornerRadius = 12;
    [reset addTarget:self action:@selector(resetPressed) forControlEvents:UIControlEventTouchUpInside];
    [reset.heightAnchor constraintEqualToConstant:42].active = YES;
    [_rootStack addArrangedSubview:reset];

    _savedLabel = [self labelWithText:@"COMPANION CONFIG • APPLY PREVIEWS THE IN-GAME BUTTON"
        font:[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightSemibold]
        color:[UIColor colorWithWhite:1.0 alpha:0.45]];
    _savedLabel.textAlignment = NSTextAlignmentCenter;
    [_rootStack addArrangedSubview:_savedLabel];
}

- (UIView *)buildHeaderCard {
    NSMutableArray<UIView *> *rows = [NSMutableArray array];

    UILabel *title = [self labelWithText:@"DARK  //  IN-GAME OVERLAY"
        font:[UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightHeavy]
        color:UIColor.whiteColor];
    [rows addObject:title];
    [rows addObject:[self labelWithText:
        @"Companion config for the DARK Free Fire IPA. Old BODY / DRAG / NECK / CHEST / MAGIC options are untouched."
        font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.62]]];

    UILabel *badge = [self labelWithText:@"IN-GAME READY  •  AIM BOT + ESP"
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightHeavy]
        color:FFDarkGreen()];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = [FFDarkGreen() colorWithAlphaComponent:0.14];
    badge.layer.cornerRadius = 8;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.clipsToBounds = YES;
    [badge.heightAnchor constraintGreaterThanOrEqualToConstant:28].active = YES;
    [rows addObject:badge];

    [rows addObject:[self informationRow:@"IOS" value:_report[@"ios"]]];
    [rows addObject:[self informationRow:@"DEVICE" value:_report[@"device"]]];
    [rows addObject:[self informationRow:@"POLICY" value:_report[@"policy"]]];
    [rows addObject:[self informationRow:@"DARKSWORD" value:_report[@"darksword"]]];
    [rows addObject:[self informationRow:@"3105 KEX" value:_report[@"kernel"]]];
    [rows addObject:[self informationRow:@"GAME" value:_report[@"game"]]];
    [rows addObject:[self informationRow:@"DARK BUILD" value:@"FREE FIRE 1.132.1"]];
    [rows addObject:[self informationRow:@"LICENSE"
        value:[_report[@"license_active"] boolValue] ? @"ACTIVE" : @"ACTIVATE IN-GAME"]];

    UILabel *live = [self labelWithText:
        @"IN-GAME PANEL: the DARK dylib draws AIM / ESP / STYLE / STREAM / LICENSE inside Free Fire. The glowing scope button toggles it."
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold]
        color:FFDarkCyan()];
    live.numberOfLines = 0;
    [rows addObject:live];

    UILabel *disclaimer = [self labelWithText:
        @"This companion app previews and saves the DARK layout. Real AIM/ESP runs only after you install the separately signed DARK Free Fire IPA and activate its license."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightMedium]
        color:[UIColor colorWithWhite:1.0 alpha:0.72]];
    [rows addObject:disclaimer];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    for (UIView *row in rows) [stack addArrangedSubview:row];
    return [self cardWithContent:stack];
}

- (void)rebuildSection {
    for (UIView *view in _sectionStack.arrangedSubviews) {
        [_sectionStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [_sliderValueLabels removeAllObjects];
    switch (_section) {
        case FFDarkSectionBoard: [self buildBoardSection]; break;
        case FFDarkSectionESP: [self buildESPSection]; break;
        case FFDarkSectionAim: [self buildAimSection]; break;
        case FFDarkSectionDisplay: [self buildDisplaySection]; break;
    }
}

- (void)buildBoardSection {
    UILabel *header = [self labelWithText:@"M BOARD LAYOUT"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFDarkGold()];
    [_sectionStack addArrangedSubview:header];
    [_sectionStack addArrangedSubview:[self labelWithText:
        @"Design the in-game M BOARD. This companion renders the layout in the preview; the DARK overlay draws it inside Free Fire."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.58]]];

    UIStackView *master = [UIStackView new];
    master.axis = UILayoutConstraintAxisVertical;
    master.spacing = 10;
    [master addArrangedSubview:[self switchRow:@"DARK MASTER"
        subtitle:@"Enable the DARK preview model" tag:FFDarkControlMaster
        on:_config.masterEnabled]];
    [master addArrangedSubview:[self switchRow:@"M BOARD"
        subtitle:@"Show the board in the preview" tag:FFDarkControlBoardEnabled
        on:_config.boardEnabled]];
    [master addArrangedSubview:[self switchRow:@"FPS COUNTER"
        subtitle:@"Board statistic" tag:FFDarkControlBoardFPS on:_config.boardShowFPS]];
    [master addArrangedSubview:[self switchRow:@"PING COUNTER"
        subtitle:@"Board statistic" tag:FFDarkControlBoardPing on:_config.boardShowPing]];
    [master addArrangedSubview:[self switchRow:@"CLOCK"
        subtitle:@"Board statistic" tag:FFDarkControlBoardClock on:_config.boardShowClock]];
    [_sectionStack addArrangedSubview:[self cardWithContent:master]];

    UIStackView *sliders = [UIStackView new];
    sliders.axis = UILayoutConstraintAxisVertical;
    sliders.spacing = 12;
    [sliders addArrangedSubview:[self sliderRow:@"BOARD OPACITY" subtitle:@"0.35 - 1.00"
        tag:FFDarkControlBoardOpacity value:_config.boardOpacity minimum:0.35 maximum:1.0]];
    [sliders addArrangedSubview:[self sliderRow:@"BOARD SCALE" subtitle:@"0.80x - 1.45x"
        tag:FFDarkControlBoardScale value:_config.boardScale minimum:0.80 maximum:1.45]];
    [_sectionStack addArrangedSubview:[self cardWithContent:sliders]];

    UIStackView *segments = [UIStackView new];
    segments.axis = UILayoutConstraintAxisVertical;
    segments.spacing = 12;
    [segments addArrangedSubview:[self segmentRow:@"STYLE" items:@[@"FULL", @"COMPACT", @"MINIMAL"]
        tag:FFDarkControlBoardStyle selected:_config.boardStyle]];
    [segments addArrangedSubview:[self segmentRow:@"POSITION" items:@[@"TL", @"TR", @"BL", @"BR"]
        tag:FFDarkControlBoardPosition selected:_config.boardPosition]];
    [_sectionStack addArrangedSubview:[self cardWithContent:segments]];
}

- (void)buildESPSection {
    [_sectionStack addArrangedSubview:[self labelWithText:@"ESP PREVIEW"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFDarkCyan()]];
    [_sectionStack addArrangedSubview:[self labelWithText:
        @"Preview of the in-game ESP. Inside Free Fire the DARK dylib draws real targets; this view uses fictional ones."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.58]]];

    UIStackView *toggles = [UIStackView new];
    toggles.axis = UILayoutConstraintAxisVertical;
    toggles.spacing = 10;
    [toggles addArrangedSubview:[self switchRow:@"ESP ENGINE" subtitle:@"Enable the ESP preview"
        tag:FFDarkControlESPEnabled on:_config.espEnabled]];
    [toggles addArrangedSubview:[self switchRow:@"BOXES" subtitle:@"Target rectangles"
        tag:FFDarkControlESPBoxes on:_config.espBoxes]];
    [toggles addArrangedSubview:[self switchRow:@"SKELETON" subtitle:@"Bone lines"
        tag:FFDarkControlESPSkeleton on:_config.espSkeleton]];
    [toggles addArrangedSubview:[self switchRow:@"NAMES" subtitle:@"Target label"
        tag:FFDarkControlESPNames on:_config.espNames]];
    [toggles addArrangedSubview:[self switchRow:@"DISTANCE" subtitle:@"Meters below target"
        tag:FFDarkControlESPDistance on:_config.espDistance]];
    [toggles addArrangedSubview:[self switchRow:@"HEALTH" subtitle:@"Side health bar"
        tag:FFDarkControlESPHealth on:_config.espHealth]];
    [toggles addArrangedSubview:[self switchRow:@"TEAM CHECK" subtitle:@"Hide the ally target"
        tag:FFDarkControlESPTeamCheck on:_config.espTeamCheck]];
    [toggles addArrangedSubview:[self switchRow:@"SNAPLINES" subtitle:@"Lines from screen bottom"
        tag:FFDarkControlESPSnaplines on:_config.espSnaplines]];
    [_sectionStack addArrangedSubview:[self cardWithContent:toggles]];

    UIStackView *sliders = [UIStackView new];
    sliders.axis = UILayoutConstraintAxisVertical;
    sliders.spacing = 12;
    [sliders addArrangedSubview:[self sliderRow:@"MAX DISTANCE" subtitle:@"25 - 300 M"
        tag:FFDarkControlESPMaxDistance value:_config.espMaxDistance minimum:25.0 maximum:300.0]];
    [sliders addArrangedSubview:[self sliderRow:@"ESP OPACITY" subtitle:@"0.30 - 1.00"
        tag:FFDarkControlESPOpacity value:_config.espOpacity minimum:0.30 maximum:1.0]];
    [_sectionStack addArrangedSubview:[self cardWithContent:sliders]];
}

- (void)buildAimSection {
    [_sectionStack addArrangedSubview:[self labelWithText:@"AIM BOT"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFDarkRed()]];
    [_sectionStack addArrangedSubview:[self labelWithText:
        @"AIM BOT runs inside the in-game DARK overlay. These controls mirror the in-game panel; Apply previews the glowing scope button."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.58]]];

    UIStackView *toggles = [UIStackView new];
    toggles.axis = UILayoutConstraintAxisVertical;
    toggles.spacing = 10;
    [toggles addArrangedSubview:[self aimBotRow]];
    [toggles addArrangedSubview:[self switchRow:@"AIM ASSIST" subtitle:@"FOV ring preference"
        tag:FFDarkControlAimEnabled on:_config.aimEnabled]];
    [toggles addArrangedSubview:[self switchRow:@"VISIBILITY CHECK"
        subtitle:@"In-game target filter" tag:FFDarkControlAimVisibility
        on:_config.aimVisibilityCheck]];
    [toggles addArrangedSubview:[self switchRow:@"AUTO FIRE"
        subtitle:@"In-game preference • use with caution" tag:FFDarkControlAimAutoFire
        on:_config.aimAutoFire]];
    [_sectionStack addArrangedSubview:[self cardWithContent:toggles]];

    UIStackView *sliders = [UIStackView new];
    sliders.axis = UILayoutConstraintAxisVertical;
    sliders.spacing = 12;
    [sliders addArrangedSubview:[self sliderRow:@"FOV RADIUS" subtitle:@"30 - 300"
        tag:FFDarkControlAimFOV value:_config.aimFOV minimum:30.0 maximum:300.0]];
    [sliders addArrangedSubview:[self sliderRow:@"SMOOTHING" subtitle:@"0.00 - 0.95"
        tag:FFDarkControlAimSmoothing value:_config.aimSmoothing minimum:0.0 maximum:0.95]];
    [sliders addArrangedSubview:[self sliderRow:@"SENSITIVITY" subtitle:@"0.10 - 2.00"
        tag:FFDarkControlAimSensitivity value:_config.aimSensitivity minimum:0.10 maximum:2.0]];
    [_sectionStack addArrangedSubview:[self cardWithContent:sliders]];

    [_sectionStack addArrangedSubview:[self cardWithContent:[self segmentRow:@"TARGET"
        items:@[@"HEAD", @"CHEST", @"NEAREST"] tag:FFDarkControlAimTarget
        selected:_config.aimTarget]]];
}

- (void)buildDisplaySection {
    [_sectionStack addArrangedSubview:[self labelWithText:@"DISPLAY & LOCALIZATION"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:FFDarkGold()]];
    [_sectionStack addArrangedSubview:[self labelWithText:
        @"Rendering preferences for the companion preview. The in-game panel keeps its own STYLE controls."
        font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.58]]];

    UIStackView *sliders = [UIStackView new];
    sliders.axis = UILayoutConstraintAxisVertical;
    sliders.spacing = 12;
    [sliders addArrangedSubview:[self sliderRow:@"HUD SCALE" subtitle:@"0.75x - 1.50x"
        tag:FFDarkControlDisplayScale value:_config.displayScale minimum:0.75 maximum:1.50]];
    [sliders addArrangedSubview:[self sliderRow:@"HUD OPACITY" subtitle:@"0.40 - 1.00"
        tag:FFDarkControlDisplayOpacity value:_config.displayOpacity minimum:0.40 maximum:1.0]];
    [_sectionStack addArrangedSubview:[self cardWithContent:sliders]];

    UIStackView *segments = [UIStackView new];
    segments.axis = UILayoutConstraintAxisVertical;
    segments.spacing = 12;
    [segments addArrangedSubview:[self segmentRow:@"ACCENT" items:@[@"GOLD", @"CYAN", @"RED", @"GREEN"]
        tag:FFDarkControlDisplayAccent selected:_config.accent]];
    [segments addArrangedSubview:[self segmentRow:@"LANGUAGE" items:@[@"EN", @"AR", @"FR"]
        tag:FFDarkControlDisplayLanguage selected:_config.language]];
    [_sectionStack addArrangedSubview:[self cardWithContent:segments]];

    UIStackView *toggles = [UIStackView new];
    toggles.axis = UILayoutConstraintAxisVertical;
    toggles.spacing = 10;
    [toggles addArrangedSubview:[self switchRow:@"COMPATIBILITY BADGE"
        subtitle:@"Show the verdict inside the preview" tag:FFDarkControlDisplayCompatBadge
        on:_config.displayShowCompatibilityBadge]];
    [toggles addArrangedSubview:[self switchRow:@"GRID" subtitle:@"Preview background grid"
        tag:FFDarkControlDisplayGrid on:_config.displayShowGrid]];
    [toggles addArrangedSubview:[self switchRow:@"SCANLINES" subtitle:@"Preview CRT effect"
        tag:FFDarkControlDisplayScanlines on:_config.displayShowScanlines]];
    [_sectionStack addArrangedSubview:[self cardWithContent:toggles]];

    UIStackView *notes = [UIStackView new];
    notes.axis = UILayoutConstraintAxisVertical;
    notes.spacing = 7;
    [notes addArrangedSubview:[self labelWithText:@"TECHNICAL LIMITS"
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightHeavy]
        color:FFDarkRed()]];
    NSArray<NSString *> *reportNotes = _report[@"notes"];
    NSUInteger limit = MIN(reportNotes.count, (NSUInteger)5);
    for (NSUInteger index = 0; index < limit; index++) {
        [notes addArrangedSubview:[self bulletRow:reportNotes[index]]];
    }
    [_sectionStack addArrangedSubview:[self cardWithContent:notes]];
}

- (void)sectionChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex < FFDarkSectionBoard ||
        sender.selectedSegmentIndex > FFDarkSectionDisplay) return;
    _section = (FFDarkSection)sender.selectedSegmentIndex;
    [self rebuildSection];
}

- (void)switchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case FFDarkControlAimBot: _config.aimBotEnabled = sender.isOn; break;
        case FFDarkControlMaster: _config.masterEnabled = sender.isOn; break;
        case FFDarkControlBoardEnabled: _config.boardEnabled = sender.isOn; break;
        case FFDarkControlBoardFPS: _config.boardShowFPS = sender.isOn; break;
        case FFDarkControlBoardPing: _config.boardShowPing = sender.isOn; break;
        case FFDarkControlBoardClock: _config.boardShowClock = sender.isOn; break;
        case FFDarkControlESPEnabled: _config.espEnabled = sender.isOn; break;
        case FFDarkControlESPBoxes: _config.espBoxes = sender.isOn; break;
        case FFDarkControlESPSkeleton: _config.espSkeleton = sender.isOn; break;
        case FFDarkControlESPNames: _config.espNames = sender.isOn; break;
        case FFDarkControlESPDistance: _config.espDistance = sender.isOn; break;
        case FFDarkControlESPHealth: _config.espHealth = sender.isOn; break;
        case FFDarkControlESPTeamCheck: _config.espTeamCheck = sender.isOn; break;
        case FFDarkControlESPSnaplines: _config.espSnaplines = sender.isOn; break;
        case FFDarkControlAimEnabled: _config.aimEnabled = sender.isOn; break;
        case FFDarkControlAimVisibility: _config.aimVisibilityCheck = sender.isOn; break;
        case FFDarkControlAimAutoFire: _config.aimAutoFire = sender.isOn; break;
        case FFDarkControlDisplayCompatBadge:
            _config.displayShowCompatibilityBadge = sender.isOn; break;
        case FFDarkControlDisplayGrid: _config.displayShowGrid = sender.isOn; break;
        case FFDarkControlDisplayScanlines: _config.displayShowScanlines = sender.isOn; break;
        default: break;
    }
    [self persistAndRefresh];
}

- (void)sliderChanged:(UISlider *)sender {
    CGFloat value = sender.value;
    switch (sender.tag) {
        case FFDarkControlBoardOpacity: _config.boardOpacity = value; break;
        case FFDarkControlBoardScale: _config.boardScale = value; break;
        case FFDarkControlESPMaxDistance: _config.espMaxDistance = value; break;
        case FFDarkControlESPOpacity: _config.espOpacity = value; break;
        case FFDarkControlAimFOV: _config.aimFOV = value; break;
        case FFDarkControlAimSmoothing: _config.aimSmoothing = value; break;
        case FFDarkControlAimSensitivity: _config.aimSensitivity = value; break;
        case FFDarkControlDisplayScale: _config.displayScale = value; break;
        case FFDarkControlDisplayOpacity: _config.displayOpacity = value; break;
        default: break;
    }
    UILabel *valueLabel = _sliderValueLabels[@(sender.tag)];
    valueLabel.text = [self valueTextForTag:sender.tag value:value];
    [self persistAndRefresh];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSInteger selected = sender.selectedSegmentIndex;
    switch (sender.tag) {
        case FFDarkControlBoardStyle:
            _config.boardStyle = (FFDarkBoardStyle)selected; break;
        case FFDarkControlBoardPosition:
            _config.boardPosition = (FFDarkBoardPosition)selected; break;
        case FFDarkControlAimTarget:
            _config.aimTarget = (FFDarkAimTarget)selected; break;
        case FFDarkControlDisplayAccent:
            _config.accent = (FFDarkAccent)selected; break;
        case FFDarkControlDisplayLanguage:
            _config.language = (FFDarkLanguage)selected; break;
        default: break;
    }
    [self persistAndRefresh];
}

- (void)persistAndRefresh {
    [_config clampValues];
    [_config save];
    [self refreshPreview];
}

- (void)refreshPreview {
    _preview.config = _config;
    _preview.compatibilityBadgeText = @"IN-GAME READY";
    _preview.showFloatingButton = _floatingButtonVisible;
    [_preview refresh];
}

- (void)applyPressed {
    [_config clampValues];
    [_config save];
    _floatingButtonVisible = YES;
    [self refreshPreview];
    _savedLabel.text = @"APPLIED • GLOWING AIM BUTTON PREVIEW ENABLED";
    _savedLabel.textColor = FFDarkCyan();

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DARK READY"
        message:@"The glowing AIM button is now previewed. Inside Free Fire the same button is "
                @"created by the DARK dylib: tap the scope icon to open the AIM / ESP / STYLE / "
                @"STREAM / LICENSE panel.\n\nReal AIM/ESP requires the signed DARK Free Fire IPA "
                @"and an active license."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"GOT IT" style:UIAlertActionStyleDefault
        handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"INSTALL STEPS"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action;
            [weakSelf installPressed];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)installPressed {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
        @"INSTALL DARK IN FREE FIRE"
        message:@"1. Re-sign FreeFire_1.132.1_DARK_UNSIGNED.ipa (the whole app, not only the "
                @"dylib) with ESign, Sideloadly or TrollStore.\n\n"
                @"2. Remove any older Free Fire copy with the same bundle id before installing.\n\n"
                @"3. Launch Free Fire, open LICENSE in the DARK panel and activate your FAKHER "
                @"VIP key.\n\n"
                @"4. Tap the glowing scope button to open AIM / ESP / STYLE / STREAM / LICENSE.\n\n"
                @"5. No panel? The game build/UUID or the license does not match; the dylib "
                @"fails closed.\n\n"
                @"Unsigned build + anti-cheat risk: use a test account."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"CLOSE" style:UIAlertActionStyleCancel
        handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)savePressed {
    [_config save];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";
    _savedLabel.text = [NSString stringWithFormat:@"SAVED LOCALLY • %@ • APPLY TO PREVIEW THE BUTTON",
        [formatter stringFromDate:[NSDate date]]];
    _savedLabel.textColor = FFDarkGreen();
    [UIView animateWithDuration:0.18 animations:^{
        self->_savedLabel.alpha = 0.45;
    } completion:^(BOOL finished) {
        (void)finished;
        [UIView animateWithDuration:0.18 animations:^{
            self->_savedLabel.alpha = 1.0;
        }];
    }];
}

- (void)resetPressed {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"RESET DARK?"
        message:@"All local DARK layout and preview settings will return to their defaults."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel
        handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"RESET" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            (void)action;
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf->_config resetToDefaults];
            [strongSelf->_config save];
            strongSelf->_floatingButtonVisible = NO;
            strongSelf->_section = FFDarkSectionBoard;
            strongSelf->_sectionControl.selectedSegmentIndex = FFDarkSectionBoard;
            [strongSelf rebuildSection];
            [strongSelf refreshPreview];
            strongSelf->_savedLabel.text = @"DEFAULTS RESTORED";
            strongSelf->_savedLabel.textColor = FFDarkGold();
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - View helpers

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
    card.backgroundColor = FFDarkPanel();
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    [card addSubview:content];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-13],
    ]];
    return card;
}

- (UIView *)informationRow:(NSString *)title value:(NSString *)value {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;
    UILabel *left = [self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold]
        color:[UIColor colorWithWhite:1.0 alpha:0.48]];
    UILabel *right = [self labelWithText:value.length ? value : @"—"
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold]
        color:[UIColor colorWithWhite:1.0 alpha:0.92]];
    right.textAlignment = NSTextAlignmentRight;
    [right setContentCompressionResistancePriority:UILayoutPriorityRequired
        forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:left];
    [row addArrangedSubview:right];
    return row;
}

- (UIView *)bulletRow:(NSString *)text {
    UILabel *label = [self labelWithText:[NSString stringWithFormat:@"•  %@", text]
        font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.64]];
    return label;
}

- (UIView *)aimBotRow {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;

    UIView *iconBadge = [UIView new];
    iconBadge.backgroundColor = [FFDarkCyan() colorWithAlphaComponent:0.12];
    iconBadge.layer.cornerRadius = 18;
    iconBadge.layer.cornerCurve = kCACornerCurveContinuous;
    iconBadge.layer.borderWidth = 1.2;
    iconBadge.layer.borderColor = [FFDarkCyan() colorWithAlphaComponent:0.8].CGColor;
    iconBadge.layer.shadowColor = FFDarkCyan().CGColor;
    iconBadge.layer.shadowOpacity = 0.55f;
    iconBadge.layer.shadowRadius = 7.0f;
    iconBadge.layer.shadowOffset = CGSizeZero;
    [iconBadge.widthAnchor constraintEqualToConstant:36.0].active = YES;
    [iconBadge.heightAnchor constraintEqualToConstant:36.0].active = YES;

    UIImage *scope = [UIImage systemImageNamed:@"scope"];
    UIView *icon = nil;
    if (scope) {
        UIImageView *image = [[UIImageView alloc] initWithImage:
            [scope imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        image.tintColor = FFDarkCyan();
        image.contentMode = UIViewContentModeScaleAspectFit;
        icon = image;
    } else {
        UILabel *fallback = [UILabel new];
        fallback.text = @"AIM";
        fallback.textAlignment = NSTextAlignmentCenter;
        fallback.textColor = FFDarkCyan();
        fallback.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightHeavy];
        icon = fallback;
    }
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [iconBadge addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:20.0],
        [icon.heightAnchor constraintEqualToConstant:20.0],
    ]];

    UIStackView *labels = [UIStackView new];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 2;
    [labels addArrangedSubview:[self labelWithText:@"AIM BOT"
        font:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightHeavy]
        color:UIColor.whiteColor]];
    [labels addArrangedSubview:[self labelWithText:@"In-game aim assist • DARK overlay"
        font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.50]]];
    [labels setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];

    UISwitch *toggle = [UISwitch new];
    toggle.on = _config.aimBotEnabled;
    toggle.tag = FFDarkControlAimBot;
    toggle.onTintColor = FFDarkCyan();
    [toggle addTarget:self action:@selector(switchChanged:)
        forControlEvents:UIControlEventValueChanged];

    [row addArrangedSubview:iconBadge];
    [row addArrangedSubview:labels];
    [row addArrangedSubview:toggle];
    return row;
}

- (UIView *)switchRow:(NSString *)title subtitle:(NSString *)subtitle
                  tag:(NSInteger)tag on:(BOOL)on {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;

    UIStackView *labels = [UIStackView new];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 2;
    [labels addArrangedSubview:[self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold]
        color:UIColor.whiteColor]];
    [labels addArrangedSubview:[self labelWithText:subtitle
        font:[UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.50]]];
    [labels setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
        forAxis:UILayoutConstraintAxisHorizontal];

    UISwitch *toggle = [UISwitch new];
    toggle.on = on;
    toggle.tag = tag;
    toggle.onTintColor = FFDarkGold();
    [toggle addTarget:self action:@selector(switchChanged:)
        forControlEvents:UIControlEventValueChanged];

    [row addArrangedSubview:labels];
    [row addArrangedSubview:toggle];
    return row;
}

- (UIView *)sliderRow:(NSString *)title subtitle:(NSString *)subtitle
                  tag:(NSInteger)tag value:(CGFloat)value minimum:(CGFloat)minimum
              maximum:(CGFloat)maximum {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisVertical;
    row.spacing = 5;

    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 8;
    UILabel *titleLabel = [self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold]
        color:UIColor.whiteColor];
    UILabel *valueLabel = [self labelWithText:[self valueTextForTag:tag value:value]
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightHeavy]
        color:FFDarkCyan()];
    valueLabel.textAlignment = NSTextAlignmentRight;
    [valueLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
        forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:titleLabel];
    [header addArrangedSubview:valueLabel];
    _sliderValueLabels[@(tag)] = valueLabel;

    UISlider *slider = [UISlider new];
    slider.minimumValue = minimum;
    slider.maximumValue = maximum;
    slider.value = value;
    slider.tag = tag;
    slider.continuous = YES;
    slider.minimumTrackTintColor = FFDarkGold();
    slider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    [slider addTarget:self action:@selector(sliderChanged:)
        forControlEvents:UIControlEventValueChanged];

    [row addArrangedSubview:header];
    [row addArrangedSubview:slider];
    [row addArrangedSubview:[self labelWithText:subtitle
        font:[UIFont systemFontOfSize:9 weight:UIFontWeightRegular]
        color:[UIColor colorWithWhite:1.0 alpha:0.42]]];
    return row;
}

- (UIView *)segmentRow:(NSString *)title items:(NSArray<NSString *> *)items
                   tag:(NSInteger)tag selected:(NSInteger)selected {
    UIStackView *row = [UIStackView new];
    row.axis = UILayoutConstraintAxisVertical;
    row.spacing = 5;
    [row addArrangedSubview:[self labelWithText:title
        font:[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold]
        color:UIColor.whiteColor]];
    UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:items];
    control.selectedSegmentIndex = selected;
    control.tag = tag;
    control.selectedSegmentTintColor = FFDarkGold();
    control.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    [control addTarget:self action:@selector(segmentChanged:)
       forControlEvents:UIControlEventValueChanged];
    [row addArrangedSubview:control];
    return row;
}

- (NSString *)valueTextForTag:(NSInteger)tag value:(CGFloat)value {
    switch (tag) {
        case FFDarkControlBoardOpacity:
        case FFDarkControlESPOpacity:
        case FFDarkControlDisplayOpacity:
            return [NSString stringWithFormat:@"%.0f%%", value * 100.0];
        case FFDarkControlBoardScale:
        case FFDarkControlDisplayScale:
            return [NSString stringWithFormat:@"%.2fx", value];
        case FFDarkControlESPMaxDistance:
        case FFDarkControlAimFOV:
            return [NSString stringWithFormat:@"%.0f", value];
        case FFDarkControlAimSmoothing:
        case FFDarkControlAimSensitivity:
            return [NSString stringWithFormat:@"%.2f", value];
        default:
            return [NSString stringWithFormat:@"%.2f", value];
    }
}

@end
