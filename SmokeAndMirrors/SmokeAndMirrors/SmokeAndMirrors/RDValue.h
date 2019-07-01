#import "RDCommon.h"
#import "RDType.h"

NS_ASSUME_NONNULL_BEGIN

#define RDValueBox(VALUE) ({ __auto_type v = (VALUE); [[RDValue alloc] initWithBytes:&v objCType:@encode(typeof(v))]; })
#define RDValueSet(RDVALUE, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) setValue:&v objCType:@encode(typeof(v))]; })
#define RDValueGet(RDVALUE, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) getValue:v objCType:@encode(typeof(*v))]; })

@class RDMutableValue;

@interface RDValue : NSObject<NSCopying, NSMutableCopying, NSSecureCoding>

@property (nonatomic, readonly) RDType *type;
@property (nonatomic, readonly) const char *objCType;

+ (instancetype)valueWithBytes:(const void *)bytes ofType:(RDType *)type;
+ (instancetype)valueWithBytes:(const void *)bytes objCType:(const char *)type;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithBytes:(const void *)bytes objCType:(const char *)type;
- (nullable instancetype)initWithBytes:(const void *)bytes ofType:(RDType *)type NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (BOOL)getValue:(void *)value size:(NSUInteger)size;
- (BOOL)getValue:(void *)value type:(RDType *)type;
- (BOOL)getValue:(void *)value objCType:(const char *)type;

- (RDValue *)copy;
- (RDValue *)copyWithZone:(nullable NSZone *)zone;
- (RDMutableValue *)mutableCopy;
- (RDMutableValue *)mutableCopyWithZone:(nullable NSZone *)zone;

@end

@interface RDMutableValue : RDValue

- (BOOL)setValue:(void *)value size:(NSUInteger)size;
- (BOOL)setValue:(void *)value objCType:(const char *)type;
- (BOOL)setValue:(void *)value type:(RDType *)type;

@end

NS_ASSUME_NONNULL_END
