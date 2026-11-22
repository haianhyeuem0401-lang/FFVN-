#import "FFDarkPreviewView.h"
#import "FFDarkConfig.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *FFDarkAccentColor(FFDarkAccent accent) {
    switch (accent) {
        case FFDarkAccentGold: return [UIColor colorWithRed:1.00 green:0.78 blue:0.24 alpha:1.0];
        case FFDarkAccentCyan: return [UIColor colorWithRed:0.20 green:0.90 blue:0.96 alpha:1.0];
        case FFDarkAccentRed: return [UIColor colorWithRed:1.00 green:0.32 blue:0.32 alpha:1.0];
        case FFDarkAccentGreen: return [UIColor colorWithRed:0.30 green:1.00 blue:0.52 alpha:1.0];
    }
    return UIColor.whiteColor;
}

static NSString *FFDarkPreviewEnemyLabel(FFDarkLanguage language) {
    switch (language) {
        case FFDarkLanguageArabic: return @"عدو";
        case FFDarkLanguageFrench: return @"ENNEMI";
        case FFDarkLanguageEnglish: break;
    }
    return @"ENEMY";
}

static NSString *FFDarkPreviewAllyLabel(FFDarkLanguage language) {
    switch (language) {
        case FFDarkLanguageArabic: return @"فريق";
        case FFDarkLanguageFrench: return @"ALLIÉ";
        case FFDarkLanguageEnglish: break;
    }
    return @"ALLY";
}

static NSString *FFDarkPreviewSimulationLabel(FFDarkLanguage language) {
    switch (language) {
        case FFDarkLanguageArabic: return @"معاينة DARK داخل اللعبة • زر AIM المتوهج";
        case FFDarkLanguageFrench: return @"APERÇU DARK EN JEU • BOUTON AIM LUMINEUX";
        case FFDarkLanguageEnglish: break;
    }
    return @"DARK IN-GAME PREVIEW • GLOWING AIM BUTTON";
}

static void FFDarkDrawText(NSString *text, CGRect rect, UIFont *font, UIColor *color,
                           NSTextAlignment alignment) {
    if (!text.length || rect.size.width <= 0 || rect.size.height <= 0) return;
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = alignment;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: paragraph,
    };
    [text drawInRect:rect withAttributes:attributes];
}

static void FFDarkFillRoundedRect(CGRect rect, CGFloat radius, UIColor *color) {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    [color setFill];
    [path fill];
}

static void FFDarkStrokeRoundedRect(CGRect rect, CGFloat radius, UIColor *color, CGFloat width) {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    path.lineWidth = width;
    [color setStroke];
    [path stroke];
}

@implementation FFDarkPreviewView {
    UIView *_floatingButton;
    BOOL _showFloatingButton;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _config = [FFDarkConfig new];
        self.backgroundColor = [UIColor colorWithWhite:0.035 alpha:1.0];
        self.contentMode = UIViewContentModeRedraw;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO;
        self.layer.cornerRadius = 18;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        [self buildFloatingButton];
    }
    return self;
}

- (void)buildFloatingButton {
    _floatingButton = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
    _floatingButton.hidden = YES;
    _floatingButton.userInteractionEnabled = NO;
    _floatingButton.backgroundColor = [UIColor colorWithRed:0.012 green:0.015
        blue:0.035 alpha:0.96];
    _floatingButton.layer.cornerRadius = 23;
    _floatingButton.layer.cornerCurve = kCACornerCurveContinuous;
    _floatingButton.layer.borderWidth = 1.8;
    _floatingButton.layer.borderColor = [UIColor colorWithRed:0.12 green:0.88
        blue:1.0 alpha:0.96].CGColor;
    _floatingButton.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.80
        blue:1.0 alpha:1.0].CGColor;
    _floatingButton.layer.shadowOpacity = 0.85f;
    _floatingButton.layer.shadowRadius = 10.0f;
    _floatingButton.layer.shadowOffset = CGSizeZero;

    UIView *icon = nil;
    UIImage *scope = [UIImage systemImageNamed:@"scope"];
    if (scope) {
        UIImageView *image = [[UIImageView alloc] initWithImage:
            [scope imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        image.tintColor = UIColor.whiteColor;
        image.contentMode = UIViewContentModeScaleAspectFit;
        icon = image;
    } else {
        UILabel *fallback = [UILabel new];
        fallback.text = @"AIM";
        fallback.textAlignment = NSTextAlignmentCenter;
        fallback.textColor = UIColor.whiteColor;
        fallback.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightHeavy];
        icon = fallback;
    }
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [_floatingButton addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:_floatingButton.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:_floatingButton.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:23.0],
        [icon.heightAnchor constraintEqualToConstant:23.0],
    ]];
    [self addSubview:_floatingButton];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    _floatingButton.frame = CGRectMake(width - 18.0 - 46.0, height * 0.50 - 23.0,
        46.0, 46.0);
}

- (void)setConfig:(FFDarkConfig *)config {
    _config = config ?: [FFDarkConfig new];
    [self setNeedsDisplay];
}

- (void)setShowFloatingButton:(BOOL)showFloatingButton {
    _showFloatingButton = showFloatingButton;
    _floatingButton.hidden = !showFloatingButton;
    if (showFloatingButton) {
        [self startFloatingGlow];
    } else {
        [_floatingButton.layer removeAnimationForKey:@"dark.glowRadius"];
        [_floatingButton.layer removeAnimationForKey:@"dark.glowOpacity"];
        [_floatingButton.layer removeAnimationForKey:@"dark.glowScale"];
    }
}

- (void)startFloatingGlow {
    CALayer *layer = _floatingButton.layer;
    if ([layer animationForKey:@"dark.glowRadius"]) return;

    CABasicAnimation *radius = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    radius.fromValue = @7.0;
    radius.toValue = @17.0;
    radius.duration = 1.35;
    radius.autoreverses = YES;
    radius.repeatCount = HUGE_VALF;
    radius.timingFunction = [CAMediaTimingFunction functionWithName:
        kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:radius forKey:@"dark.glowRadius"];

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    opacity.fromValue = @0.45;
    opacity.toValue = @1.0;
    opacity.duration = 1.35;
    opacity.autoreverses = YES;
    opacity.repeatCount = HUGE_VALF;
    [layer addAnimation:opacity forKey:@"dark.glowOpacity"];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @1.0;
    scale.toValue = @1.08;
    scale.duration = 1.35;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:
        kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:scale forKey:@"dark.glowScale"];
}

- (void)refresh {
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;

    FFDarkConfig *config = _config ?: [FFDarkConfig new];
    UIColor *accent = FFDarkAccentColor(config.accent);
    CGRect bounds = self.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat hudScale = config.displayScale;
    CGFloat baseAlpha = config.displayOpacity;

    [self.backgroundColor setFill];
    UIRectFill(bounds);

    // Simulated scene: a horizon, simple geometry and a ground plane.  This is
    // intentionally abstract so it cannot be mistaken for a game capture.
    CGContextSaveGState(context);
    CGContextSetAlpha(context, baseAlpha);
    UIBezierPath *sky = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, width, height * 0.55)];
    [[UIColor colorWithRed:0.05 green:0.09 blue:0.14 alpha:1.0] setFill];
    [sky fill];
    UIBezierPath *ground = [UIBezierPath bezierPathWithRect:
        CGRectMake(0, height * 0.55, width, height * 0.45)];
    [[UIColor colorWithRed:0.04 green:0.06 blue:0.07 alpha:1.0] setFill];
    [ground fill];

    if (config.displayShowGrid) {
        [[UIColor colorWithWhite:0.35 alpha:0.18] setStroke];
        for (CGFloat x = 0; x <= width; x += 34.0) {
            UIBezierPath *line = [UIBezierPath bezierPath];
            [line moveToPoint:CGPointMake(x, 0)];
            [line addLineToPoint:CGPointMake(x, height)];
            line.lineWidth = 0.5;
            [line stroke];
        }
        for (CGFloat y = 0; y <= height; y += 34.0) {
            UIBezierPath *line = [UIBezierPath bezierPath];
            [line moveToPoint:CGPointMake(0, y)];
            [line addLineToPoint:CGPointMake(width, y)];
            line.lineWidth = 0.5;
            [line stroke];
        }
    }

    // Horizon glow.
    UIBezierPath *horizon = [UIBezierPath bezierPath];
    [horizon moveToPoint:CGPointMake(0, height * 0.55)];
    [horizon addLineToPoint:CGPointMake(width, height * 0.55)];
    horizon.lineWidth = 1.0;
    [[accent colorWithAlphaComponent:0.35] setStroke];
    [horizon stroke];

    if (config.displayShowScanlines) {
        for (CGFloat y = 0; y < height; y += 4.0) {
            [[UIColor colorWithWhite:0 alpha:0.16] setFill];
            UIRectFill(CGRectMake(0, y, width, 1.0));
        }
    }

    CGFloat centerX = width * 0.52;
    CGFloat centerY = height * 0.62;
    CGFloat targetScale = hudScale;
    NSArray<NSDictionary *> *targets = @[
        @{@"x": @0.30, @"y": @0.48, @"w": @0.13, @"h": @0.25, @"distance": @32, @"ally": @NO},
        @{@"x": @0.61, @"y": @0.55, @"w": @0.11, @"h": @0.21, @"distance": @58, @"ally": @NO},
        @{@"x": @0.46, @"y": @0.58, @"w": @0.10, @"h": @0.18, @"distance": @21, @"ally": @YES},
    ];

    if (config.espEnabled && config.masterEnabled) {
        UIColor *enemyColor = [UIColor colorWithRed:1.0 green:0.34 blue:0.34 alpha:config.espOpacity];
        UIColor *allyColor = [UIColor colorWithRed:0.32 green:1.0 blue:0.52 alpha:config.espOpacity];
        for (NSDictionary *target in targets) {
            BOOL ally = [target[@"ally"] boolValue];
            NSInteger distance = [target[@"distance"] integerValue];
            if (ally && config.espTeamCheck) continue;
            if ((CGFloat)distance > config.espMaxDistance) continue;
            CGFloat x = width * [target[@"x"] doubleValue];
            CGFloat y = height * [target[@"y"] doubleValue];
            CGFloat w = width * [target[@"w"] doubleValue] * targetScale;
            CGFloat h = height * [target[@"h"] doubleValue] * targetScale;
            CGRect box = CGRectMake(x - w * 0.5, y - h * 0.5, w, h);
            UIColor *color = ally ? allyColor : enemyColor;

            if (config.espSnaplines) {
                UIBezierPath *snap = [UIBezierPath bezierPath];
                [snap moveToPoint:CGPointMake(centerX, height - 8.0)];
                [snap addLineToPoint:CGPointMake(CGRectGetMidX(box), CGRectGetMaxY(box))];
                snap.lineWidth = 1.0;
                [color setStroke];
                [snap stroke];
            }
            if (config.espBoxes) {
                UIBezierPath *path = [UIBezierPath bezierPathWithRect:box];
                path.lineWidth = 1.6;
                [color setStroke];
                [path stroke];
                // Corner ticks give the box a HUD-like silhouette.
                CGFloat tick = MIN(8.0, w * 0.25);
                UIBezierPath *ticks = [UIBezierPath bezierPath];
                [ticks moveToPoint:CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box) + tick)];
                [ticks addLineToPoint:CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMinX(box) + tick, CGRectGetMinY(box))];
                [ticks moveToPoint:CGPointMake(CGRectGetMaxX(box) - tick, CGRectGetMinY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box) + tick)];
                [ticks moveToPoint:CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box) - tick)];
                [ticks addLineToPoint:CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMinX(box) + tick, CGRectGetMaxY(box))];
                [ticks moveToPoint:CGPointMake(CGRectGetMaxX(box) - tick, CGRectGetMaxY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box))];
                [ticks addLineToPoint:CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box) - tick)];
                ticks.lineWidth = 2.0;
                [ticks stroke];
            }
            if (config.espSkeleton) {
                UIBezierPath *bones = [UIBezierPath bezierPath];
                CGFloat midX = CGRectGetMidX(box);
                CGFloat top = CGRectGetMinY(box) + h * 0.15;
                CGFloat shoulder = CGRectGetMinY(box) + h * 0.34;
                CGFloat hip = CGRectGetMinY(box) + h * 0.62;
                CGFloat bottom = CGRectGetMaxY(box) - h * 0.06;
                [bones moveToPoint:CGPointMake(midX, top)];
                [bones addLineToPoint:CGPointMake(midX, hip)];
                [bones moveToPoint:CGPointMake(midX - w * 0.25, shoulder)];
                [bones addLineToPoint:CGPointMake(midX + w * 0.25, shoulder)];
                [bones moveToPoint:CGPointMake(midX - w * 0.18, hip)];
                [bones addLineToPoint:CGPointMake(midX - w * 0.30, bottom)];
                [bones moveToPoint:CGPointMake(midX + w * 0.18, hip)];
                [bones addLineToPoint:CGPointMake(midX + w * 0.30, bottom)];
                bones.lineWidth = 1.0;
                [[color colorWithAlphaComponent:0.75] setStroke];
                [bones stroke];
            }
            if (config.espHealth) {
                CGRect healthBack = CGRectMake(CGRectGetMinX(box) - 6.0, CGRectGetMinY(box),
                    2.5, CGRectGetHeight(box));
                [[UIColor colorWithWhite:0.0 alpha:0.55] setFill];
                UIRectFill(healthBack);
                CGRect healthFill = CGRectMake(CGRectGetMinX(box) - 6.0,
                    CGRectGetMinY(box) + CGRectGetHeight(box) * 0.35,
                    2.5, CGRectGetHeight(box) * 0.65);
                [color setFill];
                UIRectFill(healthFill);
            }
            NSString *name = ally ? FFDarkPreviewAllyLabel(config.language)
                                  : FFDarkPreviewEnemyLabel(config.language);
            if (config.espNames) {
                CGRect nameRect = CGRectMake(CGRectGetMinX(box) - 8.0,
                    CGRectGetMinY(box) - 16.0, w + 16.0, 13.0);
                FFDarkDrawText(name, nameRect, [UIFont monospacedSystemFontOfSize:8.5
                    weight:UIFontWeightBold], color, NSTextAlignmentCenter);
            }
            if (config.espDistance) {
                NSString *distance = [NSString stringWithFormat:@"%ldM",
                    (long)[target[@"distance"] integerValue]];
                CGRect distanceRect = CGRectMake(CGRectGetMinX(box) - 8.0,
                    CGRectGetMaxY(box) + 2.0, w + 16.0, 12.0);
                FFDarkDrawText(distance, distanceRect, [UIFont monospacedSystemFontOfSize:8.0
                    weight:UIFontWeightMedium], color, NSTextAlignmentCenter);
            }
        }
    }

    // AIM preview: a dashed field-of-view circle and a simulated target lock.
    if (config.masterEnabled && (config.aimEnabled || config.aimBotEnabled)) {
        CGFloat radius = MIN(width, height) * 0.5 * (config.aimFOV / 300.0) * 1.45;
        CGRect fovRect = CGRectMake(centerX - radius, centerY - radius, radius * 2.0, radius * 2.0);
        UIBezierPath *fov = [UIBezierPath bezierPathWithOvalInRect:fovRect];
        CGFloat dash[] = {5.0, 4.0};
        [fov setLineDash:dash count:2 phase:0];
        fov.lineWidth = 1.0;
        [[accent colorWithAlphaComponent:0.80] setStroke];
        [fov stroke];

        UIBezierPath *cross = [UIBezierPath bezierPath];
        [cross moveToPoint:CGPointMake(centerX - 7.0, centerY)];
        [cross addLineToPoint:CGPointMake(centerX + 7.0, centerY)];
        [cross moveToPoint:CGPointMake(centerX, centerY - 7.0)];
        [cross addLineToPoint:CGPointMake(centerX, centerY + 7.0)];
        cross.lineWidth = 1.0;
        [[accent colorWithAlphaComponent:0.9] setStroke];
        [cross stroke];

        CGRect lockBox = CGRectMake(centerX - 19.0, centerY - 28.0, 38.0, 56.0);
        UIBezierPath *lock = [UIBezierPath bezierPathWithRect:lockBox];
        lock.lineWidth = 1.5;
        [[accent colorWithAlphaComponent:0.95] setStroke];
        [lock stroke];
        NSString *lockLabel = config.aimBotEnabled ? @"AIM BOT" : @"LOCK";
        FFDarkDrawText(lockLabel, CGRectMake(centerX - 32.0, centerY - 43.0, 64.0, 12.0),
            [UIFont monospacedSystemFontOfSize:8.0 weight:UIFontWeightBold],
            [accent colorWithAlphaComponent:0.95], NSTextAlignmentCenter);
    }

    // M BOARD preview.
    if (config.boardEnabled && config.masterEnabled) {
        CGFloat scale = config.boardScale;
        CGFloat panelWidth = 154.0 * scale;
        CGFloat panelHeight = 62.0 * scale;
        if (config.boardStyle == FFDarkBoardStyleCompact) {
            panelWidth = 132.0 * scale;
            panelHeight = 46.0 * scale;
        } else if (config.boardStyle == FFDarkBoardStyleMinimal) {
            panelWidth = 94.0 * scale;
            panelHeight = 28.0 * scale;
        }
        CGFloat margin = 11.0;
        CGFloat panelX = margin;
        CGFloat panelY = margin;
        switch (config.boardPosition) {
            case FFDarkBoardPositionTopRight:
                panelX = width - panelWidth - margin;
                break;
            case FFDarkBoardPositionBottomLeft:
                panelY = height - panelHeight - margin;
                break;
            case FFDarkBoardPositionBottomRight:
                panelX = width - panelWidth - margin;
                panelY = height - panelHeight - margin;
                break;
            case FFDarkBoardPositionTopLeft:
                break;
        }
        CGRect panel = CGRectMake(panelX, panelY, panelWidth, panelHeight);
        UIColor *panelColor = [[UIColor colorWithWhite:0.02 alpha:1.0]
            colorWithAlphaComponent:MAX(0.35, config.boardOpacity)];
        FFDarkFillRoundedRect(panel, 8.0, panelColor);
        FFDarkStrokeRoundedRect(panel, 8.0, [accent colorWithAlphaComponent:0.55], 1.0);

        UIFont *titleFont = [UIFont monospacedSystemFontOfSize:10.0 * scale
            weight:UIFontWeightHeavy];
        FFDarkDrawText(@"M BOARD", CGRectMake(panelX + 8.0 * scale, panelY + 4.0 * scale,
            panelWidth - 16.0 * scale, 14.0 * scale), titleFont, accent,
            NSTextAlignmentLeft);

        if (config.boardStyle != FFDarkBoardStyleMinimal) {
            CGFloat lineY = panelY + 19.0 * scale;
            if (config.boardStyle == FFDarkBoardStyleFull) {
                FFDarkDrawText(@"DARK // IN-GAME", CGRectMake(panelX + 8.0 * scale,
                    lineY, panelWidth - 16.0 * scale, 11.0 * scale),
                    [UIFont monospacedSystemFontOfSize:7.5 * scale weight:UIFontWeightSemibold],
                    [UIColor colorWithWhite:1.0 alpha:0.72], NSTextAlignmentLeft);
                lineY += 11.0 * scale;
            }
            NSMutableArray<NSString *> *stats = [NSMutableArray array];
            if (config.boardShowFPS) [stats addObject:@"FPS 60"];
            if (config.boardShowPing) [stats addObject:@"PING 42"];
            if (config.boardShowClock) [stats addObject:@"18:42"];
            if (stats.count) {
                FFDarkDrawText([stats componentsJoinedByString:@"  •  "],
                    CGRectMake(panelX + 8.0 * scale, lineY, panelWidth - 16.0 * scale,
                        11.0 * scale),
                    [UIFont monospacedSystemFontOfSize:7.5 * scale weight:UIFontWeightBold],
                    [UIColor colorWithWhite:1.0 alpha:0.90], NSTextAlignmentLeft);
            }
            FFDarkDrawText(@"DARK OVERLAY", CGRectMake(panelX + 8.0 * scale,
                panelY + panelHeight - 12.0 * scale, panelWidth - 16.0 * scale, 9.0 * scale),
                [UIFont monospacedSystemFontOfSize:6.5 * scale weight:UIFontWeightSemibold],
                [UIColor colorWithWhite:1.0 alpha:0.50], NSTextAlignmentLeft);
        }
    }

    // Header and footer identify the in-game preview and the DARK button.
    FFDarkFillRoundedRect(CGRectMake(10.0, 10.0, width - 20.0, 1.0), 0.5,
        [accent colorWithAlphaComponent:0.35]);
    FFDarkDrawText(FFDarkPreviewSimulationLabel(config.language),
        CGRectMake(10.0, 14.0, width - 20.0, 13.0),
        [UIFont monospacedSystemFontOfSize:7.0 weight:UIFontWeightBold],
        [UIColor colorWithWhite:1.0 alpha:0.65], NSTextAlignmentCenter);

    if (config.displayShowCompatibilityBadge && _compatibilityBadgeText.length) {
        UIBezierPath *badge = [UIBezierPath bezierPathWithRoundedRect:
            CGRectMake(width - 104.0, height - 24.0, 94.0, 15.0) cornerRadius:7.5];
        [[accent colorWithAlphaComponent:0.14] setFill];
        [badge fill];
        FFDarkDrawText(_compatibilityBadgeText,
            CGRectMake(width - 100.0, height - 21.5, 86.0, 10.0),
            [UIFont monospacedSystemFontOfSize:6.5 weight:UIFontWeightBold],
            [accent colorWithAlphaComponent:0.90], NSTextAlignmentCenter);
    }

    CGContextRestoreGState(context);

    // Vignette.
    CGContextSaveGState(context);
    CGContextSetAlpha(context, 0.22);
    UIBezierPath *vignette = [UIBezierPath bezierPathWithRect:bounds];
    [vignette appendPath:[UIBezierPath bezierPathWithOvalInRect:
        CGRectInset(bounds, -width * 0.18, -height * 0.18)]];
    vignette.usesEvenOddFillRule = YES;
    [[UIColor blackColor] setFill];
    [vignette fillWithBlendMode:kCGBlendModeMultiply alpha:0.6];
    CGContextRestoreGState(context);
}

@end
