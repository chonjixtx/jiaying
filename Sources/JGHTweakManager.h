//
//  JGHTweakManager.h
//  JiayingGameTweak
//
//  核心协调器：串联外设监听 -> 映射查询 -> 触摸注入。
//  由 Tweak.x 在 App 启动后驱动。
//

#import <Foundation/Foundation.h>
// 必须 import 完整定义：类声明遵守该协议时，仅有 @protocol 前向声明会导致
// "cannot find protocol definition" 编译错误。
#import "JGHDeviceMonitor.h"

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
