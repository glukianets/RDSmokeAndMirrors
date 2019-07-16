#import <Foundation/Foundation.h>
#import "RDValue.h"

NS_ASSUME_NONNULL_BEGIN

RD_FINAL_CLASS
@interface RDMessage : NSObject

@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly) RDValue *arguments;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (nullable instancetype)messageWithSelector:(SEL)selector arguments:(RDValue *)arguments;
- (nullable instancetype)initWithSelector:(SEL)selector arguments:(RDValue *)arguments;

@end

RD_FINAL_CLASS
@interface RDInvocation : NSObject

@property (nonatomic, readonly) RDMethodSignature *signature;
@property (nonatomic, readonly) RDMessage *message;

- (instancetype)initWithSignature:(RDMethodSignature *)signature message:(RDMessage *)message;

@end

NS_ASSUME_NONNULL_END
