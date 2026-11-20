//
//  Tweak.x  —  JiayingGameTweak 入口
//  Hook UIApplication 启动流程，初始化协调器。
//

#import <UIKit/UIKit.h>
#import <unistd.h>
#import "JGHTweakManager.h"
#import "JGHCommon.h"

static BOOL jghInitialized = NO;

// 只在用户于桌面 App 里添加过的游戏里激活。
// 关键：SpringBoard（桌面/锁屏）本身也是 UIApplication，若不加判断，
// 悬浮窗会盖在桌面上并拦截全部触摸，导致设备无法操作。
static BOOL JGHShouldActivate(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    // 1) 硬性排除桌面与所有系统 App，绝不注入 UI
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return NO;
    if ([bundleID hasPrefix:@"com.apple."]) return NO;
    // 排除本工具自己的 App
    if ([bundleID isEqualToString:@"com.jiaying.gamehall.app"] ||
        [bundleID isEqualToString:@"com.jiaying.gamehall.unified"] ||
        [bundleID isEqualToString:@"com.jiaying.gamehall"]) return NO;

    // 2) 白名单：只有 games.plist 里添加过的游戏才激活
    NSString *gamesPath = [[JGHCommon dataDirectory] stringByAppendingPathComponent:@"games.plist"];
    NSArray *games = [NSArray arrayWithContentsOfFile:gamesPath];
    if (![games isKindOfClass:[NSArray class]]) return NO;
    for (id item in games) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *gameBundle = [[(NSDictionary *)item objectForKey:@"bundleID"] description];
        if ([gameBundle isEqualToString:bundleID]) return YES;
    }
    return NO;
}

static void JGHInitialize(void) {
    if (jghInitialized) return;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if (!JGHShouldActivate(bundleID)) {
        JGHLog(@"跳过非游戏进程: %@", bundleID ?: @"?");
        return;  // 不置 jghInitialized，避免后续白名单变化时无法重试
    }
    jghInitialized = YES;

    JGHLog(@"启动 (rootless=%@, bundle=%@)",
           [JGHCommon isRootless] ? @"YES" : @"NO",
           bundleID);
    JGHLog(@"数据目录: %@", [JGHCommon dataDirectory]);

    JGHTweakManager *mgr = [JGHTweakManager sharedManager];
    [mgr applyCurrentAppProfile];
    [mgr start];
}

%hook UIApplication

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    JGHInitialize();
    return result;
}

%end

%ctor {
    @autoreleasepool {
        JGHLog(@"ctor 注入成功, pid=%d", getpid());

        // 首选：监听 UIKit 的启动通知。比 hook UIApplication 的
        // didFinishLaunching 更可靠（部分游戏根本不走那个方法）。
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            JGHInitialize();
        }];

        // 兜底：通知漏掉或游戏启动极慢时，延迟初始化。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            JGHInitialize();
        });
    }
}
