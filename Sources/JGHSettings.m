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
        // 主播模式：开启后悬浮层对录屏/截图不可见，但本机屏幕仍可见。
        @"streamerMode": @YES,
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
