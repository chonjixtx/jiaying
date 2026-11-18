//
//  JGHDeviceMonitor.h
//  JiayingGameTweak
//
//  通过 IOHIDManager 监听键盘/鼠标/手柄的 HID 输入。
//  设备插拔与按键事件通过 delegate 回调上报。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JGHDeviceMonitorDelegate <NSObject>
/// 有输入事件：usagePage/usage 标识按键，value 为原始值，down 表示是否按下/非零
- (void)deviceMonitorDidReceiveUsagePage:(uint32_t)page usage:(uint32_t)usage value:(double)value down:(BOOL)down;
@optional
- (void)deviceMonitorDidConnectDevice:(NSString *)name;
- (void)deviceMonitorDidDisconnectDevice:(NSString *)name;
@end

@interface JGHDeviceMonitor : NSObject

+ (instancetype)sharedMonitor;

@property (nonatomic, weak, nullable) id<JGHDeviceMonitorDelegate> delegate;
@property (nonatomic, readonly) BOOL running;

/// 开始监听
- (BOOL)start;
/// 停止监听
- (void)stop;

@end

NS_ASSUME_NONNULL_END
