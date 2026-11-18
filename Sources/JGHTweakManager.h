//
//  JGHTweakManager.h
//  JiayingGameTweak
//
//  核心协调器：串联外设监听 -> 映射查询 -> 触摸注入。
//  由 Tweak.x 在 App 启动后驱动。
//

#import <Foundation/Foundation.h>

@protocol JGHDeviceMonitorDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface JGHTweakManager : NSObject <JGHDeviceMonitorDelegate>

+ (instancetype)sharedManager;

/// 是否启用映射
@property (nonatomic) BOOL mappingEnabled;

/// 启动（开始监听外设）
- (void)start;
/// 根据当前 App 选择配置
- (void)applyCurrentAppProfile;

@end

NS_ASSUME_NONNULL_END
