#import "RDCommon.h"
#import "RDType.h"

NS_ASSUME_NONNULL_BEGIN

#define RDValueSet(RDVALUE, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) setValue:&v objCType:@encode(typeof(v))]; })
#define RDValueSetAt(RDVALUE, INDEX, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) setValue:&v objCType:@encode(typeof(v)) atIndex:(INDEX)]; })
#define RDValueGet(RDVALUE, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) getValue:v objCType:@encode(typeof(*v))]; })
#define RDValueGetAt(RDVALUE, INDEX, VALUE) ({ __auto_type v = (VALUE); [(RDVALUE) getValue:v objCType:@encode(typeof(*v)) atIndex:(INDEX)]; })

#define _RD_VAR_ENC(I, VALUE) @encode(typeof(VALUE))
#define _RD_VAR_DCL(I, V) __auto_type __ ##I = (V);
#define _RD_VAR_NOM(I, V) &__ ##I
#define _RD_TUPLE(TYPE, ...) ({ \
_RD_LIST(_RD_VAR_DCL, __VA_ARGS__) \
RDAggregateType *type = [[RDAggregateType alloc] initWithKind:RDAggregateTypeKindStruct name:nil, _RD_CSL(_RD_VAR_ENC, __VA_ARGS__), nil]; \
[[TYPE alloc] initTupleWithType:type, _RD_CSL(_RD_VAR_NOM, __VA_ARGS__)]; \
})
#define _RD_VALUE(TYPE, VALUE) ({ __auto_type v = (VALUE); [[TYPE alloc] initWithBytes:&v objCType:@encode(typeof(v))]; })

#define RDValueBox(VALUE) _RD_VALUE(RDValue, VALUE)
#define RDValueTuple(...) _RD_TUPLE(RDValue, __VA_ARGS__)
#define RDMutableValueBox(VALUE) _RD_VALUE(RDMutableValue, __VA_ARGS__)
#define RDMutableValueTuple(...) _RD_TUPLE(RDMutableValue, __VA_ARGS__)

@class RDValue;
@class RDMutableValue;

@interface RDValue : NSObject<NSCopying, NSMutableCopying, NSSecureCoding>

@property (nonatomic, readonly) RDType *type;
@property (nonatomic, readonly) const char *objCType;

+ (instancetype)valueWithBytes:(nullable const void *)bytes ofType:(RDType *)type;
+ (instancetype)valueWithBytes:(nullable const void *)bytes objCType:(const char *)type;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithBytes:(nullable const void *)bytes objCType:(const char *)type;
- (nullable instancetype)initWithBytes:(nullable const void *)bytes ofType:(RDType *)type NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initTupleWithType:(RDAggregateType *)type, ... NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (BOOL)getValue:(void *)value objCType:(const char *)type;
- (BOOL)getValue:(void *)value type:(RDType *)type;
- (BOOL)getValue:(void *)value objCType:(const char *)type atIndex:(NSUInteger)index;
- (BOOL)getValue:(void *)value type:(RDType *)type atIndex:(NSUInteger)index;
- (BOOL)getValue:(void *)value objCType:(const char *)type forKey:(nullable NSString *)key;
- (BOOL)getValue:(void *)value type:(RDType *)type forKey:(nullable NSString *)key;

- (nullable const uint8_t *)bufferType:(RDType *_Nullable *_Nullable)type;
- (nullable const uint8_t *)bufferAtIndex:(NSUInteger)index type:(RDType *_Nullable *_Nullable)type;
- (nullable const uint8_t *)bufferforKey:(nullable NSString *)key type:(RDType *_Nullable *_Nullable)type;

- (RDValue *)copy;
- (RDValue *)copyWithZone:(nullable NSZone *)zone;
- (RDMutableValue *)mutableCopy;
- (RDMutableValue *)mutableCopyWithZone:(nullable NSZone *)zone;

- (nullable RDValue *)objectAtIndexedSubscript:(NSUInteger)index;
- (nullable RDValue *)objectAtKeyedSubscript:(nullable NSString *)index;

@end

@interface RDMutableValue : RDValue

- (BOOL)setValue:(void *)value objCType:(const char *)type;
- (BOOL)setValue:(void *)value type:(RDType *)type;
- (BOOL)setValue:(void *)value objCType:(const char *)type atIndex:(NSUInteger)index;
- (BOOL)setValue:(void *)value type:(RDType *)type atIndex:(NSUInteger)index;
- (BOOL)setValue:(void *)value objCType:(const char *)type forKey:(NSString *)key;
- (BOOL)setValue:(void *)value type:(RDType *)type forKey:(NSString *)key;

- (nullable uint8_t *)bufferType:(RDType *_Nullable *_Nullable)type;
- (nullable uint8_t *)bufferAtIndex:(NSUInteger)index type:(RDType *_Nullable *_Nullable)type;
- (nullable uint8_t *)bufferforKey:(nullable NSString *)key type:(RDType *_Nullable *_Nullable)type;

- (BOOL)setObject:(RDValue *)value atIndexedSubscript:(NSUInteger)index;
- (BOOL)setObject:(RDValue *)value atKeyedSubscript:(nullable NSString *)key;

@end

NS_ASSUME_NONNULL_END
