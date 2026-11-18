//
//  IOHIDPrivate.h
//  JiayingGameTweak
//
//  iOS SDK 不公开 IOKit 的 HID 事件注入/监听接口，这里做最小化前向声明。
//  注意：不同 iOS 版本的结构体布局/函数签名可能有差异，真机调试时以
//  $THEOS/sdks/iPhoneOS*.sdk/System/Library/Frameworks/IOKit.framework 内头文件为准。
//

#ifndef IOHIDPrivate_h
#define IOHIDPrivate_h

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>
#include <IOKit/IOTypes.h>

#pragma mark - IOHIDEvent（触摸注入）

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

// IOHIDEvent 字段类型（iOS SDK 私有头中定义为 CFIndex 的整数类型）
typedef CFIndex IOHIDEventField;

typedef enum {
    kIOHIDDigitizerTransducerTypeStylus = 0,
    kIOHIDDigitizerTransducerTypePuck   = 1,
    kIOHIDDigitizerTransducerTypeFinger = 2,
    kIOHIDDigitizerTransducerTypeHand   = 3
} IOHIDDigitizerTransducerType;

enum {
    kIOHIDDigitizerEventRange            = 0x00000001,
    kIOHIDDigitizerEventTouch            = 0x00000002,
    kIOHIDDigitizerEventPosition         = 0x00000004,
    kIOHIDDigitizerEventStop             = 0x00000008,
    kIOHIDDigitizerEventPeak             = 0x00000010,
    kIOHIDDigitizerEventIdentity         = 0x00000020,
    kIOHIDDigitizerEventAttribute        = 0x00000040,
    kIOHIDDigitizerEventCancel           = 0x00000400,
    kIOHIDDigitizerEventDisplay          = 0x00000800,
};

typedef enum {
    kIOHIDEventFieldDigitizerX         = 0x0020000,
    kIOHIDEventFieldDigitizerY         = 0x0020001,
    kIOHIDEventFieldDigitizerZ         = 0x0020002,
    kIOHIDEventFieldDigitizerRange     = 0x0020004,
    kIOHIDEventFieldDigitizerTouch     = 0x0020005,
    kIOHIDEventFieldDigitizerPressure  = 0x0020007,
} IOHIDEventFieldDigitizer;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(
    CFAllocatorRef allocator,
    uint64_t timeStamp,
    IOHIDDigitizerTransducerType type,
    uint32_t index,
    uint32_t identity,
    uint32_t eventMask,
    uint32_t buttonMask,
    double x,
    double y,
    double z,
    double pressure,
    double width,
    double height,
    double orientation,
    bool isRange,
    uint32_t eventFlags,
    IOOptionBits options);

extern void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
extern void IOHIDEventSetFloatValue(IOHIDEventRef event, IOHIDEventField field, double value);
extern void IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef childEvent);

#pragma mark - IOHIDManager（外设监听）

typedef struct __IOHIDManager *IOHIDManagerRef;
typedef struct __IOHIDDevice *IOHIDDeviceRef;
typedef struct __IOHIDElement *IOHIDElementRef;
typedef struct __IOHIDValue *IOHIDValueRef;

typedef enum {
    kIOHIDValueScaleTypeCalibrated = 0,
    kIOHIDValueScaleTypePhysical   = 1,
} IOHIDValueScaleType;

typedef void (*IOHIDDeviceCallback)(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);
typedef void (*IOHIDValueCallback)(void *context, IOReturn result, void *sender, IOHIDValueRef value);

enum {
    kIOHIDManagerOptionNone = 0,
    kIOHIDManagerOptionUsePersistentProperties = 1 << 0,
    kIOHIDManagerOptionDoNotLoadProperties     = 1 << 2,
};

extern IOHIDManagerRef IOHIDManagerCreate(CFAllocatorRef allocator, IOOptionBits options);
extern void IOHIDManagerUnscheduleFromRunLoop(IOHIDManagerRef manager, CFRunLoopRef runLoop, CFStringRef mode);
extern void IOHIDManagerSetDeviceMatching(IOHIDManagerRef manager, CFDictionaryRef matching);
// 多条件匹配：接受 CFArrayRef（数组元素是 CFDictionaryRef）
extern void IOHIDManagerSetDeviceMatchingMultiple(IOHIDManagerRef manager, CFArrayRef matching);
extern void IOHIDManagerRegisterDeviceMatchingCallback(IOHIDManagerRef manager, IOHIDDeviceCallback callback, void *context);
extern void IOHIDManagerRegisterDeviceRemovalCallback(IOHIDManagerRef manager, IOHIDDeviceCallback callback, void *context);
extern void IOHIDManagerRegisterInputValueCallback(IOHIDManagerRef manager, IOHIDValueCallback callback, void *context);
extern IOReturn IOHIDManagerOpen(IOHIDManagerRef manager, IOOptionBits options);
extern IOReturn IOHIDManagerClose(IOHIDManagerRef manager, IOOptionBits options);
extern void IOHIDManagerScheduleWithRunLoop(IOHIDManagerRef manager, CFRunLoopRef runLoop, CFStringRef mode);
extern CFSetRef IOHIDManagerCopyDevices(IOHIDManagerRef manager);

extern CFTypeRef IOHIDDeviceGetProperty(IOHIDDeviceRef device, CFStringRef key);
extern IOHIDValueRef IOHIDDeviceGetValue(IOHIDDeviceRef device, IOHIDElementRef element, IOReturn *result);
extern CFArrayRef IOHIDDeviceCopyMatchingElements(IOHIDDeviceRef device, CFDictionaryRef matching, IOOptionBits options);

extern IOHIDElementRef IOHIDValueGetElement(IOHIDValueRef value);
extern CFIndex IOHIDValueGetIntegerValue(IOHIDValueRef value);
extern double IOHIDValueGetScaledValue(IOHIDValueRef value, IOHIDValueScaleType type);
extern uint32_t IOHIDElementGetUsage(IOHIDElementRef element);
extern uint32_t IOHIDElementGetUsagePage(IOHIDElementRef element);
extern uint32_t IOHIDElementGetLogicalMin(IOHIDElementRef element);
extern uint32_t IOHIDElementGetLogicalMax(IOHIDElementRef element);

// 常用属性键用字符串字面量（CFSTR("Product") 等），不声明 extern 符号，
// 避免链接未公开符号导致 undefined symbol。

// Usage Page
enum {
    kHIDPage_GenericDesktop    = 0x01,
    kHIDPage_KeyboardOrKeypad  = 0x07,
    kHIDPage_LEDs              = 0x08,
    kHIDPage_Button            = 0x09,
    kHIDPage_Consumer          = 0x0C,
};

#endif /* IOHIDPrivate_h */
