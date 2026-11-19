#import "JGHSettings.h"
#import "JGHCommon.h"

@implementation JGHSettings

+ (instancetype)sharedSettings {
    static JGHSettings *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHSettings new];
        [instance reload];
    });
    return instance;
}

- (void)reload {
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:[JGHCommon settingsPath]];
    NSDictionary *defaults = @{
        @"enabled": @YES,
        // 主播模式默认关闭，确保首次启动悬浮窗一定可见；
        // 用户可在游戏内悬浮窗里手动开启（录屏隐藏按键、本机仍可见）。
        @"streamerMode": @NO,
        @"mouseSensitivity": @1.0,
        @"pointerSize": @12.0,
        @"customPointerPath": @"",
        @"scrollOrientation": @"vertical",
        @"scrollStep": @3,
        @"scrollZoom": @YES
    };
    NSMutableDictionary *all = [defaults mutableCopy];
    if ([saved isKindOfClass:[NSDictionary class]]) [all addEntriesFromDictionary:saved];

    _enabled = [all[@"enabled"] boolValue];
    _streamerMode = [all[@"streamerMode"] boolValue];
    _mouseSensitivity = [all[@"mouseSensitivity"] floatValue];
    _pointerSize = [all[@"pointerSize"] floatValue];
    _customPointerPath = [all[@"customPointerPath"] copy] ?: @"";
    _scrollOrientation = [all[@"scrollOrientation"] copy] ?: @"vertical";
    _scrollStep = [all[@"scrollStep"] integerValue];
    _scrollZoom = [all[@"scrollZoom"] boolValue];
}

@end
