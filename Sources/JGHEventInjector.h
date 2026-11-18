//
//  JGHEventInjector.h
//  JiayingGameTweak
//
//  通过 IOHIDEvent 向系统注入触摸事件（点按/长按/滑动/摇杆）。
//  私有符号通过 dlsym 动态解析，避免链接期依赖未导出的符号。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JGHEventInjector : NSObject

+ (instancetype)sharedInjector;

/// 私有 API 是否可用（dlsym 是否全部解析成功）
@property (nonatomic, readonly) BOOL available;

/// 按下（fingerID 用于多点触控区分手指，0 为主手指）
- (void)touchDownAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID;
/// 移动
- (void)touchMoveAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID;
/// 抬起
- (void)touchUpAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID;
/// 单击（自动 down + up）
- (void)tapAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID;

/// 清理所有仍按下的手指（如 App 切后台时调用）
- (void)releaseAllTouches;

@end

NS_ASSUME_NONNULL_END
