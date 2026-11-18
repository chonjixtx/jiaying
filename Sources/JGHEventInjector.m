//
//  JGHEventInjector.m
//  JiayingGameTweak
//

#import "JGHEventInjector.h"
#import "IOHIDPrivate.h"
#import "JGHCommon.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>

// 私有函数指针类型
typedef IOHIDEventSystemClientRef (*CreateClientFn)(CFAllocatorRef);
typedef void                       (*DispatchEventFn)(IOHIDEventSystemClientRef, IOHIDEventRef);
typedef IOHIDEventRef              (*CreateDigitizerFn)(CFAllocatorRef, uint64_t, IOHIDDigitizerTransducerType,
                                                        uint32_t, uint32_t, uint32_t, uint32_t,
                                                        double, double, double, double, double, double,
                                                        double, bool, uint32_t, IOOptionBits);
typedef void                       (*SetIntFn)(IOHIDEventRef, IOHIDEventField, int);
typedef void                       (*SetFloatFn)(IOHIDEventRef, IOHIDEventField, double);

@interface JGHEventInjector ()
@property (nonatomic) CreateClientFn createClient;
@property (nonatomic) DispatchEventFn dispatchEvent;
@property (nonatomic) CreateDigitizerFn createDigitizer;
@property (nonatomic) SetIntFn setInt;
@property (nonatomic) SetFloatFn setFloat;
@property (nonatomic) IOHIDEventSystemClientRef client;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *downFingers;
@property (nonatomic) BOOL available;
@end

@implementation JGHEventInjector

+ (instancetype)sharedInjector {
    static JGHEventInjector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHEventInjector new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downFingers = [NSMutableSet set];
        [self resolveSymbols];
        if (_available && _createClient) {
            _client = _createClient(kCFAllocatorDefault);
        }
    }
    return self;
}

- (void)resolveSymbols {
    void *handle = RTLD_DEFAULT;

    _createClient    = (CreateClientFn)dlsym(handle, "IOHIDEventSystemClientCreate");
    _dispatchEvent   = (DispatchEventFn)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    _createDigitizer = (CreateDigitizerFn)dlsym(handle, "IOHIDEventCreateDigitizerEvent");

    // 必需符号只有三个；setInt/setFloat 为可选，仅真机调试扩展坐标修正时使用
    _available = _createClient && _dispatchEvent && _createDigitizer;
    if (!_available) {
        JGHLog(@"[警告] IOHIDEvent 私有符号解析失败，触摸注入不可用。请确认已链接 IOKit 私有框架。");
    } else {
        JGHLog(@"IOHIDEvent 符号解析成功");
    }
}

#pragma mark - 坐标换算

// 归一化坐标 (0~1) -> 屏幕点。iOS 16+ 的上屏坐标与 UIScreen 一致。
- (CGPoint)screenPointFromNormalizedX:(CGFloat)x y:(CGFloat)y {
    CGSize size = [UIScreen mainScreen].bounds.size;
    return CGPointMake(MAX(0,MIN(1,x)) * size.width,
                       MAX(0,MIN(1,y)) * size.height);
}

#pragma mark - 事件构造与分发

- (IOHIDEventRef)createEventAtX:(CGFloat)x y:(CGFloat)y
                      eventMask:(uint32_t)eventMask
                     buttonMask:(uint32_t)buttonMask
                        isRange:(bool)isRange
                      fingerID:(uint32_t)fingerID {
    CGPoint p = [self screenPointFromNormalizedX:x y:y];
    uint64_t ts = mach_absolute_time();

    IOHIDEventRef event = _createDigitizer(
        kCFAllocatorDefault,
        ts,
        kIOHIDDigitizerTransducerTypeFinger,
        fingerID + 1,               // index
        fingerID + 1,               // identity
        eventMask,
        buttonMask,
        p.x, p.y, 0.0,              // x, y, z
        1.0,                        // pressure
        8.0, 8.0,                   // width, height
        0.0,                        // orientation
        isRange,
        0,                          // eventFlags
        0                           // options
    );
    if (!event) return NULL;

    // 坐标已在 createDigitizerEvent 参数中给出。
    // 注意：IOHIDEventField* 常量值在不同 iOS SDK 间存在差异，这里不二次写入坐标，
    // 避免用错 field 值反而污染事件。真机若发现坐标偏移，可在此处按目标 SDK 补 setFloat。
    (void)_setFloat;
    (void)_setInt;
    return event;
}

- (void)dispatch:(IOHIDEventRef)event {
    if (!event || !_client || !_dispatchEvent) return;
    _dispatchEvent(_client, event);
    CFRelease(event);
}

#pragma mark - 对外接口

- (void)touchDownAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID {
    if (!_available) return;
    if ([_downFingers containsObject:@(fingerID)]) return; // 防重复按下

    uint32_t mask = kIOHIDDigitizerEventPosition |
                    kIOHIDDigitizerEventTouch |
                    kIOHIDDigitizerEventRange |
                    kIOHIDDigitizerEventIdentity;
    IOHIDEventRef e = [self createEventAtX:x y:y eventMask:mask buttonMask:1 isRange:true fingerID:(uint32_t)fingerID];
    [self dispatch:e];
    [_downFingers addObject:@(fingerID)];
}

- (void)touchMoveAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID {
    if (!_available) return;
    uint32_t mask = kIOHIDDigitizerEventPosition |
                    kIOHIDDigitizerEventTouch;
    IOHIDEventRef e = [self createEventAtX:x y:y eventMask:mask buttonMask:1 isRange:true fingerID:(uint32_t)fingerID];
    [self dispatch:e];
}

- (void)touchUpAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID {
    if (!_available) return;
    uint32_t mask = kIOHIDDigitizerEventPosition |
                    kIOHIDDigitizerEventTouch |
                    kIOHIDDigitizerEventRange |
                    kIOHIDDigitizerEventStop;
    IOHIDEventRef e = [self createEventAtX:x y:y eventMask:mask buttonMask:0 isRange:false fingerID:(uint32_t)fingerID];
    [self dispatch:e];
    [_downFingers removeObject:@(fingerID)];
}

- (void)tapAtX:(CGFloat)x y:(CGFloat)y fingerID:(NSInteger)fingerID {
    [self touchDownAtX:x y:y fingerID:fingerID];
    // 系统需要至少一帧间隔识别为有效点击
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self touchUpAtX:x y:y fingerID:fingerID];
    });
}

- (void)releaseAllTouches {
    for (NSNumber *n in [_downFingers copy]) {
        [self touchUpAtX:0.5 y:0.5 fingerID:n.integerValue];
    }
    [_downFingers removeAllObjects];
}

- (void)dealloc {
    if (_client) CFRelease(_client);
}

@end
