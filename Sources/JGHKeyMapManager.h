//
//  JGHKeyMapManager.h
//  JiayingGameTweak
//
//  键位映射配置管理：HID 按键 (usagePage:usage) -> 触摸动作。
//  配置文件为 JSON，存放在 JGHCommon.profilesDirectory。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JGHActionType) {
    JGHActionTypeTap      = 0,  // 点按
    JGHActionTypeHold     = 1,  // 长按（按住即保持按下）
    JGHActionTypeSwipe    = 2,  // 滑动（从 x,y 沿 dx,dy 划动）
    JGHActionTypeJoystick = 3,  // 虚拟摇杆（组合键产生方向）
};

@interface JGHAction : NSObject <NSCoding>
@property (nonatomic) JGHActionType type;
@property (nonatomic) CGFloat x;      // 归一化 0~1
@property (nonatomic) CGFloat y;
@property (nonatomic) CGFloat dx;     // swipe 方向/摇杆位移
@property (nonatomic) CGFloat dy;
@property (nonatomic) NSInteger fingerID; // 多点触摸编号（默认 0）
+ (instancetype)actionWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface JGHProfile : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;   // 目标 App bundle id，* 表示通用
@property (nonatomic, strong) NSMutableDictionary<NSString *, JGHAction *> *mappings;
+ (nullable instancetype)profileWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface JGHKeyMapManager : NSObject

+ (instancetype)sharedManager;

/// 生成映射键：@"usagePage:usage"
+ (NSString *)keyForUsagePage:(uint32_t)page usage:(uint32_t)usage;

@property (nonatomic, strong, readonly) NSArray<JGHProfile *> *profiles;
@property (nonatomic, strong, nullable) JGHProfile *activeProfile;

/// 重新从磁盘加载全部配置
- (void)reloadProfiles;

/// 根据当前 App 的 bundleID 自动选择 profile
- (void)selectProfileForBundleID:(NSString *)bundleID;

/// 查询动作，无映射返回 nil
- (nullable JGHAction *)actionForUsagePage:(uint32_t)page usage:(uint32_t)usage;

/// 保存 activeProfile 到磁盘
- (BOOL)saveActiveProfile:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
