//
//  Tweak.x  —  JiayingGameTweak 入口
//  Hook UIApplication 启动流程，初始化协调器。
//

#import <UIKit/UIKit.h>
#import <unistd.h>
#import "JGHTweakManager.h"
#import "JGHCommon.h"

static BOOL jghInitialized = NO;

static void JGHInitialize(void) {
    if (jghInitialized) return;
    jghInitialized = YES;

    JGHLog(@"启动 (rootless=%@, bundle=%@)",
           [JGHCommon isRootless] ? @"YES" : @"NO",
           [[NSBundle mainBundle] bundleIdentifier] ?: @"?");
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
        // 双保险：部分 App 不走标准 didFinishLaunching，用延迟兜底初始化
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            JGHInitialize();
        });
    }
}
