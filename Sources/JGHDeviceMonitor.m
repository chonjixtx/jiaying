//
//  JGHDeviceMonitor.m
//  JiayingGameTweak
//

#import "JGHDeviceMonitor.h"
#import "IOHIDPrivate.h"
#import "JGHCommon.h"
#import "JGHSettings.h"
#import <math.h>
#import <UIKit/UIKit.h>

// C 回调桥接：把 IOHIDManager 回调转发给 ObjC delegate
static void JGHDeviceMatched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    JGHDeviceMonitor *self = (__bridge JGHDeviceMonitor *)context;
    CFStringRef nameRef = (CFStringRef)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSString *name = nameRef ? (__bridge NSString *)nameRef : @"未知设备";
    JGHLog(@"外设已连接: %@", name);
    if ([self.delegate respondsToSelector:@selector(deviceMonitorDidConnectDevice:)]) {
        [self.delegate deviceMonitorDidConnectDevice:name];
    }
}

static void JGHDeviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    JGHDeviceMonitor *self = (__bridge JGHDeviceMonitor *)context;
    CFStringRef nameRef = (CFStringRef)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSString *name = nameRef ? (__bridge NSString *)nameRef : @"未知设备";
    JGHLog(@"外设已断开: %@", name);
    if ([self.delegate respondsToSelector:@selector(deviceMonitorDidDisconnectDevice:)]) {
        [self.delegate deviceMonitorDidDisconnectDevice:name];
    }
}

static void JGHInputValue(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    JGHDeviceMonitor *self = (__bridge JGHDeviceMonitor *)context;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t page = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);

    // 忽略 Keyboard 的 rollover/error 等无效 usage
    if (page == kHIDPage_KeyboardOrKeypad && (usage == 0x00 || usage == 0x01)) return;

    // 鼠标相对移动：维护虚拟指针并广播坐标
    if (page == kHIDPage_GenericDesktop && (usage == 0x30 || usage == 0x31)) {
        double delta = IOHIDValueGetIntegerValue(value);
        CGFloat sensitivity = [JGHSettings sharedSettings].mouseSensitivity;
        if (usage == 0x30) self.pointerX += delta * sensitivity;
        else self.pointerY += delta * sensitivity;
        CGSize screen = [UIScreen mainScreen].bounds.size;
        self.pointerX = MAX(0, MIN(screen.width, self.pointerX));
        self.pointerY = MAX(0, MIN(screen.height, self.pointerY));
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JGHPointerDidMove"
                                                            object:nil
                                                          userInfo:@{@"x": @(self.pointerX), @"y": @(self.pointerY)}];
        return;
    }

    // 鼠标滚轮：转换为触摸滑动
    if (page == kHIDPage_GenericDesktop && usage == 0x38) {
        NSInteger step = [JGHSettings sharedSettings].scrollStep;
        double wheel = IOHIDValueGetIntegerValue(value);
        NSString *orientation = [JGHSettings sharedSettings].scrollOrientation;
        CGFloat dx = [orientation isEqualToString:@"horizontal"] ? (CGFloat)(wheel * step) : 0;
        CGFloat dy = [orientation isEqualToString:@"horizontal"] ? 0 : (CGFloat)(wheel * step);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JGHScrollDidMove"
                                                            object:nil
                                                          userInfo:@{@"x": @(self.pointerX),
                                                                     @"y": @(self.pointerY),
                                                                     @"dx": @(dx), @"dy": @(dy)}];
        return;
    }

    double scaled = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated);
    CFIndex integer = IOHIDValueGetIntegerValue(value);

    // 数字按键：integer==0 视为松开；模拟量（摇杆/扳机）：以中值为界
    uint32_t logicalMin = IOHIDElementGetLogicalMin(element);
    uint32_t logicalMax = IOHIDElementGetLogicalMax(element);
    BOOL analog = (logicalMax - logicalMin) > 1;
    BOOL down;
    if (analog) {
        double mid = (logicalMin + logicalMax) / 2.0;
        // 摇杆轴：远离中值即视为“按下”，便于映射到方向键
        down = fabs(scaled - mid) > (logicalMax - logicalMin) * 0.3;
    } else {
        down = (integer != 0);
    }

    if ([self.delegate respondsToSelector:@selector(deviceMonitorDidReceiveUsagePage:usage:value:down:)]) {
        [self.delegate deviceMonitorDidReceiveUsagePage:page usage:usage value:scaled down:down];
    }
}

@interface JGHDeviceMonitor ()
@property (nonatomic) IOHIDManagerRef manager;
@property (nonatomic, readwrite) BOOL running;
@property (nonatomic) CGFloat pointerX;
@property (nonatomic) CGFloat pointerY;
@end

@implementation JGHDeviceMonitor

+ (instancetype)sharedMonitor {
    static JGHDeviceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [JGHDeviceMonitor new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        CGSize screen = [UIScreen mainScreen].bounds.size;
        _pointerX = screen.width / 2;
        _pointerY = screen.height / 2;
    }
    return self;
}

- (BOOL)start {
    if (_running) return YES;

    _manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    if (!_manager) {
        JGHLog(@"IOHIDManager 创建失败");
        return NO;
    }

    // 匹配键盘、鼠标/指针、手柄（Generic Desktop / Button / Consumer）
    // 用字符串字面量作为 key/value，避免依赖 IOKit 里的 extern CFString 符号
    // （kIOHIDDeviceUsagePageKey = "DeviceUsagePage"，kIOHIDDeviceUsageKey = "DeviceUsage"）
    NSString *pageKey = @"DeviceUsagePage";
    NSString *usageKey = @"DeviceUsage";
    NSArray *matching = @[
        @{pageKey: @(kHIDPage_KeyboardOrKeypad)},
        @{pageKey: @(kHIDPage_GenericDesktop), usageKey: @(2)},   // Mouse
        @{pageKey: @(kHIDPage_GenericDesktop), usageKey: @(4)},   // Joystick
        @{pageKey: @(kHIDPage_GenericDesktop), usageKey: @(5)},   // Game Pad
        @{pageKey: @(kHIDPage_Button)},
    ];
    // matching 是 NSArray，必须用 SetDeviceMatchingMultiple + CFArrayRef，
    // 强转 CFDictionaryRef 会触发 -Wbridge-cast 并在 -Werror 下编译失败。
    IOHIDManagerSetDeviceMatchingMultiple(_manager, (__bridge CFArrayRef)matching);

    IOHIDManagerRegisterDeviceMatchingCallback(_manager, JGHDeviceMatched, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, JGHDeviceRemoved, (__bridge void *)self);
    IOHIDManagerRegisterInputValueCallback(_manager, JGHInputValue, (__bridge void *)self);

    IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOReturn ret = IOHIDManagerOpen(_manager, kIOHIDManagerOptionNone);
    if (ret != kIOReturnSuccess) {
        JGHLog(@"IOHIDManager 打开失败: 0x%08x", ret);
        CFRelease(_manager);
        _manager = NULL;
        return NO;
    }

    _running = YES;
    JGHLog(@"外设监听已启动");
    return YES;
}

- (void)stop {
    if (!_running) return;
    IOHIDManagerUnscheduleFromRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOHIDManagerClose(_manager, kIOHIDManagerOptionNone);
    CFRelease(_manager);
    _manager = NULL;
    _running = NO;
    JGHLog(@"外设监听已停止");
}

- (void)dealloc {
    [self stop];
}

@end
