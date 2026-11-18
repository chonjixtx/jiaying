#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JGHAppConfig : NSObject

+ (NSString *)dataDirectory;
+ (NSString *)gamesPath;
+ (NSString *)settingsPath;
+ (NSString *)profilesDirectory;

+ (NSArray<NSDictionary *> *)loadGames;
+ (BOOL)saveGames:(NSArray<NSDictionary *> *)games;
+ (BOOL)addGame:(NSDictionary *)game;
+ (BOOL)removeGameWithBundleID:(NSString *)bundleID;

+ (NSDictionary *)loadSettings;
+ (void)saveSettings:(NSDictionary *)settings;

@end

NS_ASSUME_NONNULL_END
