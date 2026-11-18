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
        // 主播模式默认关闭：投屏/录屏/电脑端屏幕助手也会让 isCaptured=YES，
        // 默认开启会把悬浮 J 和虚拟鼠标一起隐藏，导致用户以为 tweak 没生效。
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
