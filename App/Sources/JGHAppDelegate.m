#import "JGHAppDelegate.h"
#import "JGHGameListViewController.h"

@implementation JGHAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    JGHGameListViewController *list = [[JGHGameListViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
