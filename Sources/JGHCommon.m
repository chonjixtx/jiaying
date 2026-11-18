//
//  JGHCommon.m
//  JiayingGameTweak
//

#import "JGHCommon.h"
#import <UIKit/UIKit.h>

@implementation JGHCommon

+ (BOOL)isRootless {
    static BOOL result = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"];
    });
    return result;
}

+ (NSString *)dataDirectory {
    NSString *mobileLib;
    if ([self isRootless]) {
        // rootless 越狱把整个文件系统挪到 /var/jb 下
        mobileLib = @"/var/jb/var/mobile/Library";
    } else {
        mobileLib = @"/var/mobile/Library";
    }
    return [mobileLib stringByAppendingPathComponent:@"JiayingGameHall"];
}

+ (NSString *)profilesDirectory {
    return [[self dataDirectory] stringByAppendingPathComponent:@"Profiles"];
}

+ (NSString *)settingsPath {
    return [[self dataDirectory] stringByAppendingPathComponent:@"settings.plist"];
}

+ (BOOL)ensureDirectory:(NSString *)path error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        return YES;
    }
    // 用字符串字面量作为 key，避免依赖真机 SDK 中可能未公开的 NSFileProtectionKey 符号；
    // value 用 NSFileProtectionNone 的字符串值，文件保护属性非必需。
    return [fm createDirectoryAtPath:path
         withIntermediateDirectories:YES
                          attributes:@{@"NSFileProtection": @"NSFileProtectionNone"}
                               error:error];
}

@end
