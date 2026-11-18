//
//  JGHKeyMapManager.m
//  JiayingGameTweak
//

#import "JGHKeyMapManager.h"
#import "JGHCommon.h"
// defaultProfile 用到 kHIDPage_KeyboardOrKeypad / kHIDPage_Button 常量，
// 这些定义在 IOHIDPrivate.h，必须引入否则 "undeclared identifier"。
#import "IOHIDPrivate.h"

#pragma mark - JGHAction

@implementation JGHAction

+ (instancetype)actionWithDictionary:(NSDictionary *)dict {
    JGHAction *a = [JGHAction new];
    NSString *type = [dict[@"type"] lowercaseString];
    if      ([type isEqualToString:@"hold"])     a.type = JGHActionTypeHold;
    else if ([type isEqualToString:@"swipe"])    a.type = JGHActionTypeSwipe;
    else if ([type isEqualToString:@"joystick"]) a.type = JGHActionTypeJoystick;
    else                                          a.type = JGHActionTypeTap;

    a.x = dict[@"x"] ? [dict[@"x"] floatValue] : 0.5f;
    a.y = dict[@"y"] ? [dict[@"y"] floatValue] : 0.5f;
    a.dx = dict[@"dx"] ? [dict[@"dx"] floatValue] : 0.0f;
    a.dy = dict[@"dy"] ? [dict[@"dy"] floatValue] : 0.0f;
    a.fingerID = dict[@"finger"] ? [dict[@"finger"] integerValue] : 0;
    return a;
}

- (NSDictionary *)dictionaryRepresentation {
    NSString *type;
    switch (self.type) {
        case JGHActionTypeHold:     type = @"hold"; break;
        case JGHActionTypeSwipe:    type = @"swipe"; break;
        case JGHActionTypeJoystick: type = @"joystick"; break;
        default:                    type = @"tap"; break;
    }
    return @{@"type": type,
             @"x": @(self.x), @"y": @(self.y),
             @"dx": @(self.dx), @"dy": @(self.dy),
             @"finger": @(self.fingerID)};
}

// NSCoding（便于偏好面板序列化）
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.type forKey:@"type"];
    [coder encodeDouble:self.x forKey:@"x"];
    [coder encodeDouble:self.y forKey:@"y"];
    [coder encodeDouble:self.dx forKey:@"dx"];
    [coder encodeDouble:self.dy forKey:@"dy"];
    [coder encodeInteger:self.fingerID forKey:@"finger"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _type = (JGHActionType)[coder decodeIntegerForKey:@"type"];
        _x = [coder decodeDoubleForKey:@"x"];
        _y = [coder decodeDoubleForKey:@"y"];
        _dx = [coder decodeDoubleForKey:@"dx"];
        _dy = [coder decodeDoubleForKey:@"dy"];
        _fingerID = [coder decodeIntegerForKey:@"finger"];
    }
    return self;
}

@end

#pragma mark - JGHProfile

@implementation JGHProfile

+ (instancetype)profileWithDictionary:(NSDictionary *)dict {
    JGHProfile *p = [JGHProfile new];
    p.name = dict[@"name"] ?: @"未命名";
    p.bundleID = dict[@"bundleID"] ?: @"*";
    p.mappings = [NSMutableDictionary dictionary];

    NSDictionary *raw = dict[@"mappings"] ?: @{};
    [raw enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSDictionary class]]) {
            p.mappings[key] = [JGHAction actionWithDictionary:obj];
        }
    }];
    return p;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *raw = [NSMutableDictionary dictionary];
    [self.mappings enumerateKeysAndObjectsUsingBlock:^(NSString *key, JGHAction *action, BOOL *stop) {
        raw[key] = [action dictionaryRepresentation];
    }];
    return @{@"name": self.name, @"bundleID": self.bundleID, @"mappings": raw};
}

@end

#pragma mark - JGHKeyMapManager

@interface JGHKeyMapManager ()
@property (nonatomic, strong) NSArray<JGHProfile *> *profiles;
@end

@implementation JGHKeyMapManager

+ (instancetype)sharedManager {
    static JGHKeyMapManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHKeyMapManager new];
    });
    return instance;
}

+ (NSString *)keyForUsagePage:(uint32_t)page usage:(uint32_t)usage {
    return [NSString stringWithFormat:@"%u:%u", page, usage];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _profiles = @[];
        [self reloadProfiles];
    }
    return self;
}

- (void)reloadProfiles {
    NSError *err = nil;
    [JGHCommon ensureDirectory:[JGHCommon profilesDirectory] error:&err];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:[JGHCommon profilesDirectory] error:&err];
    NSMutableArray *loaded = [NSMutableArray array];

    for (NSString *file in files) {
        if (![[file pathExtension] isEqualToString:@"json"]) continue;
        NSString *full = [[JGHCommon profilesDirectory] stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:full];
        if (!data) continue;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if (![dict isKindOfClass:[NSDictionary class]]) {
            JGHLog(@"跳过非法配置: %@ (%@)", file, err.localizedDescription);
            continue;
        }
        JGHProfile *p = [JGHProfile profileWithDictionary:dict];
        if (p) [loaded addObject:p];
    }

    // 内置默认配置（无任何外部文件时）
    if (loaded.count == 0) {
        [loaded addObject:[self defaultProfile]];
    }

    self.profiles = [loaded copy];
    JGHLog(@"已加载 %lu 个配置", (unsigned long)self.profiles.count);
}

- (JGHProfile *)defaultProfile {
    JGHProfile *p = [JGHProfile new];
    p.name = @"默认 (WASD + 鼠标)";
    p.bundleID = @"*";
    p.mappings = [NSMutableDictionary dictionary];
    // 键盘 WASD -> 左摇杆方向（归一化屏幕坐标示例）
    p.mappings[[JGHKeyMapManager keyForUsagePage:kHIDPage_KeyboardOrKeypad usage:0x04]] =
        [JGHAction actionWithDictionary:@{@"type":@"joystick", @"x":@0.2, @"y":@0.8, @"dx":@(-1), @"dy":@0, @"finger":@0}];
    p.mappings[[JGHKeyMapManager keyForUsagePage:kHIDPage_KeyboardOrKeypad usage:0x1A]] =
        [JGHAction actionWithDictionary:@{@"type":@"joystick", @"x":@0.2, @"y":@0.8, @"dx":@1, @"dy":@0, @"finger":@0}];
    p.mappings[[JGHKeyMapManager keyForUsagePage:kHIDPage_KeyboardOrKeypad usage:0x16]] =
        [JGHAction actionWithDictionary:@{@"type":@"joystick", @"x":@0.2, @"y":@0.8, @"dx":@0, @"dy":@(-1), @"finger":@0}];
    p.mappings[[JGHKeyMapManager keyForUsagePage:kHIDPage_KeyboardOrKeypad usage:0x07]] =
        [JGHAction actionWithDictionary:@{@"type":@"joystick", @"x":@0.2, @"y":@0.8, @"dx":@0, @"dy":@1, @"finger":@0}];
    // 鼠标左键 -> 射击点按
    p.mappings[[JGHKeyMapManager keyForUsagePage:kHIDPage_Button usage:1]] =
        [JGHAction actionWithDictionary:@{@"type":@"hold", @"x":@0.8, @"y":@0.5, @"finger":@1}];
    return p;
}

- (void)selectProfileForBundleID:(NSString *)bundleID {
    JGHProfile *match = nil;
    for (JGHProfile *p in self.profiles) {
        if ([p.bundleID isEqualToString:bundleID]) { match = p; break; }
    }
    if (!match) {
        for (JGHProfile *p in self.profiles) {
            if ([p.bundleID isEqualToString:@"*"]) { match = p; break; }
        }
    }
    self.activeProfile = match;
    if (match) JGHLog(@"当前配置: %@ (目标 %@)", match.name, bundleID);
}

- (JGHAction *)actionForUsagePage:(uint32_t)page usage:(uint32_t)usage {
    return self.activeProfile.mappings[[JGHKeyMapManager keyForUsagePage:page usage:usage]];
}

- (BOOL)saveActiveProfile:(NSError **)error {
    if (!self.activeProfile) return NO;
    [JGHCommon ensureDirectory:[JGHCommon profilesDirectory] error:error];
    NSString *safeName = [[self.activeProfile.name componentsSeparatedByCharactersInSet:
                           [NSCharacterSet alphanumericCharacterSet].invertedSet] componentsJoinedByString:@"_"];
    if (safeName.length == 0) safeName = @"profile";
    NSString *path = [[JGHCommon profilesDirectory] stringByAppendingPathComponent:
                      [safeName stringByAppendingPathExtension:@"json"]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self.activeProfile dictionaryRepresentation]
                                                   options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

@end
