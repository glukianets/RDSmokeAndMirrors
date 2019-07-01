#import "RDValue.h"
#import "RDPrivate.h"
#import <malloc/malloc.h>
#import <objc/runtime.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static constexpr size_t kAssumedMallocAlignmentBytes = 16;
static constexpr size_t kAssumendInstanceSizeBytes = 32;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDType(RDValue)

- (void)_value_retainBytes:(void *)bytes;
- (void)_value_releaseBytes:(void *)bytes;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDValue()
@end

@implementation RDValue {
    @protected
    RDType *_type;
    void *_data;
    @private
    uintptr_t _reserved;
}

#pragma mark Initialization

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    if (self == RDValue.self || self == RDMutableValue.self) {
        static RDValue *instance = nil;
        static RDMutableValue *mutableInstance = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instance = class_createInstance(RDValue.self, 0);
            mutableInstance = class_createInstance(RDMutableValue.self, 0);
        });
        return objc_retain(self == RDValue.self ? instance : mutableInstance);
    } else {
        return [super alloc];
    }
}

+ (instancetype)valueWithBytes:(const void *)bytes ofType:(RDType *)type {
    return [[self alloc] initWithBytes:bytes ofType:type];
}

+ (instancetype)valueWithBytes:(const void *)bytes objCType:(const char *)type {
    return [[self alloc] initWithBytes:bytes objCType:type];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = [RDUnknownType instance];
        _data = NULL;
    }
    return self;
}

- (instancetype)initWithBytes:(const void *)bytes objCType:(const char *)type {
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self initWithBytes:bytes ofType:rdtype];
    else
        return nil;
}

- (instancetype)initWithBytes:(const void *)bytes ofType:(RDType *)type {
    if (type == nil || bytes == nil)
        return nil;
    
    size_t size = type.size;
    size_t alignment = type.alignment;

    if (size == RDTypeSizeUnknown || size == 0 || alignment == RDTypeAlignmentUnknown || alignment == 0)
        return nil;
    
    size_t alignmentPad = alignment > kAssumedMallocAlignmentBytes ? alignment - kAssumedMallocAlignmentBytes : 0;
    size_t instanceSize = class_getInstanceSize(self.class);
    NSAssert(instanceSize == kAssumendInstanceSizeBytes, @"RDValue has different instance size than expected");
    
    self = class_createInstance(self.class, size + alignmentPad);

    void *data = ({
        uintptr_t ptr = (uintptr_t)self;
        NSAssert(ptr % kAssumedMallocAlignmentBytes == 0, @"Allocated instance has weaker alignment than expected");
        ptr += instanceSize;
        while (ptr % alignment != 0)
            ++ptr;
        (void *)ptr;
    });
    
    self = [super init];
    if (self) {
        _type = type;
        _data = data;
        memcpy(_data, bytes, size);
        [_type _value_retainBytes:_data];
    }
    return self;
}

#pragma mark Interface

- (BOOL)getValue:(void *)value size:(NSUInteger)size {
    if (_data == NULL || value == NULL || _type.size != size || (uintptr_t)value % _type.alignment != 0)
        return NO;
    
    memcpy(value, _data, size);
    return YES;
}

- (BOOL)getValue:(void *)value objCType:(const char *)type {
    if (_data == NULL || value == NULL || type == NULL)
        return NO;
    
    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; type != nil)
        return [self getValue:value type:rdtype];
    else
        return NO;
}

- (BOOL)getValue:(void *)value type:(RDType *)type {
    BOOL isOk = _data != NULL
             && value != NULL
             && type != nil
             && type.size != RDTypeSizeUnknown
             && type.alignment != RDTypeAlignmentUnknown
             && [type isAssignableFromType:_type]
             && (uintptr_t)value % type.alignment == 0;
    
    if (!isOk)
        return NO;
    
    [type _value_releaseBytes:value];
    memcpy(value, _data, type.size);
    [type _value_retainBytes:value];
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:_type.format ?: @"%@", @"rd_value"];
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
        return [[RDValue alloc] initWithBytes:_data ofType:_type];
}

#pragma mark <NSMutableCopying>

- (RDMutableValue *)mutableCopy {
    return [self mutableCopyWithZone:nil];
}

- (RDMutableValue *)mutableCopyWithZone:(NSZone *)zone {
    return [[RDMutableValue alloc] initWithBytes:_data ofType:_type];
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
    if (_data != nil && _type != nil && _type.size != RDTypeSizeUnknown) {
        [coder encodeObject:_type forKey:@"type"];
        [coder encodeBytes:(const uint8_t *)_data length:_type.size forKey:@"data"];
    } else {
        [coder encodeObject:nil forKey:@"type"];
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDMutableValue

- (BOOL)setValue:(void *)value size:(NSUInteger)size {
    if (value == NULL || _data == NULL || _type == nil || _type.size != size)
        return NO;
    
    [_type _value_releaseBytes:_data];
    memcpy(_data, value, _type.size);
    [_type _value_retainBytes:_data];
    return YES;
}

- (BOOL)setValue:(void *)value objCType:(const char *)type {
    if (_data == NULL || value == NULL || type == NULL)
        return NO;

    if (RDType *rdtype = [RDType typeWithObjcTypeEncoding:type]; rdtype != nil)
        return [self setValue:value type:rdtype];
    else
        return NO;
}

- (BOOL)setValue:(void *)value type:(RDType *)type {
    BOOL isOk = _data != NULL
             && value != NULL
             && type != nil
             && _type.size != RDTypeSizeUnknown
             && _type.alignment != RDTypeAlignmentUnknown
             && [_type isAssignableFromType:type];
    
    if (!isOk)
        return NO;

    [_type _value_releaseBytes:_data];
    memcpy(_data, value, _type.size);
    [_type _value_retainBytes:_data];
    return YES;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDType(RDValue)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType(RDValue)
@end

@implementation RDObjectType(RDValue)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    *(void **)bytes = (__bridge void *)objc_retain((__bridge id)*(void **)bytes);
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    objc_release((__bridge id)*(void **)bytes);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBlockType(RDValue)
@end

@implementation RDBlockType(RDValue)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL)
        *(void **)bytes = (__bridge void *)objc_retainBlock((__bridge id)*(void **)bytes);
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL)
        objc_release((__bridge id)*(void **)bytes);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDStructType(RDValue)
@end

@implementation RDStructType(RDValue)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL)
        for (RDField *field in self.fields)
            if (size_t offset = field.offset; offset != RDFieldOffsetUnknown)
                [field.type _value_retainBytes:(char *)bytes + offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL)
        for (RDField *field in self.fields)
            if (size_t offset = field.offset; offset != RDFieldOffsetUnknown)
                [field.type _value_releaseBytes:(char *)bytes + offset];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType(RDValue)
@end

@implementation RDArrayType(RDValue)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDFieldOffsetUnknown)
                [self.type _value_retainBytes:(char *)bytes + offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDFieldOffsetUnknown)
                [self.type _value_releaseBytes:(char *)bytes + offset];
}

@end
