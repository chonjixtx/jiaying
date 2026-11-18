#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JGHSettings : NSObject

+ (instancetype)sharedSettings;
- (void)reload;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL streamerMode;
@property (nonatomic, readonly) CGFloat mouseSensitivity;
@property (nonatomic, readonly) CGFloat pointerSize;
@property (nonatomic, readonly, copy) NSString *customPointerPath;
@property (nonatomic, readonly, copy) NSString *scrollOrientation;
@property (nonatomic, readonly) NSInteger scrollStep;
@property (nonatomic, readonly) BOOL scrollZoom;

@end

NS_ASSUME_NONNULL_END
