//
//  JGHTweakManager.m
//  JiayingGameTweak
//

#import "JGHTweakManager.h"
#import "JGHDeviceMonitor.h"
#import "JGHEventInjector.h"
#import "JGHKeyMapManager.h"
#import "JGHFloatingControl.h"
#import "JGHCommon.h"
#import <UIKit/UIKit.h>

@interface JGHTweakManager ()
// key: "page:usage" -> value: NSNumber(fingerID)，记录当前按下的按键对应的手指
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *pressedKeys;
@property (nonatomic, strong) NSMutableDictionary<NSString *, JGHAction *> *activeActions;
@end

@implementation JGHTweakManager

+ (instancetype)sharedManager {
    static JGHTweakManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHTweakManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mappingEnabled = YES;
        _pressedKeys = [NSMutableDictionary dictionary];
        _activeActions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)start {
    // 读取启停状态
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[JGHCommon settingsPath]];
    if (settings[@"enabled"] != nil) {
        self.mappingEnabled = [settings[@"enabled"] boolValue];
    }

    [JGHDeviceMonitor sharedMonitor].delegate = self;
    BOOL ok = [[JGHDeviceMonitor sharedMonitor] start];
    JGHLog(@"外设监听%@", ok ? @"启动成功" : @"启动失败");

    // 显示悬浮面板（稍延迟，等待 Window 层级稳定）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[JGHFloatingControl sharedControl] show];
    });
}

- (void)applyCurrentAppProfile {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"*";
    [[JGHKeyMapManager sharedManager] selectProfileForBundleID:bundleID];
}

- (void)setMappingEnabled:(BOOL)enabled {
    _mappingEnabled = enabled;
    if (!enabled) {
        // 停用时释放所有按下的触摸，避免“卡住”
        [[JGHEventInjector sharedInjector] releaseAllTouches];
        [self.pressedKeys removeAllObjects];
        [self.activeActions removeAllObjects];
    }
    // 持久化
    NSDictionary *settings = @{@"enabled": @(enabled)};
    NSError *err = nil;
    [JGHCommon ensureDirectory:[JGHCommon dataDirectory] error:&err];
    [settings writeToFile:[JGHCommon settingsPath] atomically:YES];
}

#pragma mark - JGHDeviceMonitorDelegate

- (void)deviceMonitorDidReceiveUsagePage:(uint32_t)page usage:(uint32_t)usage value:(double)value down:(BOOL)down {
    if (!self.mappingEnabled) return;

    NSString *key = [JGHKeyMapManager keyForUsagePage:page usage:usage];
    JGHAction *action = [[JGHKeyMapManager sharedManager] actionForUsagePage:page usage:usage];
    if (!action) return;  // 无映射，忽略

    // 主线程注入（UI/系统事件需在主线程）
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleAction:action forKey:key down:down value:value];
    });
}

- (void)handleAction:(JGHAction *)action forKey:(NSString *)key down:(BOOL)down value:(double)value {
    JGHEventInjector *injector = [JGHEventInjector sharedInjector];
    NSInteger finger = action.fingerID;

    switch (action.type) {
        case JGHActionTypeTap: {
            if (down && !self.pressedKeys[key]) {
                [injector tapAtX:action.x y:action.y fingerID:finger];
                self.pressedKeys[key] = @(finger);
            } else if (!down) {
                [self.pressedKeys removeObjectForKey:key];
            }
            break;
        }
        case JGHActionTypeHold: {
            if (down && !self.pressedKeys[key]) {
                [injector touchDownAtX:action.x y:action.y fingerID:finger];
                self.pressedKeys[key] = @(finger);
            } else if (!down && self.pressedKeys[key]) {
                [injector touchUpAtX:action.x y:action.y fingerID:finger];
                [self.pressedKeys removeObjectForKey:key];
            }
            break;
        }
        case JGHActionTypeSwipe: {
            if (down && !self.pressedKeys[key]) {
                [injector touchDownAtX:action.x y:action.y fingerID:finger];
                CGPoint end = CGPointMake(action.x + action.dx, action.y + action.dy);
                __weak typeof(self) weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    [injector touchMoveAtX:end.x y:end.y fingerID:finger];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        [injector touchUpAtX:end.x y:end.y fingerID:finger];
                        [weakSelf.pressedKeys removeObjectForKey:key];
                    });
                });
                self.pressedKeys[key] = @(finger);
            }
            break;
        }
        case JGHActionTypeJoystick: {
            // 虚拟摇杆：按下时把手指移动到方向偏移位置，松开回到中心并抬起
            if (down) {
                if (!self.pressedKeys[key]) {
                    [injector touchDownAtX:action.x y:action.y fingerID:finger];
                    self.pressedKeys[key] = @(finger);
                }
                CGFloat nx = action.x + action.dx * 0.08;
                CGFloat ny = action.y + action.dy * 0.08;
                [injector touchMoveAtX:nx y:ny fingerID:finger];
                self.activeActions[key] = action;
            } else if (self.pressedKeys[key]) {
                [injector touchUpAtX:action.x y:action.y fingerID:finger];
                [self.pressedKeys removeObjectForKey:key];
                [self.activeActions removeObjectForKey:key];
            }
            break;
        }
    }
}

- (void)deviceMonitorDidConnectDevice:(NSString *)name {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 通知悬浮面板刷新状态
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JGHDeviceStatusChanged" object:nil];
    });
}

- (void)deviceMonitorDidDisconnectDevice:(NSString *)name {
    // 设备断开时释放所有触摸，防止卡键
    [[JGHEventInjector sharedInjector] releaseAllTouches];
    [self.pressedKeys removeAllObjects];
}

@end
