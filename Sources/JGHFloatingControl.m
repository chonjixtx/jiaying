//
//  JGHFloatingControl.m
//  JiayingGameTweak
//
//  小悬浮图标 + 按键编辑器。图标可拖动；点开后进入编辑面板。
//

#import "JGHFloatingControl.h"
#import "JGHCommon.h"
#import "JGHSettings.h"
#import "JGHTweakManager.h"
#import "JGHKeyMapManager.h"
#import "JGHDeviceMonitor.h"
#import "IOHIDPrivate.h"
#import <UIKit/UIKit.h>

#pragma mark - 触摸穿透容器

@interface JGHPassthroughView : UIView
@end

@implementation JGHPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}
@end

#pragma mark - 悬浮控制

@interface JGHFloatingControl ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) JGHPassthroughView *container;
@property (nonatomic, strong) UIButton *miniButton;
@property (nonatomic, strong) UIView *editorPanel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *pointerView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *keyButtons;
@property (nonatomic) BOOL editorVisible;
@property (nonatomic) BOOL backgroundUnlocked;
@end

@implementation JGHFloatingControl

+ (instancetype)sharedControl {
    static JGHFloatingControl *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHFloatingControl new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
        _keyButtons = [NSMutableArray array];
        [self buildUI];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshStatus)
                                                     name:@"JGHDeviceStatusChanged"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onSettingsChanged)
                                                     name:@"JGHSettingsChanged"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onCaptureChanged)
                                                     name:UIScreenCapturedDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onPointerMoved:)
                                                     name:@"JGHPointerDidMove"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI 构建

- (void)buildUI {
    CGRect screen = [UIScreen mainScreen].bounds;

    self.container = [[JGHPassthroughView alloc] initWithFrame:screen];

    // 小图标
    self.miniButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.miniButton.frame = CGRectMake(16, 100, 46, 46);
    self.miniButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    self.miniButton.layer.cornerRadius = 23;
    self.miniButton.layer.borderColor = [UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:1].CGColor;
    self.miniButton.layer.borderWidth = 2;
    [self.miniButton setTitle:@"J" forState:UIControlStateNormal];
    [self.miniButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.miniButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.miniButton addTarget:self action:@selector(toggleEditor) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *miniPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMiniPan:)];
    [self.miniButton addGestureRecognizer:miniPan];
    [self.container addSubview:self.miniButton];

    // 编辑面板
    CGFloat ew = 280.0, eh = 330.0;
    self.editorPanel = [[UIView alloc] initWithFrame:CGRectMake(70, 160, ew, eh)];
    self.editorPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
    self.editorPanel.layer.cornerRadius = 14;
    self.editorPanel.layer.borderColor = [UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:0.9].CGColor;
    self.editorPanel.layer.borderWidth = 1.5;
    self.editorPanel.hidden = YES;
    [self.container addSubview:self.editorPanel];

    UIPanGestureRecognizer *editorPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEditorPan:)];
    [self.editorPanel addGestureRecognizer:editorPan];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, ew - 24, 20)];
    title.text = @"佳影 · 按键编辑";
    title.textColor = [UIColor colorWithRed:0.45 green:0.85 blue:1.0 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:14];
    [self.editorPanel addSubview:title];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, ew - 24, 18)];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    [self.editorPanel addSubview:self.statusLabel];

    NSArray *titles = @[@"解锁背景", @"添加点击键", @"添加宏按键", @"保存", @"关闭"];
    CGFloat buttonW = (ew - 36 - 20) / 3.0;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSInteger col = i % 3;
        NSInteger row = i / 3;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12 + col * (buttonW + 10), 56 + row * 40, buttonW, 32);
        b.backgroundColor = [UIColor colorWithRed:0.16 green:0.55 blue:0.9 alpha:1];
        [b setTitle:titles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:12];
        b.layer.cornerRadius = 7;
        b.tag = 100 + i;
        [b addTarget:self action:@selector(editorAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.editorPanel addSubview:b];
    }

    // 虚拟鼠标指针：启动时直接放在屏幕中央可见位置，
    // 不再等第一次 HID 移动事件才从屏幕外 (-50,-50) 移进来。
    CGFloat ps = [JGHSettings sharedSettings].pointerSize;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.pointerView = [[UIView alloc] initWithFrame:CGRectMake((screenSize.width - ps) / 2,
                                                                (screenSize.height - ps) / 2,
                                                                ps, ps)];
    self.pointerView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    self.pointerView.layer.cornerRadius = ps / 2;
    self.pointerView.layer.borderColor = [UIColor blackColor].CGColor;
    self.pointerView.layer.borderWidth = 1;
    self.pointerView.userInteractionEnabled = NO;
    [self.container addSubview:self.pointerView];

    self.window = [[UIWindow alloc] initWithFrame:screen];
    self.window.windowLevel = UIWindowLevelAlert + 100;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.rootViewController = [UIViewController new];
    [self.window.rootViewController.view addSubview:self.container];
    self.window.hidden = NO;

    [self refreshStatus];
    [self applyStreamerMode];
}

#pragma mark - 面板交互

- (void)toggleEditor {
    self.editorVisible = !self.editorVisible;
    self.editorPanel.hidden = !self.editorVisible;
    if (self.editorVisible) [self refreshEditor];
}

- (void)editorAction:(UIButton *)sender {
    switch (sender.tag) {
        case 100: { // 解锁/锁定背景
            self.backgroundUnlocked = !self.backgroundUnlocked;
            [sender setTitle:self.backgroundUnlocked ? @"锁定背景" : @"解锁背景" forState:UIControlStateNormal];
            self.editorPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:
                                                self.backgroundUnlocked ? 0.18 : 0.82];
            for (UIGestureRecognizer *g in self.editorPanel.gestureRecognizers) g.enabled = !self.backgroundUnlocked;
            break;
        }
        case 101: [self addKeyButtonOfType:JGHActionTypeTap]; break;
        case 102: [self addKeyButtonOfType:JGHActionTypeMacro]; break;
        case 103: [self saveProfile]; break;
        case 104: [self toggleEditor]; break;
        default: break;
    }
}

- (void)addKeyButtonOfType:(JGHActionType)type {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat size = 46;
    b.frame = CGRectMake(CGRectGetWidth(self.window.frame)/2 - size/2,
                         CGRectGetHeight(self.window.frame)/2 - size/2, size, size);
    b.backgroundColor = [[UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:0.85] colorWithAlphaComponent:0.9];
    b.layer.cornerRadius = size/2;
    b.layer.borderColor = [UIColor whiteColor].CGColor;
    b.layer.borderWidth = 1.5;
    [b setTitle:type == JGHActionTypeMacro ? @"宏" : @"键" forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleKeyPan:)];
    [b addGestureRecognizer:pan];
    [self.container insertSubview:b belowSubview:self.editorPanel];
    [self.keyButtons addObject:b];
}

- (void)refreshEditor {
    for (UIButton *b in self.keyButtons) [b removeFromSuperview];
    [self.keyButtons removeAllObjects];

    JGHProfile *profile = [JGHKeyMapManager sharedManager].activeProfile;
    NSArray *keys = [profile.mappings.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        JGHAction *action = profile.mappings[key];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat size = 46;
        CGPoint center = CGPointMake(action.x * CGRectGetWidth(self.window.frame),
                                     action.y * CGRectGetHeight(self.window.frame));
        b.frame = CGRectMake(center.x - size/2, center.y - size/2, size, size);
        b.backgroundColor = [[UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:0.85] colorWithAlphaComponent:0.9];
        b.layer.cornerRadius = size/2;
        b.layer.borderColor = [UIColor whiteColor].CGColor;
        b.layer.borderWidth = 1.5;
        [b setTitle:action.type == JGHActionTypeMacro ? @"宏" : @"键" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleKeyPan:)];
        [b addGestureRecognizer:pan];
        [self.container insertSubview:b belowSubview:self.editorPanel];
        [self.keyButtons addObject:b];
    }
}

- (void)saveProfile {
    JGHProfile *profile = [JGHKeyMapManager sharedManager].activeProfile;
    if (!profile) return;
    [profile.mappings removeAllObjects];

    for (NSInteger i = 0; i < self.keyButtons.count; i++) {
        UIButton *b = self.keyButtons[i];
        BOOL isMacro = [b.currentTitle isEqualToString:@"宏"];
        JGHAction *action = [JGHAction new];
        action.type = isMacro ? JGHActionTypeMacro : JGHActionTypeTap;
        action.x = CGRectGetMidX(b.frame) / CGRectGetWidth(self.window.frame);
        action.y = CGRectGetMidY(b.frame) / CGRectGetHeight(self.window.frame);
        action.fingerID = i;
        if (isMacro) {
            action.steps = @[
                @{@"type": @"tap", @"x": @(action.x), @"y": @(action.y), @"delay": @0.0},
                @{@"type": @"tap", @"x": @(action.x + 0.05), @"y": @(action.y), @"delay": @0.12},
                @{@"type": @"tap", @"x": @(action.x - 0.05), @"y": @(action.y), @"delay": @0.12}
            ];
        }
        NSString *key = [JGHKeyMapManager keyForUsagePage:kHIDPage_KeyboardOrKeypad usage:(uint32_t)(0x40 + i)];
        profile.mappings[key] = action;
    }
    NSError *error = nil;
    BOOL ok = [[JGHKeyMapManager sharedManager] saveActiveProfile:&error];
    self.statusLabel.text = ok ? @"配置已保存" : [NSString stringWithFormat:@"保存失败: %@", error.localizedDescription];
    JGHLog(@"保存按键配置 %@", ok ? @"成功" : @"失败");
}

#pragma mark - 拖拽

- (void)handleMiniPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.window];
    CGPoint center = self.miniButton.center;
    center.x += translation.x;
    center.y += translation.y;
    center.x = MAX(23, MIN(CGRectGetWidth(self.window.frame) - 23, center.x));
    center.y = MAX(23, MIN(CGRectGetHeight(self.window.frame) - 23, center.y));
    self.miniButton.center = center;
    [gesture setTranslation:CGPointZero inView:self.window];
}

- (void)handleEditorPan:(UIPanGestureRecognizer *)gesture {
    if (self.backgroundUnlocked) return;
    CGPoint translation = [gesture translationInView:self.window];
    CGPoint center = self.editorPanel.center;
    center.x += translation.x;
    center.y += translation.y;
    self.editorPanel.center = center;
    [gesture setTranslation:CGPointZero inView:self.window];
}

- (void)handleKeyPan:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:self.window];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    center.x = MAX(23, MIN(CGRectGetWidth(self.window.frame) - 23, center.x));
    center.y = MAX(23, MIN(CGRectGetHeight(self.window.frame) - 23, center.y));
    view.center = center;
    [gesture setTranslation:CGPointZero inView:self.window];
}

#pragma mark - 设置与状态

- (void)onSettingsChanged {
    [[JGHSettings sharedSettings] reload];
    CGFloat ps = [JGHSettings sharedSettings].pointerSize;
    self.pointerView.frame = CGRectMake(CGRectGetMinX(self.pointerView.frame),
                                        CGRectGetMinY(self.pointerView.frame), ps, ps);
    self.pointerView.layer.cornerRadius = ps / 2;
    NSString *custom = [JGHSettings sharedSettings].customPointerPath;
    if (custom.length && [[NSFileManager defaultManager] fileExistsAtPath:custom]) {
        UIImage *image = [UIImage imageWithContentsOfFile:custom];
        if (image) {
            self.pointerView.layer.contents = (id)image.CGImage;
            self.pointerView.backgroundColor = [UIColor clearColor];
            self.pointerView.layer.cornerRadius = 0;
        }
    } else {
        self.pointerView.layer.contents = nil;
        self.pointerView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    }
    [self applyStreamerMode];
    [self refreshStatus];
}

- (void)onCaptureChanged {
    [self applyStreamerMode];
}

- (void)applyStreamerMode {
    BOOL hide = [JGHSettings sharedSettings].streamerMode && [UIScreen mainScreen].isCaptured;
    self.window.hidden = hide;
}

- (void)onPointerMoved:(NSNotification *)note {
    NSNumber *x = note.userInfo[@"x"];
    NSNumber *y = note.userInfo[@"y"];
    if (!x || !y) return;
    CGFloat cx = x.floatValue;
    CGFloat cy = y.floatValue;
    CGFloat ps = [JGHSettings sharedSettings].pointerSize;
    self.pointerView.frame = CGRectMake(cx - ps/2, cy - ps/2, ps, ps);
}

- (void)refreshStatus {
    NSString *profileName = [JGHKeyMapManager sharedManager].activeProfile.name ?: @"默认";
    self.statusLabel.text = [NSString stringWithFormat:@"配置: %@ | 外设: %@",
                             profileName, [JGHDeviceMonitor sharedMonitor].running ? @"已连接" : @"未连接"];
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyStreamerMode];
    });
}

- (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = YES;
    });
}

- (void)toggle {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self toggleEditor];
    });
}

@end
