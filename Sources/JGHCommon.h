//
//  JGHCommon.h
//  JiayingGameTweak
//
//  公共日志与路径工具：屏蔽 rootless/rootful 文件系统差异。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 带标签的日志，统一前缀便于在 syslog / 控制台过滤
#define JGHLog(fmt, ...) NSLog(@"[JiayingGameTweak] " fmt, ##__VA_ARGS__)

@interface JGHCommon : NSObject

/// 是否为 rootless 环境（存在 /var/jb）
+ (BOOL)isRootless;

/// tweak 数据根目录，自动适配 rootless/rootful
/// rootless: /var/jb/var/mobile/Library/JiayingGameHall
/// rootful : /var/mobile/Library/JiayingGameHall
+ (NSString *)dataDirectory;

/// 键位配置存放路径
+ (NSString *)profilesDirectory;

/// 设置 plist 路径
+ (NSString *)settingsPath;

/// 确保目录存在
+ (BOOL)ensureDirectory:(NSString *)path error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
