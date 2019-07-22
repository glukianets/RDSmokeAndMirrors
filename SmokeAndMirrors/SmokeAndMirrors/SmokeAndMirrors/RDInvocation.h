#import <Foundation/Foundation.h>
#import "RDValue.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const RDInvocationErrorDomain;

RD_FINAL_CLASS
@interface RDInvocation : NSObject

@property (nonatomic, readonly) RDValue *arguments;

+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)invocationWithArguments:(RDValue *)arguments;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithArguments:(RDValue *)arguments;

- (nullable RDValue *)invokeWithTarget:(nullable id<NSObject>)target
                          selector:(SEL)selector;
- (nullable RDValue *)invokeWithTarget:(nullable id<NSObject>)target
                          selector:(SEL)selector
                             error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
