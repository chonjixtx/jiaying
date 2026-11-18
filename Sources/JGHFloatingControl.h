//
//  JGHFloatingControl.h
//  JiayingGameTweak
//
//  悬浮控制面板：可拖拽，提供 启用/停用、重新加载配置、隐藏 按钮。
//  面板窗口除按钮区域外触摸穿透，不阻挡游戏操作。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JGHFloatingControl : NSObject

+ (instancetype)sharedControl;

/// 当前映射是否启用
@property (nonatomic, readonly) BOOL enabled;

/// 显示面板（若已显示则忽略）
- (void)show;
/// 隐藏面板
- (void)dismiss;
/// 切换显隐
- (void)toggle;

@end

NS_ASSUME_NONNULL_END
