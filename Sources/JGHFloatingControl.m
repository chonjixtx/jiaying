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
@property (nonatomic, strong) UIButton *streamerButton;
@property (nonatomic, strong) UILabel *tuneLabel;
@property (nonatomic) BOOL editorVisible;
@property (nonatomic) BOOL backgroundUnlocked;
// iOS 13+ 悬浮窗必须绑定到一个 UIWindowScene 才会真正显示到屏幕上。
- (UIWindowScene *)activeWindowScene;
- (void)attachToActiveScene;
- (void)onSceneDidActivate:(NSNotification *)note;
// 设置项落盘并广播，悬浮窗内直接改设置用
- (void)setSettingValue:(id)value forKey:(NSString *)key;
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
        // 场景激活/连接时重新绑定 windowScene，保证悬浮窗一定会显示
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onSceneDidActivate:)
                                                         name:UISceneDidActivateNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onSceneDidActivate:)
                                                         name:UISceneDidConnectNotification
                                                       object:nil];
        }
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

    // 编辑面板（游戏内设置全部放这里）
    CGFloat ew = 300.0, eh = 470.0;
    self.editorPanel = [[UIView alloc] initWithFrame:CGRectMake(40, 90, ew, eh)];
    self.editorPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
    self.editorPanel.layer.cornerRadius = 14;
    self.editorPanel.layer.borderColor = [UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:0.9].CGColor;
    self.editorPanel.layer.borderWidth = 1.5;
    self.editorPanel.hidden = YES;
    [self.container addSubview:self.editorPanel];

    UIPanGestureRecognizer *editorPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEditorPan:)];
    [self.editorPanel addGestureRecognizer:editorPan];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, ew - 24, 20)];
    title.text = @"balls映射 · 游戏内设置";
    title.textColor = [UIColor colorWithRed:0.45 green:0.85 blue:1.0 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:14];
    [self.editorPanel addSubview:title];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, ew - 24, 30)];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.numberOfLines = 2;
    [self.editorPanel addSubview:self.statusLabel];

    // 第一组：按键编辑
    NSArray *titles = @[@"解锁背景", @"添加点击键", @"添加宏按键", @"保存", @"关闭"];
    CGFloat buttonW = (ew - 36 - 20) / 3.0;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSInteger col = i % 3;
        NSInteger row = i / 3;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12 + col * (buttonW + 10), 62 + row * 38, buttonW, 32);
        b.backgroundColor = [UIColor colorWithRed:0.16 green:0.55 blue:0.9 alpha:1];
        [b setTitle:titles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:12];
        b.layer.cornerRadius = 7;
        b.tag = 100 + i;
        [b addTarget:self action:@selector(editorAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.editorPanel addSubview:b];
    }

    // 第二组：主播模式 + 鼠标指针设置（都在游戏内悬浮窗里调）
    UILabel *section2 = [[UILabel alloc] initWithFrame:CGRectMake(12, 146, ew - 24, 18)];
    section2.text = @"主播模式 / 鼠标指针";
    section2.textColor = [UIColor colorWithRed:0.45 green:0.85 blue:1.0 alpha:1];
    section2.font = [UIFont boldSystemFontOfSize:12];
    [self.editorPanel addSubview:section2];

    // 主播模式开关
    self.streamerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.streamerButton.frame = CGRectMake(12, 170, ew - 24, 32);
    self.streamerButton.backgroundColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.4 alpha:1];
    [self.streamerButton setTitle:@"主播模式：关（录屏可见按键）" forState:UIControlStateNormal];
    [self.streamerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.streamerButton.titleLabel.font = [UIFont systemFontOfSize:12];
    self.streamerButton.layer.cornerRadius = 7;
    self.streamerButton.tag = 105;
    [self.streamerButton addTarget:self action:@selector(editorAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.editorPanel addSubview:self.streamerButton];

    // 指针大小 / 灵敏度：用一行两个按钮，格式 "名称-"/"名称+"
    NSArray *tuneTitles = @[@"指针-", @"指针+", @"灵敏度-", @"灵敏度+", @"滚动-", @"滚动+"];
    for (NSInteger i = 0; i < tuneTitles.count; i++) {
        NSInteger col = i % 2;
        NSInteger row = i / 2;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12 + col * (buttonW + 10), 210 + row * 38, buttonW, 32);
        b.backgroundColor = [UIColor colorWithRed:0.2 green:0.45 blue:0.35 alpha:1];
        [b setTitle:tuneTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:12];
        b.layer.cornerRadius = 7;
        b.tag = 200 + i;
        [b addTarget:self action:@selector(editorAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.editorPanel addSubview:b];
    }

    // 当前参数值显示
    self.tuneLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 332, ew - 24, 46)];
    self.tuneLabel.textColor = [UIColor colorWithRed:0.8 green:0.9 blue:0.8 alpha:1];
    self.tuneLabel.font = [UIFont systemFontOfSize:10];
    self.tuneLabel.numberOfLines = 3;
    [self.editorPanel addSubview:self.tuneLabel];

    // 提示：按键绑定方式
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, 384, ew - 24, 74)];
    tip.text = @"说明：点「添加点击键/宏按键」放好位置后按「保存」。\n键盘按键 → 对应悬浮键；鼠标 → 屏幕指针（跟电脑一样）。\n主播模式开启后录屏看不到按键，你本机仍可见可用。";
    tip.textColor = [UIColor colorWithRed:0.75 green:0.78 blue:0.82 alpha:1];
    tip.font = [UIFont systemFontOfSize:10];
    tip.numberOfLines = 5;
    [self.editorPanel addSubview:tip];

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
    [self attachToActiveScene];
    // 不抢占 keyWindow（避免抢走游戏输入焦点），只把窗口显示出来。
    // iOS 13+ 只要绑定了 windowScene，hidden=NO 就会真正上屏。
    self.window.hidden = NO;

    [self refreshStatus];
    [self applyStreamerMode];
    [self applyCaptureProtection];
}

#pragma mark - 场景绑定（悬浮窗显示的关键）

- (UIWindowScene *)activeWindowScene {
    if (@available(iOS 13.0, *)) {
        // 优先取前台激活的场景
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
        // 兜底：任意已连接的窗口场景
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

- (void)attachToActiveScene {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeWindowScene];
        if (scene && self.window.windowScene != scene) {
            self.window.windowScene = scene;
            // 场景变化后重新按场景尺寸布局
            CGRect bounds = scene.coordinateSpace.bounds;
            if (bounds.size.width > 0 && bounds.size.height > 0) {
                self.window.frame = bounds;
                self.container.frame = bounds;
            }
        }
    }
}

- (void)onSceneDidActivate:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self attachToActiveScene];
    });
}

#pragma mark - 面板交互

- (void)toggleEditor {
    self.editorVisible = !self.editorVisible;
    self.editorPanel.hidden = !self.editorVisible;
    if (self.editorVisible) [self refreshEditor];
}

- (void)editorAction:(UIButton *)sender {
    NSInteger tag = sender.tag;
    if (tag >= 200 && tag <= 205) {  // 指针/灵敏度/滚动 调节
        [self tuneSettingForTag:tag];
        return;
    }
    switch (tag) {
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
        case 105: { // 主播模式开关
            BOOL on = ![JGHSettings sharedSettings].streamerMode;
            [self setSettingValue:@(on) forKey:@"streamerMode"];
            [self.streamerButton setTitle:on ? @"主播模式：开（录屏隐藏按键）" : @"主播模式：关（录屏可见按键）"
                                 forState:UIControlStateNormal];
            self.streamerButton.backgroundColor = on
                ? [UIColor colorWithRed:0.75 green:0.35 blue:0.2 alpha:1]
                : [UIColor colorWithRed:0.35 green:0.35 blue:0.4 alpha:1];
            [self applyCaptureProtection];
            break;
        }
        default: break;
    }
}

// 200 指针-  201 指针+  202 灵敏度-  203 灵敏度+  204 滚动-  205 滚动+
- (void)tuneSettingForTag:(NSInteger)tag {
    JGHSettings *s = [JGHSettings sharedSettings];
    switch (tag) {
        case 200: [self setSettingValue:@(MAX(6.0f,  s.pointerSize - 2.0f)) forKey:@"pointerSize"]; break;
        case 201: [self setSettingValue:@(MIN(40.0f, s.pointerSize + 2.0f)) forKey:@"pointerSize"]; break;
        case 202: [self setSettingValue:@(MAX(0.2f,  s.mouseSensitivity - 0.2f)) forKey:@"mouseSensitivity"]; break;
        case 203: [self setSettingValue:@(MIN(3.0f,  s.mouseSensitivity + 0.2f)) forKey:@"mouseSensitivity"]; break;
        case 204: [self setSettingValue:@(MAX(1, (NSInteger)s.scrollStep - 1)) forKey:@"scrollStep"]; break;
        case 205: [self setSettingValue:@(MIN(20, (NSInteger)s.scrollStep + 1)) forKey:@"scrollStep"]; break;
        default: break;
    }
    [self onSettingsChanged];
}

// 把单个设置写入 plist 并广播，保证同一进程内立即生效
- (void)setSettingValue:(id)value forKey:(NSString *)key {
    NSMutableDictionary *settings = [[NSDictionary dictionaryWithContentsOfFile:[JGHCommon settingsPath]] mutableCopy];
    if (!settings) settings = [NSMutableDictionary dictionary];
    settings[key] = value;
    NSError *err = nil;
    [JGHCommon ensureDirectory:[JGHCommon dataDirectory] error:&err];
    [settings writeToFile:[JGHCommon settingsPath] atomically:YES];
    [[JGHSettings sharedSettings] reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"JGHSettingsChanged" object:nil];
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
    [self refreshSettingControls];

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

// 同步设置类控件显示（主播按钮、数值标签）
- (void)refreshSettingControls {
    JGHSettings *s = [JGHSettings sharedSettings];
    BOOL streamer = s.streamerMode;
    if (self.streamerButton) {
        [self.streamerButton setTitle:streamer ? @"主播模式：开（录屏隐藏按键）" : @"主播模式：关（录屏可见按键）"
                             forState:UIControlStateNormal];
        self.streamerButton.backgroundColor = streamer
            ? [UIColor colorWithRed:0.75 green:0.35 blue:0.2 alpha:1]
            : [UIColor colorWithRed:0.35 green:0.35 blue:0.4 alpha:1];
    }
    if (self.tuneLabel) {
        self.tuneLabel.text = [NSString stringWithFormat:
            @"指针大小: %.0f   灵敏度: %.1f   每格滚动: %ld",
            s.pointerSize, s.mouseSensitivity, (long)s.scrollStep];
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
    [self refreshSettingControls];
    [self refreshStatus];
}

- (void)onCaptureChanged {
    [self applyStreamerMode];
}

- (void)applyStreamerMode {
    // 主播模式：录屏/截图里看不到按键，但本机屏幕上照常可见可操作。
    // 关键：绝不能把整个 container 隐藏，否则本机也看不见了。
    // disableUpdateMask 只在图层上打“合成排除”标记，不影响本机渲染。
    [self applyCaptureProtection];
}

- (void)applyCaptureProtection {
    BOOL protect = [JGHSettings sharedSettings].streamerMode;
    CALayer *layer = self.container.layer;
    if (!layer) return;

    // 只操作按键/指针这类"敏感"子层，绝不动 container 本身，
    // 这样即使私有 API 行为异常，也不会导致整个悬浮层在本机消失。
    NSArray *sensitiveLayers = @[
        self.miniButton.layer,
        self.editorPanel.layer,
        self.pointerView.layer
    ].copy;
    for (UIButton *b in self.keyButtons) {
        sensitiveLayers = [sensitiveLayers arrayByAddingObject:b.layer];
    }

    NSString *key = @"disableUpdateMask";
    NSInteger mask = protect ? ((1 << 1) | (1 << 4)) : 0;
    for (CALayer *sub in sensitiveLayers) {
        if (!sub || ![sub respondsToSelector:NSSelectorFromString(key)]) continue;
        @try {
            [sub setValue:@(mask) forKey:key];
        } @catch (NSException *exception) {
            JGHLog(@"主播模式保护设置失败: %@", exception.reason);
        }
    }
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
        // 每次 show 都重新绑定场景并确保上屏（场景可能在 init 之后才就绪）
        [self attachToActiveScene];
        self.window.hidden = NO;
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
