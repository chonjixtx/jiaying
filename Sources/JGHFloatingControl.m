//
//  JGHFloatingControl.m
//  JiayingGameTweak
//

#import "JGHFloatingControl.h"
#import "JGHCommon.h"
#import "JGHTweakManager.h"
#import "JGHKeyMapManager.h"
#import "JGHDeviceMonitor.h"
#import <UIKit/UIKit.h>

#pragma mark - 触摸穿透容器

@interface JGHPassthroughView : UIView
@end

@implementation JGHPassthroughView
// 只有子视图（按钮）区域响应触摸，其余区域穿透到下层游戏
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}
@end

#pragma mark - 悬浮面板

@interface JGHFloatingControl ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, readwrite) BOOL enabled;
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
        [self buildUI];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshStatus)
                                                     name:@"JGHDeviceStatusChanged"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildUI {
    CGFloat w = 190.0, h = 116.0;
    CGRect frame = CGRectMake(16, 100, w, h);

    // 面板容器
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
    self.panel.layer.cornerRadius = 12;
    self.panel.layer.borderColor = [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:0.9].CGColor;
    self.panel.layer.borderWidth = 1.5;

    // 拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.panel addGestureRecognizer:pan];

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 24, 20)];
    title.text = @"佳影游戏厅 · 映射";
    title.textColor = [UIColor colorWithRed:0.4 green:0.85 blue:1.0 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:13];
    [self.panel addSubview:title];

    // 状态
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, w - 24, 18)];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    [self.panel addSubview:self.statusLabel];

    // 启用/停用
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(12, 56, (w - 36) / 2, 34);
    self.toggleButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.65 blue:0.95 alpha:1];
    [self.toggleButton setTitle:@"已启用" forState:UIControlStateNormal];
    [self.toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.toggleButton.layer.cornerRadius = 8;
    [self.toggleButton addTarget:self action:@selector(onToggle:) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.toggleButton];

    // 重新加载配置
    UIButton *reloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    reloadBtn.frame = CGRectMake(12 + (w - 36) / 2 + 12, 56, (w - 36) / 2, 34);
    reloadBtn.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1];
    [reloadBtn setTitle:@"重载配置" forState:UIControlStateNormal];
    [reloadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    reloadBtn.layer.cornerRadius = 8;
    [reloadBtn addTarget:self action:@selector(onReload:) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:reloadBtn];

    // 穿透容器
    JGHPassthroughView *container = [[JGHPassthroughView alloc] initWithFrame:frame];
    [container addSubview:self.panel];

    // 悬浮 Window：兼容 iOS 13+ Scene API
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.windowLevel = UIWindowLevelAlert + 100;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.rootViewController = [UIViewController new];
    [self.window.rootViewController.view addSubview:container];
    // 不调用 makeKeyAndVisible，避免抢走游戏键盘焦点
    self.window.hidden = NO;

    [self refreshStatus];
}

- (void)refreshStatus {
    NSString *profileName = [JGHKeyMapManager sharedManager].activeProfile.name ?: @"无";
    self.statusLabel.text = [NSString stringWithFormat:@"配置: %@ | 外设: %@",
                             profileName, [JGHDeviceMonitor sharedMonitor].running ? @"已连接" : @"未连接"];
    [self.toggleButton setTitle:self.enabled ? @"已启用" : @"已停用" forState:UIControlStateNormal];
    self.toggleButton.backgroundColor = self.enabled
        ? [UIColor colorWithRed:0.16 green:0.65 blue:0.95 alpha:1]
        : [UIColor colorWithWhite:0.4 alpha:1];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.window];
    CGPoint center = self.panel.superview.center;
    center.x += translation.x;
    center.y += translation.y;

    // 限制在屏幕范围内
    CGFloat halfW = CGRectGetWidth(self.panel.frame) / 2;
    CGFloat halfH = CGRectGetHeight(self.panel.frame) / 2;
    center.x = MAX(halfW, MIN(CGRectGetWidth(self.window.frame) - halfW, center.x));
    center.y = MAX(halfH + 20, MIN(CGRectGetHeight(self.window.frame) - halfH - 20, center.y));

    self.panel.superview.center = center;
    [gesture setTranslation:CGPointZero inView:self.window];
}

- (void)onToggle:(UIButton *)sender {
    self.enabled = !self.enabled;
    [[JGHTweakManager sharedManager] setMappingEnabled:self.enabled];
    [self refreshStatus];
    JGHLog(@"映射已%@", self.enabled ? @"启用" : @"停用");
}

- (void)onReload:(UIButton *)sender {
    [[JGHKeyMapManager sharedManager] reloadProfiles];
    [[JGHTweakManager sharedManager] applyCurrentAppProfile];
    [self refreshStatus];
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = NO;
    });
}

- (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = YES;
    });
}

- (void)toggle {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.hidden = !self.window.hidden;
    });
}

@end
