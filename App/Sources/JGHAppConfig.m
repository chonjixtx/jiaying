#import "JGHAppConfig.h"

@implementation JGHAppConfig

+ (NSString *)dataDirectory {
    NSString *mobileLib = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]
        ? @"/var/jb/var/mobile/Library"
        : @"/var/mobile/Library";
    NSString *dir = [mobileLib stringByAppendingPathComponent:@"JiayingGameHall"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    NSString *profiles = [dir stringByAppendingPathComponent:@"Profiles"];
    [[NSFileManager defaultManager] createDirectoryAtPath:profiles
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    return dir;
}

+ (NSString *)gamesPath {
    return [[self dataDirectory] stringByAppendingPathComponent:@"games.plist"];
}

+ (NSString *)settingsPath {
    return [[self dataDirectory] stringByAppendingPathComponent:@"settings.plist"];
}

+ (NSString *)profilesDirectory {
    return [[self dataDirectory] stringByAppendingPathComponent:@"Profiles"];
}

+ (NSArray<NSDictionary *> *)loadGames {
    NSArray *arr = [NSArray arrayWithContentsOfFile:[self gamesPath]];
    return [arr isKindOfClass:[NSArray class]] ? arr : @[];
}

+ (BOOL)saveGames:(NSArray<NSDictionary *> *)games {
    return [games writeToFile:[self gamesPath] atomically:YES];
}

+ (BOOL)addGame:(NSDictionary *)game {
    NSMutableArray *games = [[self loadGames] mutableCopy];
    NSString *bid = game[@"bundleID"];
    if (bid.length == 0) return NO;
    for (NSDictionary *g in games) {
        if ([g[@"bundleID"] isEqualToString:bid]) return YES; // already exists
    }
    [games addObject:game];
    return [self saveGames:games];
}

+ (BOOL)removeGameWithBundleID:(NSString *)bundleID {
    NSMutableArray *games = [[self loadGames] mutableCopy];
    NSIndexSet *indexes = [games indexesOfObjectsPassingTest:^BOOL(NSDictionary *g, NSUInteger idx, BOOL *stop) {
        return [g[@"bundleID"] isEqualToString:bundleID];
    }];
    [games removeObjectsAtIndexes:indexes];
    return [self saveGames:games];
}

+ (NSDictionary *)loadSettings {
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:[self settingsPath]];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
        @"enabled": @YES,
        @"streamerMode": @YES,
        @"mouseSensitivity": @1.0,
        @"pointerSize": @12.0,
        @"customPointerPath": @"",
        @"scrollOrientation": @"vertical",
        @"scrollStep": @3,
        @"scrollZoom": @YES
    }];
    if ([saved isKindOfClass:[NSDictionary class]]) [result addEntriesFromDictionary:saved];
    return result;
}

+ (void)saveSettings:(NSDictionary *)settings {
    [settings writeToFile:[self settingsPath] atomically:YES];
    // 通知已注入的 tweak 立即重载设置
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, CFSTR("com.jiaying.gamehall.settingschanged"), NULL, NULL, YES);
}

@end
