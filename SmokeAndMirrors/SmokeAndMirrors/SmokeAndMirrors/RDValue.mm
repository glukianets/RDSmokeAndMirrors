#import "RDValue.h"
#import "RDPrivate.h"

#import <malloc/malloc.h>
#import <objc/runtime.h>
#import <cstdarg>

#define DATA(VAR) (uint8_t *)RD_FLEX_ARRAY_RAW_ELEMENT(VAR, VAR->_type.size, VAR->_type.alignment, 0)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static inline bool copy(void *dst, RDType *dstType, const void *src, RDType *srcType) {
    BOOL isSafe = src != NULL
               && dst != NULL
               && srcType != nil
               && dstType != nil
               && dstType.size != RDTypeSizeUnknown
               && dstType.alignment != RDTypeAlignUnknown
               && [dstType isAssignableFromType:srcType]
               && (uintptr_t)dst % dstType.alignment == 0;
    
    if (!isSafe)
        return NO;
    
    [dstType _value_releaseBytes:dst];
    memcpy(dst, src, dstType.size);
    [dstType _value_retainBytes:dst];
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDValue()

- (instancetype)_init NS_DESIGNATED_INITIALIZER;

@end

@implementation RDValue {
    @protected
    RDType *_type;
}

#pragma mark Initialization

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    if (self == RDValue.self || self == RDMutableValue.self) {
        static RDValue *instance = class_createInstance(RDValue.self, 0);
        static RDMutableValue *mutableInstance = class_createInstance(RDMutableValue.self, 0);
        return (self == RDValue.self ? instance : mutableInstance);
    } else {
        return [super alloc];
    }
}

- (void)dealloc {
    [_type _value_releaseBytes:DATA(self)];
}

+ (instancetype)valueWithBytes:(const void *)bytes ofType:(RDType *)type {
    return [[self alloc] initWithBytes:bytes ofType:type];
}

+ (instancetype)valueWithBytes:(const void *)bytes objCType:(const char *)type {
    return [[self alloc] initWithBytes:bytes objCType:type];
}

- (instancetype)_init {
    self = [super init];
    if (self) {
        _type = RDVoidType.instance;
    }
    return self;
}

- (instancetype)init {
    static RDValue *instance = [(RDValue *)class_createInstance(self.class, 0) _init];
    return instance;
}

- (instancetype)initWithBytes:(const void *)bytes objCType:(const char *)type {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self initWithBytes:bytes ofType:rdtype];
    else
        return nil;
}

- (instancetype)initWithBytes:(const void *)bytes ofType:(RDType *)type {
    size_t size = type.size;
    size_t alignment = type.alignment;

    if (size == RDTypeSizeUnknown || size == 0 || alignment == RDTypeAlignUnknown || alignment == 0)
        return nil;
    
    self = RD_FLEX_ARRAY_RAW_CREATE(self.class, size, alignment, 1);
    self = [super init];
    if (self) {
        _type = type;
        if (bytes != NULL)
            memcpy(DATA(self), bytes, size);
        else
            memset(DATA(self), 0, size);
        [_type _value_retainBytes:DATA(self)];
    }
    return self;
}

- (nullable instancetype)initTupleWithType:(RDAggregateType *)type, ... {
    if (type == nil || type.kind != RDAggregateTypeKindStruct)
        return nil;
    
    size_t size = type.size;
    size_t alignment = type.alignment;
    
    if (size == RDTypeSizeUnknown || size == 0 || alignment == RDTypeAlignUnknown || alignment == 0)
        return nil;
    
    self = RD_FLEX_ARRAY_RAW_CREATE(self.class, size, alignment, 1);
    self = [super init];
    if (self) {
        _type = type;
        
        va_list ap;
        va_start(ap, type);
        for (NSUInteger i = 0; i < type.count; ++i)
            if (const void *data = va_arg(ap, const void *); data == NULL)
                continue;
            else if (RDField *field = [type fieldAtIndex:i]; field == NULL || field->offset == RDOffsetUnknown)
                continue;
            else if (RDType *fieldType = field->type; fieldType == nil || fieldType.size == RDTypeSizeUnknown)
                continue;
            else
                memcpy(DATA(self) + field->offset, data, field->type.size);
        va_end(ap);
        
        [_type _value_retainBytes:DATA(self)];
    }
    return self;
}

#pragma mark Interface

- (BOOL)getValue:(void *)value objCType:(const char *)type {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self getValue:value type:rdtype];
    else
        return NO;
}

- (BOOL)getValue:(void *)value type:(RDType *)type {
    RDType *dataType = nil;
    const uint8_t *data = [self bufferType:&dataType];
    return data != NULL && copy(value, type, data, dataType);
}

- (BOOL)getValue:(void *)value objCType:(const char *)type atIndex:(NSUInteger)index {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self getValue:value type:rdtype atIndex:index];
    else
        return NO;
}

- (BOOL)getValue:(void *)value type:(RDType *)type atIndex:(NSUInteger)index {
    RDType *dataType = nil;
    const uint8_t *data = [self bufferAtIndex:index type:&dataType];
    return data != NULL && copy(value, type, data, dataType);
}

- (BOOL)getValue:(void *)value objCType:(const char *)type forKey:(nullable NSString *)key {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self getValue:value type:rdtype forKey:key];
    else
        return NO;
}

- (BOOL)getValue:(void *)value type:(RDType *)type forKey:(nullable NSString *)key {
    RDType *dataType = nil;
    const uint8_t *data = [self bufferforKey:key type:&dataType];
    return data != NULL && copy(value, type, data, dataType);
}

- (nullable const uint8_t *)bufferType:(RDType *_Nullable *_Nullable)type {
    if (type != NULL)
        *type = _type;
    
    return DATA(self);
}

- (nullable const uint8_t *)bufferAtIndex:(NSUInteger)index type:(RDType *_Nullable *_Nullable)type {
    if (RDArrayType *rdtype = RD_CAST(self.type, RDArrayType); rdtype != nil) {
        if (RDOffset offset = [rdtype offsetForElementAtIndex:index]; offset != RDOffsetUnknown)
            return (void)(type != NULL && (*type = rdtype.type)), DATA(self) + offset;

    } else if (RDAggregateType *rdtype = RD_CAST(self.type, RDAggregateType); rdtype != nil) {
        if (RDField *field = [rdtype fieldAtIndex:index]; field != NULL && field->offset != RDOffsetUnknown && field->type != nil)
            return (void)(type != NULL && (*type = field->type)), DATA(self) + field->offset;
    }
    
    if (type != NULL)
        *type = nil;
    return NULL;
}

- (nullable const uint8_t *)bufferforKey:(nullable NSString *)key type:(RDType *_Nullable *_Nullable)type {
    if (key.length > 0) {
        if (RDAggregateType *rdtype = RD_CAST(self.type, RDAggregateType); rdtype != nil) {
            if (RDField *field = [rdtype fieldWithName:key]; field != NULL && field->offset != RDOffsetUnknown && field->type != nil)
                return (void)(type != NULL && (*type = field->type)), DATA(self) + field->offset;

        } else if (RDArrayType *rdtype = RD_CAST(self.type, RDArrayType); rdtype != nil) {
            if (NSInteger index = key.integerValue; index > 0 || [key isEqualToString:@"0"])
                if (RDOffset offset = [rdtype offsetForElementAtIndex:index]; offset != RDOffsetUnknown)
                    return (void)(type != NULL && (*type = rdtype.type)), DATA(self) + offset;
        }
    }
    
    if (type != NULL)
        *type = nil;
    return NULL;
}

- (NSString *)description {
    return [NSString stringWithFormat:[self.type _value_formatWithBytes:DATA(self)],
            [NSString stringWithFormat:@"value_at_%p", self]];
}

- (NSString *)debugDescription {
    return [self.type _value_describeBytes:DATA(self) additionalInfo:nil];
}

- (const char *)objCType {
    return _type.objCTypeEncoding;
}

#pragma mark <NSCopying>

- (RDValue *)copy {
    return [self copyWithZone:nil];
}

- (RDValue *)copyWithZone:(NSZone *)zone {
    if (self.class == RDValue.self)
        return self;
    else
        return [[RDValue alloc] initWithBytes:DATA(self) ofType:_type];
}

#pragma mark <NSMutableCopying>

- (RDMutableValue *)mutableCopy {
    return [self mutableCopyWithZone:nil];
}

- (RDMutableValue *)mutableCopyWithZone:(NSZone *)zone {
    return [[RDMutableValue alloc] initWithBytes:DATA(self) ofType:_type];
}

#pragma mark <NSSecureCopying>

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark <NSCopying>

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    RDType *type = [coder decodeObjectOfClass:RDType.self forKey:@"type"];
    if (type == nil)
        return nil;
    
    NSUInteger size = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:@"data" returnedLength:&size];
    if (bytes == NULL || size != type.size)
        return nil;
    
    return [[self.class alloc] initWithBytes:bytes ofType:type];
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    if (_type != nil && _type.size != RDTypeSizeUnknown) {
        [coder encodeObject:_type forKey:@"type"];
        [coder encodeBytes:DATA(self) length:_type.size forKey:@"data"];
    } else {
        [coder encodeObject:nil forKey:@"type"];
    }
}

#pragma mark Subscripting

- (RDValue *)objectAtIndexedSubscript:(NSUInteger)index {
    if (RDArrayType *type = RD_CAST(self.type, RDArrayType); type != nil) {
        if (index < type.count)
            return [RDValue valueWithBytes:DATA(self) + [type offsetForElementAtIndex:index] ofType:type.type];
        else
            return nil;

    } else if (RDAggregateType *type = RD_CAST(self.type, RDAggregateType); type != nil) {
        if (index >= type.count)
            return nil;
            
        if (RDField *field = [type fieldAtIndex:index]; field != NULL && field->type != nil && field->offset != RDOffsetUnknown)
            return [RDValue valueWithBytes:DATA(self) + field->offset ofType:field->type];
        else
            return nil;

    } else {
        return nil;
    }
}

- (RDValue *)objectAtKeyedSubscript:(NSString *)key {
    if (key == nil) {
        return nil;
    } else if (RDAggregateType *type = RD_CAST(self.type, RDAggregateType); type != nil) {
        for (NSUInteger i = 0; i < type.count; ++i)
            if (RDField *field = [type fieldAtIndex:i]; field != NULL)
                if ([key isEqualToString:field->name] && field->type != nil && field->offset != RDOffsetUnknown)
                    return [RDValue valueWithBytes:DATA(self) + field->offset ofType:field->type];

        return nil;
        
    } else {
        return nil;
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDMutableValue

- (BOOL)setValue:(void *)value objCType:(const char *)type {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self setValue:value type:rdtype];
    else
        return NO;
}

- (BOOL)setValue:(void *)value type:(RDType *)type {
    return copy(DATA(self), _type, value, type);
}

- (BOOL)setValue:(void *)value objCType:(const char *)type atIndex:(NSUInteger)index; {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self setValue:value type:rdtype atIndex:index];
    else
        return NO;
}

- (BOOL)setValue:(void *)value type:(RDType *)type atIndex:(NSUInteger)index {
    if (RDArrayType *rdtype = RD_CAST(self.type, RDArrayType); rdtype != nil) {
        if (RDOffset offset = [rdtype offsetForElementAtIndex:index]; offset != RDOffsetUnknown)
            return copy(DATA(self) + offset, rdtype.type, value, type);
    } else if (RDAggregateType *rdtype = RD_CAST(self.type, RDAggregateType); rdtype != nil) {
        if (RDField *field = [rdtype fieldAtIndex:index]; field != NULL && field->offset != RDOffsetUnknown && field->type != nil)
            return copy(DATA(self) + field->offset, field->type, value, type);
    }

    return NO;
}

- (BOOL)setValue:(void *)value objCType:(const char *)type forKey:(NSString *)key {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self setValue:value type:rdtype forKey:key];
    else
        return NO;
}

- (BOOL)setValue:(void *)value type:(RDType *)type forKey:(NSString *)key {
    if (key.length > 0)
        if (RDAggregateType *rdtype = RD_CAST(self.type, RDAggregateType); rdtype != nil)
            if (RDField *field = [rdtype fieldWithName:key]; field != NULL && field->offset != RDOffsetUnknown && field->type != nil)
                return copy(DATA(self) + field->offset, field->type, value, type);
    
    return NO;
}

- (nullable uint8_t *)bufferType:(RDType *_Nullable *_Nullable)type {
    return (uint8_t *)[super bufferType:type];
}

- (nullable uint8_t *)bufferAtIndex:(NSUInteger)index type:(RDType *_Nullable *_Nullable)type {
    return (uint8_t *)[super bufferAtIndex:(NSUInteger)index type:type];
}
- (nullable uint8_t *)bufferforKey:(nullable NSString *)key type:(RDType *_Nullable *_Nullable)type {
    return (uint8_t *)[super bufferforKey:key type:type];
}

- (BOOL)setObject:(RDValue *)value atIndexedSubscript:(NSUInteger)index {
    if (RDArrayType *type = RD_CAST(self.type, RDArrayType); type != nil) {
        if (index < type.count)
            return copy(DATA(self) + [type offsetForElementAtIndex:index], type.type, DATA(value), value->_type);
        else
            return NO;
        
    } else if (RDAggregateType *type = RD_CAST(self.type, RDAggregateType); type != nil) {
        if (RDField *field = [type fieldAtIndex:index]; field != NULL && field->type != nil && field->offset != RDOffsetUnknown)
            return copy(DATA(self) + field->offset, field->type, DATA(value), value->_type);
        else
            return NO;
        
    } else {
        return NO;
    }
}

- (BOOL)setObject:(RDValue *)value atKeyedSubscript:(NSString *)key {
    if (key == nil)
        return NO;
    else if (RDAggregateType *type = RD_CAST(self.type, RDAggregateType); type != nil)
        if (RDField *field = [type fieldWithName:key]; field != NULL && field->type != nil && field->offset != RDOffsetUnknown)
            return copy(DATA(self) + field->offset, field->type, DATA(value), value->_type);
        
    return NO;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
