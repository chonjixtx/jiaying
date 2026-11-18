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
    return [fm createDirectoryAtPath:path
         withIntermediateDirectories:YES
                          attributes:@{NSFileProtectionKey: NSFileProtectionNone}
                               error:error];
}

@end
