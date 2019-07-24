#import "RDValue.h"
#import "RDPrivate.h"
#import <malloc/malloc.h>
#import <objc/runtime.h>
#import <cstdarg>

#define DATA(VAR) (uint8_t *)RD_FLEX_ARRAY_RAW_ELEMENT(VAR, VAR->_type.size, VAR->_type.alignment, 0)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDType(RDValue)

- (void)_value_retainBytes:(void *)bytes;
- (void)_value_releaseBytes:(void *)bytes;
- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info;
- (NSString *)_value_formatWithBytes:(void *)bytes;

@end

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

@implementation RDType(RDValue)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return nil;
}

- (NSString *)_value_formatWithBytes:(void *)bytes {
    NSMutableArray *more = [NSMutableArray array];
    NSString *desc = [self _value_describeBytes:bytes additionalInfo:more];
    NSString *decl = self.format;
    return [NSString stringWithFormat:@"%@ = %@;\n%@", decl, desc, [more componentsJoinedByString:@"\n\n"]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnknownType(RDValue)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType(RDValue)
@end

@implementation RDObjectType(RDValue)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    switch (self.kind) {
    case RDObjectTypeKindGeneric:
        *(void **)bytes = (__bridge void *)objc_retain((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindBlock:
        *(void **)bytes = (__bridge void *)objc_retainBlock((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindClass:
        //do nothing
        break;
    }
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    switch (self.kind) {
    case RDObjectTypeKindGeneric:
    case RDObjectTypeKindBlock:
        objc_release((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindClass:
        //do nothing
        break;
    }

}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    if (NSString *description = [(__bridge id)*(void **)bytes description]; description != nil)
        [info addObject:[NSString stringWithFormat:@"Printing description of (%@)%p:\n%@", self.description, *(void **)bytes, description]];

    if (void *ptr = *(void **)bytes; ptr != NULL)
        switch (self.kind) {
        case RDObjectTypeKindGeneric:
        case RDObjectTypeKindBlock:
            return [NSString stringWithFormat:@"(%@)%p", self.description, ptr];
        case RDObjectTypeKindClass:
            return [NSString stringWithFormat:@"%@.self", NSStringFromClass(*(Class *)bytes)];
        }
    else
        return @"nil";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDVoidType(RDValue)
@end

@implementation RDVoidType(RDValue)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return @"void";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPrimitiveType(RDValue)
@end

@implementation RDPrimitiveType(RDValue)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    switch (self.kind) {
        case RDPrimitiveTypeKindSelector:
            return [NSString stringWithFormat:@"@selector(%s)", sel_getName(*(SEL *)bytes)];
        case RDPrimitiveTypeKindCString:
            return [NSString stringWithFormat:@"c string at \"%p\"", *(const char **)bytes];
        case RDPrimitiveTypeKindAtom:
            return [NSString stringWithFormat:@"?"];
        case RDPrimitiveTypeKindChar:
            return [NSString stringWithFormat:@"'%c'", *(char *)bytes];
        case RDPrimitiveTypeKindUnsignedChar:
            return [NSString stringWithFormat:@"(unsigned char)'%c'", *(unsigned char *)bytes];
        case RDPrimitiveTypeKindBool:
            return [NSString stringWithFormat:@"%s", *(unsigned char *)bytes ? "true" : "false"];
        case RDPrimitiveTypeKindShort:
            return [NSString stringWithFormat:@"(short)%d", *(short *)bytes];
        case RDPrimitiveTypeKindUnsignedShort:
            return [NSString stringWithFormat:@"(unsigned short)%du", *(unsigned short *)bytes];
        case RDPrimitiveTypeKindInt:
            return [NSString stringWithFormat:@"%d", *(int *)bytes];
        case RDPrimitiveTypeKindUnsignedInt:
            return [NSString stringWithFormat:@"%du", *(unsigned int *)bytes];
        case RDPrimitiveTypeKindLong:
            return [NSString stringWithFormat:@"%ldl", *(long *)bytes];
        case RDPrimitiveTypeKindUnsignedLong:
            return [NSString stringWithFormat:@"%luul", *(unsigned long *)bytes];
        case RDPrimitiveTypeKindLongLong:
            return [NSString stringWithFormat:@"%lldll", *(long long int *)bytes];
        case RDPrimitiveTypeKindUnsignedLongLong:
            return [NSString stringWithFormat:@"%lluull", *(unsigned long long *)bytes];
        case RDPrimitiveTypeKindInt128:
            return [NSString stringWithFormat:@"(int128_t)%lld", (long long)*(__int128_t *)bytes];
        case RDPrimitiveTypeKindUnsignedInt128:
            return [NSString stringWithFormat:@"(uint128_t)%llu", (unsigned long long)*(__uint128_t *)bytes];
        case RDPrimitiveTypeKindFloat:
            return [NSString stringWithFormat:@"%ff", *(float *)bytes];
        case RDPrimitiveTypeKindDouble:
            return [NSString stringWithFormat:@"%f", *(double *)bytes];
        case RDPrimitiveTypeKindLongDouble:
            return [NSString stringWithFormat:@"%Lfl", *(long double *)bytes];
    }
    return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDCompositeType(RDValue)
@end

@implementation RDCompositeType(RDValue)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return [self.type _value_describeBytes:bytes additionalInfo:info];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBitfieldType(RDValue)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType(RDValue)
@end

@implementation RDArrayType(RDValue)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDOffsetUnknown)
                [self.type _value_retainBytes:(uint8_t *)bytes + offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDOffsetUnknown)
                [self.type _value_releaseBytes:(uint8_t *)bytes + offset];
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.count; ++i)
        [values addObject:[self.type _value_describeBytes:(uint8_t *)bytes + [self offsetForElementAtIndex:i] additionalInfo:info]];
    return [NSString stringWithFormat:@"{ %@ }", [values componentsJoinedByString:@", "]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDAggregateType(RDValue)
@end

@implementation RDAggregateType(RDValue)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL && self.kind == RDAggregateTypeKindStruct)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
                [field->type _value_retainBytes:(uint8_t *)bytes + field->offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL && self.kind == RDAggregateTypeKindStruct)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
                [field->type _value_releaseBytes:(uint8_t *)bytes + field->offset];
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
            [values addObject:[NSString stringWithFormat:@".%@ = %@",
                               field->name ?: [NSString stringWithFormat:@"field%zu", i],
                               [field->type _value_describeBytes:(uint8_t *)bytes + field->offset additionalInfo:info]]];

    return [NSString stringWithFormat:@"(%@%@) { %@ }",
                                      self.kind == RDAggregateTypeKindUnion ? @"union" : @"struct",
                                      self.name ? [NSString stringWithFormat:@" %@", self.name] : @"",
                                      [values componentsJoinedByString:@", "]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
