#import "RDType.h"
#import "RDCommon.h"
#import "RDPrivate.h"

#include <initializer_list>
#include <algorithm>
#include <utility>
#include <vector>

RDTypeSize const RDTypeSizeUnknown = (size_t)0 - 1;
RDTypeAlign const RDTypeAlignUnknown = (size_t)0 - 1;
RDOffset const RDOffsetUnknown = (size_t)0 -1;

static size_t parseCountSucceded = 0;
static size_t parseCountFailed = 0;

RDType *parseType(const char *_Nonnull *_Nonnull encoding);
RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding);
RDPropertySignature *parsePropertySignature(const char *_Nonnull *_Nonnull encoding);
const char *cloneCString(const char *source, size_t length);

BOOL areEqual(_Nullable id lhs, _Nullable id rhs) {
    return lhs == rhs || lhs != nil && rhs != nil && [lhs isEqual:rhs];
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

template<typename T>
T *parseCheck(T *(*parser)(const char **), const char *_Nonnull *_Nonnull encoding) {
    const char *e = *encoding;
    T *result = parser(encoding);
    if (result == nil) {
        NSLog(@"%p: %s___------->___%s", parser, e, *encoding);
        parseCountFailed += 1;
    } else {
        parseCountSucceded += 1;
    }
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDType

+ (instancetype)typeWithObjcTypeEncoding:(const char *)encoding {
    if (encoding == NULL || *encoding == '\0')
        return nil;
    
    const char *it = encoding;
    RDType *type = parseType(&it);

    const char *clonedEncoding = cloneCString(encoding, it - encoding);
    
    @try {
        NSUInteger size = 0, alignment = 0;
        NSGetSizeAndAlignment(clonedEncoding, &size, &alignment);
        
        NSAssert(size == type.size || alignment == type.alignment, @"Miscalculated size and alignment: %zu, %zu instead of %zu, %zu (parsed type is %@)", type.size, type.alignment, size, alignment, type);
        
    } @catch(id e) {
        // NSGetSizeAndAlignment is kinda buggy
    }

    if (type != nil && type->_objCTypeEncoding == NULL)
        type->_objCTypeEncoding = clonedEncoding;
    else
        free((void *)clonedEncoding);
    
    return type;
}

- (instancetype)initWithByteSize:(size_t)size alignment:(size_t)alignment {
    self = [super init];
    if (self) {
        _size = size;
        _alignment = alignment;
    }
    return self;
}

- (void)dealloc {
    free((void *)_objCTypeEncoding);
}

- (NSString *)description {
    return [[NSString stringWithFormat:self.format ?: @"%@", @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString *)format {
    return @"%@";
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:RDType.self] && [self isEqualToType:object];
}

- (BOOL)isEqualToType:(nullable RDType *)type {
    return type == self;
}

- (BOOL)isAssignableFromType:(nullable RDType *)type {
    return type == self || type != nil && [self isEqualToType:type];
}

#pragma mark <NSSecureCoding>

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark <NSCoding>

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    //TODO: implement
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    //TODO: implement
    return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDUnknownType

+ (instancetype)instance {
    static RDUnknownType *instance = [[RDUnknownType alloc] initWithByteSize:RDTypeSizeUnknown
                                                                   alignment:RDTypeAlignUnknown];
    return instance;
}

- (NSString *)format {
    return @"? %@";
}

- (BOOL)isEqualToType:(nullable RDType *)type {
    return [type isKindOfClass:RDUnknownType.self];
}

- (BOOL)isAssignableFromType:(nullable RDType *)type {
    return NO;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDVoidType

+ (instancetype)instance {
    static RDVoidType *instance = [[RDVoidType alloc] initWithByteSize:0 alignment:1];
    return instance;
}

- (NSString *)format {
    return @"void %@";
}

- (BOOL)isEqualToType:(nullable RDType *)type {
    return [type isKindOfClass:RDVoidType.self];
}

- (BOOL)isAssignableFromType:(nullable RDType *)type {
    return NO;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPrimitiveType : RDType

- (instancetype)initWithKind:(RDPrimitiveTypeKind)kind {
    std::pair<size_t, size_t> sizeAndAlignement = [self.class sizeAndAlignmentForKind:kind];
    self = [super initWithByteSize:sizeAndAlignement.first alignment:sizeAndAlignement.second];
    if (self) {
        _kind = kind;
    }
    return self;
}

+ (instancetype)instanceWithKind:(RDPrimitiveTypeKind)kind {
#define RD_INSTANCE(TYPE) @(TYPE): [[RDPrimitiveType alloc] initWithKind:TYPE]
    static NSDictionary *instances = @{
        RD_INSTANCE(RDPrimitiveTypeKindSelector),
        RD_INSTANCE(RDPrimitiveTypeKindAtom),
        RD_INSTANCE(RDPrimitiveTypeKindCString),
        RD_INSTANCE(RDPrimitiveTypeKindChar),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedChar),
        RD_INSTANCE(RDPrimitiveTypeKindBool),
        RD_INSTANCE(RDPrimitiveTypeKindShort),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedShort),
        RD_INSTANCE(RDPrimitiveTypeKindInt),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedInt),
        RD_INSTANCE(RDPrimitiveTypeKindLong),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedLong),
        RD_INSTANCE(RDPrimitiveTypeKindLongLong),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedLongLong),
        RD_INSTANCE(RDPrimitiveTypeKindInt128),
        RD_INSTANCE(RDPrimitiveTypeKindUnsignedInt128),
        RD_INSTANCE(RDPrimitiveTypeKindFloat),
        RD_INSTANCE(RDPrimitiveTypeKindDouble),
        RD_INSTANCE(RDPrimitiveTypeKindLongDouble),
    };
#undef RD_INSTANCE
    return instances[@(kind)];
}

- (NSString *)format {
    switch (self.kind) {
        case RDPrimitiveTypeKindSelector:
            return @"SEL %@";
        case RDPrimitiveTypeKindAtom:
        case RDPrimitiveTypeKindCString:
            return @"const char *%@";
        case RDPrimitiveTypeKindChar:
            return @"char %@";
        case RDPrimitiveTypeKindUnsignedChar:
            return @"unsigned char %@";
        case RDPrimitiveTypeKindBool:
            return @"_Bool %@";
        case RDPrimitiveTypeKindShort:
            return @"short %@";
        case RDPrimitiveTypeKindUnsignedShort:
            return @"unsigned short %@";
        case RDPrimitiveTypeKindInt:
            return @"int %@";
        case RDPrimitiveTypeKindUnsignedInt:
            return @"unsigned int %@";
        case RDPrimitiveTypeKindLong:
            return @"long %@";
        case RDPrimitiveTypeKindUnsignedLong:
            return @"unsigned long %@";
        case RDPrimitiveTypeKindLongLong:
            return @"long long %@";
        case RDPrimitiveTypeKindUnsignedLongLong:
            return @"unsigned long long %@";
        case RDPrimitiveTypeKindInt128:
            return @"int128_t %@";
        case RDPrimitiveTypeKindUnsignedInt128:
            return @"uint128_t %@";
        case RDPrimitiveTypeKindFloat:
            return @"float %@";
        case RDPrimitiveTypeKindDouble:
            return @"double %@";
        case RDPrimitiveTypeKindLongDouble:
            return @"long double %@";
    }
}

+ (std::pair<size_t, size_t>)sizeAndAlignmentForKind:(RDPrimitiveTypeKind)kind {
    switch (kind) {
        case RDPrimitiveTypeKindSelector:
            return { sizeof(SEL), alignof(SEL) };
        case RDPrimitiveTypeKindCString:
        case RDPrimitiveTypeKindAtom:
            return { sizeof(const char *), alignof(const char *) };
        case RDPrimitiveTypeKindChar:
            return { sizeof(char), alignof(char) };
        case RDPrimitiveTypeKindUnsignedChar:
            return { sizeof(unsigned char), alignof(unsigned char) };
        case RDPrimitiveTypeKindBool:
            return { sizeof(bool), alignof(bool) };
        case RDPrimitiveTypeKindShort:
            return { sizeof(short), alignof(short) };
        case RDPrimitiveTypeKindUnsignedShort:
            return { sizeof(unsigned short), alignof(unsigned short) };
        case RDPrimitiveTypeKindInt:
            return { sizeof(int), alignof(int) };
        case RDPrimitiveTypeKindUnsignedInt:
            return { sizeof(unsigned int), alignof(unsigned int) };
        case RDPrimitiveTypeKindLong:
            return { sizeof(long), alignof(long) };
        case RDPrimitiveTypeKindUnsignedLong:
            return { sizeof(unsigned long), alignof(unsigned long) };
        case RDPrimitiveTypeKindLongLong:
            return { sizeof(long long), alignof(long long) };
        case RDPrimitiveTypeKindUnsignedLongLong:
            return { sizeof(unsigned long long), alignof(unsigned long long) };
        case RDPrimitiveTypeKindInt128:
            return { sizeof(__int128_t), alignof(__int128_t) };
        case RDPrimitiveTypeKindUnsignedInt128:
            return { sizeof(__int128_t), alignof(__int128_t) };
        case RDPrimitiveTypeKindFloat:
            return { sizeof(float), alignof(float) };
        case RDPrimitiveTypeKindDouble:
            return { sizeof(double), alignof(double) };
        case RDPrimitiveTypeKindLongDouble:
            return { sizeof(long double), alignof(long double) };
    }
}

- (BOOL)isEqualToType:(nullable RDType *)type {
    return [super isEqualToType:type]
        || [type isKindOfClass:RDPrimitiveType.self]
        && ((RDPrimitiveType *)type).kind == self.kind;
}

- (BOOL)isAssignableFromType:(RDType *)type {
    return [self isEqualToType:type];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDObjectType

- (instancetype)initAsClass {
    self = [super initWithByteSize:sizeof(Class) alignment:alignof(Class)];
    if (self) {
        _kind = RDObjectTypeKindClass;
    }
    return self;
}

- (instancetype)initWithBlockArgumentString:(NSString *)string {
    self = [super initWithByteSize:sizeof(void (^)(...)) alignment:alignof(void (^)(...))];
    if (self) {
        _kind = RDObjectTypeKindBlock;
    }
    return self;
}

- (instancetype)initWithClassName:(NSString *)cls protocolNames:(NSArray<NSString *> *)protocols {
    self = [super initWithByteSize:sizeof(id) alignment:alignof(id)];
    if (self) {
        _kind = RDObjectTypeKindGeneric;
        _className = cls.copy;
        _protocolNames = protocols.copy;
    }
    return self;
}

- (NSString *)format {
    switch (self.kind) {
    case RDObjectTypeKindClass:
        return @"Class %@";
    case RDObjectTypeKindBlock:
        return @"void (^%@)(...)";
    case RDObjectTypeKindGeneric:
        return ({
            NSString *protocols = self.protocolNames.count == 0 ? @"" : [NSString stringWithFormat:@"<%@>", [self.protocolNames componentsJoinedByString:@", "]];
            NSString *cls = self.className.length > 0 ? self.className : nil;
            [NSString stringWithFormat:@"%@%@ %@%%@", cls ? cls : @"id", protocols, cls ? @"*" : @""];
        });
    }
}

- (BOOL)isEqualToType:(RDType *)type {
    return [super isEqualToType:type]
        || [type isKindOfClass:RDObjectType.self]
        && (self.kind == RDObjectTypeKindGeneric || self.kind == ((RDObjectType *)type).kind)
        && areEqual(((RDObjectType *)type).className, self.className)
        && areEqual(((RDObjectType *)type).protocolNames, self.protocolNames);
}

- (BOOL)isAssignableFromType:(RDType *)type {
    return [type isKindOfClass:RDObjectType.self];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDCompositeType

- (instancetype)initWithKind:(RDCompositeTypeKind)kind type:(RDType *)type {
    size_t size = RDTypeSizeUnknown, alignment = RDTypeAlignUnknown;
    switch (kind) {
        case RDCompositeTypeKindPointer:
            size = sizeof(void *);
            alignment = alignof(void *);
            break;
        case RDCompositeTypeKindVector:
            // ?
            break;
        case RDCompositeTypeKindComplex:
            size = type.size * 2;
            alignment = type.alignment;
            break;
        case RDCompositeTypeKindAtomic:
        case RDCompositeTypeKindConst:
            size = type.size;
            alignment = type.alignment;
            break;
    }
    
    self = [super initWithByteSize:size alignment:alignment];
    if (self) {
        _kind = kind;
        _type = type;
    }
    return self;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length < 2)
        return nil;
    else
        switch (self.kind) {
            case RDCompositeTypeKindPointer:
                return [NSString stringWithFormat:fmt, @"*%@"];
            case RDCompositeTypeKindVector:
                return nil; // ?
            case RDCompositeTypeKindComplex:
                return [NSString stringWithFormat:fmt, @"_Complex %@"];
            case RDCompositeTypeKindAtomic:
                return [NSString stringWithFormat:fmt, @"_Atomic %@"];
            case RDCompositeTypeKindConst:
                return [NSString stringWithFormat:fmt, @"const %@"];
        }
}

- (BOOL)isEqualToType:(RDType *)type {
    return [type isKindOfClass:RDCompositeType.self]
        && self.kind == ((RDCompositeType *)type).kind
        && [self.type isEqualToType:((RDCompositeType *)type).type];
}

- (BOOL)isAssignableFromType:(RDType *)type {
    //TODO: more complex logic
    return [type isKindOfClass:RDCompositeType.self]
        && self.kind == ((RDCompositeType *)type).kind
        && [self.type isAssignableFromType:((RDCompositeType *)type).type];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDBitfieldType

- (instancetype)initWithSizeInBits:(NSUInteger)size {
    self = [super initWithByteSize:RDTypeSizeUnknown alignment:alignof(unsigned int)];
    if (self) {
        _bitsize = size;
    }
    return self;
}

- (NSString *)format {
    return [NSString stringWithFormat:@"unsigned int %%@ : %zu", self.bitsize];
}

- (BOOL)isEqualToType:(RDType *)type {
    return [type isKindOfClass:RDBitfieldType.class]
        && self.bitsize == ((RDBitfieldType *)type).bitsize;
}

- (BOOL)isAssignableFromType:(RDType *)type {
    return NO;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDArrayType

- (instancetype)initWithCount:(NSUInteger)count elementsOfType:(RDType *)type {
    type = type ?: RDUnknownType.instance;
    self = [super initWithByteSize:type.size * count alignment:type.alignment];
    if (self) {
        _count = count;
        _type = type;
    }
    return self;
}

- (size_t)offsetForElementAtIndex:(NSUInteger)index {
    if (index >= self.count)
        return RDOffsetUnknown;

    if (self.type == nil)
        return RDOffsetUnknown;
    
    size_t size = self.type.size;
    size_t alignment = self.type.alignment;

    if (size == 0 || size == RDTypeSizeUnknown || alignment == RDTypeSizeUnknown)
        return RDOffsetUnknown;
    
    while (size % alignment != 0)
        ++size;
    
    return index * size;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [NSString stringWithFormat:fmt, [NSString stringWithFormat:@"%%@[%zu]", self.size]];
    else
        return nil;
}

- (BOOL)isEqualToType:(RDType *)type {
    return [type isKindOfClass:RDArrayType.class]
        && [self.type isEqualToType:((RDArrayType *)type).type]
        && self.count == ((RDArrayType *)type).count;
}

- (BOOL)isAssignableFromType:(RDType *)type {
    return [type isKindOfClass:RDArrayType.class]
        && [self.type isAssignableFromType:((RDArrayType *)type).type]
        && self.count <= ((RDArrayType *)type).count;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

BOOL RDFieldsEqual(RDField *lhs, RDField *rhs) {
    return lhs == rhs
        || lhs != nil
        && rhs != nil
        && lhs->offset == rhs->offset
        && areEqual(lhs->name, rhs->name)
        && areEqual(lhs->type, rhs->type);
}

@implementation RDAggregateType

+ (instancetype)alloc {
    static RDAggregateType *instance = class_createInstance(self, 0);
    return instance;
}

- (void)dealloc {
    for (NSUInteger i = 0; i < self.count; ++i)
        *RD_FLEX_ARRAY_ELEMENT(self, RDField, i) = (RDField) {.type=nil, .name=nil, .offset=RDOffsetUnknown};
}

- (instancetype)initWithKind:(RDAggregateTypeKind)kind name:(NSString *)name fields:(RDField *)fields count:(NSUInteger)count {
    size_t size, alignment;
    switch (kind) {
        case RDAggregateTypeKindStruct:
            [self.class layoutStructTypeWithFields:fields count:count size:&size alignment:&alignment];
            break;
        case RDAggregateTypeKindUnion:
            [self.class layoutUnionTypeWithFields:fields count:count size:&size alignment:&alignment];
            break;
    }
    
    self = RD_FLEX_ARRAY_CREATE(self.class, RDField, count);
    self = [super initWithByteSize:size alignment:alignment];
    if (self) {
        _kind = kind;
        _name = name.copy;
        _count = count;
        for (NSUInteger i = 0; i < count; ++i)
            *RD_FLEX_ARRAY_ELEMENT(self, RDField, i) = fields[i];
    }
    return self;
}

- (instancetype)initWithKind:(RDAggregateTypeKind)kind name:(NSString *)name, ... {
    typedef const char *encoding_t;
    
    va_list ap;
    
    va_start(ap, name);
    NSUInteger count = 0;
    while (va_arg(ap, encoding_t) != NULL)
        ++count;
    va_end(ap);
    
    va_start(ap, name);
    NSUInteger i = 0;
    RDField fields[MAX(1, count)];
    memset(fields, 0, sizeof(RDField) * count);
    encoding_t encoding;
    while ((encoding = va_arg(ap, encoding_t)) != NULL)
        fields[i++] = (RDField) {
            .type=[RDType typeWithObjcTypeEncoding:encoding],
            .name=nil,
            .offset=RDOffsetUnknown
        };
    va_end(ap);
    
    RDAggregateType *result = [self initWithKind:kind name:nil fields:fields count:count];

    for (NSUInteger i = 0; i < count; ++i)
        fields[i] = (RDField) {.type=nil, .name=nil, .offset=0};
    
    return result;
}

- (RDField *)fieldAtIndex:(NSUInteger)index {
    if (index >= self.count)
        return nil;
    
    return RD_FLEX_ARRAY_ELEMENT(self, RDField, index);
}

- (RDField *)fieldAtOffset:(RDOffset)offset {
    if (offset == RDOffsetUnknown)
        return nil;
    
    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset == offset)
            return field;
    
    return nil;
}

- (RDField *)fieldWithName:(NSString *)name {
    if (name.length == 0)
        return nil;
    
    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *field = [self fieldAtIndex:i]; field != NULL && [field->name isEqualToString:name])
            return field;
    
    return nil;
}

- (NSString *)format {
    NSMutableString *fields = [NSMutableString string];
    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *field = [self fieldAtIndex:i]; field != NULL)
            [fields appendFormat:[field->type.format stringByAppendingString:@"; "] ?: @"%@; ", field->name ?: @"_"];

    NSString *name = self.name ?: @"";
    NSString *tag = ({
        NSString *str = nil;
        switch (self.kind) {
            case RDAggregateTypeKindStruct:
                str = @"struct";
                break;
                
            case RDAggregateTypeKindUnion:
                str = @"union";
                break;
        }
        str;
    });

    return [NSString stringWithFormat:@"%@ %@ { %@} %%@", tag, name, fields];
}

- (BOOL)isEqualToType:(RDType *)other {
    if (self == other)
        return YES;
    
    RDAggregateType *type = RD_CAST(other, RDAggregateType);
    if (type == nil)
        return NO;
    
    if (self.kind != type.kind || !areEqual(self.name, type.name) || self.count != type.count)
        return NO;

    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *lhs = [self fieldAtIndex:i], *rhs = [type fieldAtIndex:i]; !RDFieldsEqual(lhs, rhs))
            return NO;

    return YES;
}

- (BOOL)isAssignableFromType:(RDType *)other {
    RDAggregateType *type = RD_CAST(other, RDAggregateType);
    if (type == nil || self.kind != type.kind)
        return NO;
    
    switch (self.kind) {
        case RDAggregateTypeKindStruct: {
            if (self.count != type.count)
                return NO;
            else
                for (NSUInteger i = 0; i < self.count; ++i)
                    if (RDField *field = [self fieldAtIndex:i]; field == NULL)
                        return NO;
                    else if (RDOffset offset = field->offset; offset == RDOffsetUnknown)
                        return NO;
                    else if (RDField *otherField = [type fieldAtOffset:offset]; otherField == NULL)
                        return NO;
                    else if (RDType *fieldType = otherField->type; fieldType == nil)
                        return NO;
                    else if (![field->type isAssignableFromType:fieldType])
                        return NO;
                    else
                        continue;
    
            return YES;
        }

        case RDAggregateTypeKindUnion: {
            for (NSUInteger i = 0; i < type.count; ++i)
                if (RDField *otherField = [type fieldAtIndex:i]; otherField != NULL)
                    for (NSUInteger i = 0; i < self.count; ++i)
                        if (RDField *field = [self fieldAtIndex:i]; field == NULL || ![field->type isAssignableFromType:otherField->type])
                            return NO;

            return YES;
        }
    }
}

+ (void)layoutUnionTypeWithFields:(RDField *)fields count:(NSUInteger)count size:(size_t *)size alignment:(size_t *)alignment {
    *size = 1;
    *alignment = 1;
    for (NSUInteger i = 0; i < count; ++i) {
        *size = MAX(fields[i].type.size, *size);
        *alignment = MAX(fields[i].type.alignment, *alignment);
        fields[i].offset = 0u;
    }
}

+ (void)layoutStructTypeWithFields:(RDField *)fields count:(NSUInteger)count size:(size_t *)size alignment:(size_t *)alignment {
    size_t offset = 0;
    *alignment = 1;
    
    for (NSUInteger i = 0; i < count; ++i) {
        size_t falignment = fields[i].type.alignment;
        size_t fsize = fields[i].type.size;
        
        if (fields[i].type == nil || falignment == RDTypeAlignUnknown || fsize == RDTypeSizeUnknown) {
            offset = RDTypeSizeUnknown;
            *alignment = RDTypeAlignUnknown;
            break;
        }
        
        while (offset % falignment != 0)
            ++offset;
        
        fields[i].offset = offset;
        offset += fields[i].type.size;
        *alignment = MAX(falignment, *alignment);
    }
    
    if (offset == RDTypeSizeUnknown || *alignment == RDTypeAlignUnknown)
        for (NSUInteger i = 0; i < count; ++i)
            fields[i].offset = RDOffsetUnknown;
    else
        while (offset != RDTypeSizeUnknown && offset % *alignment != 0)
            ++offset;
    
    *size = MAX(1, offset);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDMethodSignature

+ (instancetype)signatureWithObjcTypeEncoding:(const char *)encoding {
    if (encoding != nil && *encoding != '\0')
        return parseCheck(parseMethodSignature, &encoding);
    else
        return nil;
}

- (instancetype)initWithReturnValue:(RDMethodArgument)retval arguments:(RDMethodArgument *)arguments count:(NSUInteger)count {
    self = RD_FLEX_ARRAY_CREATE(self.class, RDMethodArgument, (count + 1));
    self = [super init];
    if (self) {
        _argumentsCount = count;
        *RD_FLEX_ARRAY_ELEMENT(self, RDMethodArgument, _argumentsCount) = retval;
        for (NSUInteger i = 0; i < count; ++i)
            *RD_FLEX_ARRAY_ELEMENT(self, RDMethodArgument, i) = arguments[i];
    }
    return self;
}

- (RDMethodArgument *)argumentAtIndex:(NSUInteger)index {
    return index < self.argumentsCount ? RD_FLEX_ARRAY_ELEMENT(self, RDMethodArgument, index) : NULL;
}

- (RDMethodArgument *)returnValue {
    return RD_FLEX_ARRAY_ELEMENT(self, RDMethodArgument, self.argumentsCount);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPropertyAttribute

- (instancetype)initWithKind:(RDPropertyAttributeKind)kind value:(NSString *)value {
    self = [super init];
    if (self) {
        _kind = kind;
        _value = value.copy;
    }
    return self;
}

- (NSString *)description {
    switch (self.kind) {
        case RDPropertyAttributeReadOnly:
            return @"readonly";
        case RDPropertyAttributeCopy:
            return @"copy";
        case RDPropertyAttributeRetain:
            return @"retain";
        case RDPropertyAttributeNonatomic:
            return @"nonatomic";
        case RDPropertyAttributeGetter:
            return [NSString stringWithFormat:@"getter=%@", self.value];
        case RDPropertyAttributeSetter:
            return [NSString stringWithFormat:@"setter=%@", self.value];
        case RDPropertyAttributeDynamic:
            return @"dynamic";
        case RDPropertyAttributeWeak:
            return @"weak";
        case RDPropertyAttributeGarbageCollected:
            return @"gc";
        case RDPropertyAttributeLegacyEncoding:
            return @"legacy";
        case RDPropertyAttributeIvarName:
            return [NSString stringWithFormat:@"ivar=%@", self.value];
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPropertySignature

+ (instancetype)signatureWithObjcTypeEncoding:(const char *)encoding {
    if (encoding != nil && *encoding != '\0')
        return parseCheck(parsePropertySignature, &encoding);
    else
        return nil;
}

- (instancetype)initWithName:(NSString *)name type:(RDType *)type attributes:(NSArray<RDPropertyAttribute *> *)attributes {
    self = [super init];
    if (self) {
        _ivarName = name.copy;
        _type = type;
        _attributes = attributes.copy;
    }
    return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const char *cloneCString(const char *source, size_t length) {
    if (source == NULL)
        return NULL;
    
    size_t characterSize = MAX(strlen(source), length);
    char *str = (char *)calloc(characterSize + 1, 1);
    memccpy(str, source, '\0', characterSize);
    str[characterSize] = '\0';
    return str;
}

NSString *parseString(const char *_Nonnull *_Nonnull encoding, char terminator, BOOL consume = NO) {
    static constexpr size_t LIMIT = 8192;
    char buff[LIMIT] = {};
    unsigned index = 0;
    while (index < LIMIT && **encoding != terminator && **encoding != '\0')
        buff[index++] = *((*encoding)++);
    
    if (consume && **encoding == terminator)
        ++(*encoding);
    
    return [NSString stringWithUTF8String:buff];
};

NSString *parseQuotedString(const char *_Nonnull *_Nonnull encoding) {
    if (**encoding != RDTypeEncodingSymbolQuote)
        return nil;
    ++(*encoding);
    return parseString(encoding, RDTypeEncodingSymbolQuote, YES);
}

NSUInteger parseNumber(const char *_Nonnull *_Nonnull encoding) {
    NSUInteger result = 0;
    while (**encoding != '\0')
        if (**encoding >= '0' && **encoding <= '9')
            result = result * 10 + ((*(*encoding)++) - '0');
        else
            break;
    
    return result;
}

RDType *parseType(const char *_Nonnull *_Nonnull encoding) {
    while (**encoding != '\0') {
        switch (**encoding) {
            case RDSpecialTypeKindUnknown:
                ++(*encoding);
                return RDUnknownType.instance;
                
            case RDSpecialTypeKindVoid:
                ++(*encoding);
                return RDVoidType.instance;
            
            case RDPrimitiveTypeKindSelector:
            case RDPrimitiveTypeKindChar:
            case RDPrimitiveTypeKindUnsignedChar:
            case RDPrimitiveTypeKindShort:
            case RDPrimitiveTypeKindUnsignedShort:
            case RDPrimitiveTypeKindInt:
            case RDPrimitiveTypeKindUnsignedInt:
            case RDPrimitiveTypeKindLong:
            case RDPrimitiveTypeKindUnsignedLong:
            case RDPrimitiveTypeKindLongLong:
            case RDPrimitiveTypeKindUnsignedLongLong:
            case RDPrimitiveTypeKindInt128:
            case RDPrimitiveTypeKindUnsignedInt128:
            case RDPrimitiveTypeKindFloat:
            case RDPrimitiveTypeKindDouble:
            case RDPrimitiveTypeKindLongDouble:
            case RDPrimitiveTypeKindBool:
            case RDPrimitiveTypeKindCString:
            case RDPrimitiveTypeKindAtom: {
                return [RDPrimitiveType instanceWithKind:(RDPrimitiveTypeKind)*((*encoding)++)];
            }
                
            case RDObjectTypeKindClass: {
                ++(*encoding);
                return [[RDObjectType alloc] initAsClass];
            }
            
            case RDObjectTypeKindGeneric: {
                ++(*encoding);
                if (**encoding == RDObjectTypeKindBlock) {
                    NSString *args = nil;
                    if (*(++(*encoding)) == RDTypeEncodingSymbolBlockArgsBegin)
                        args = parseString(encoding, RDTypeEncodingSymbolBlockArgsEnd);
                    return [[RDObjectType alloc] initWithBlockArgumentString:args];
                }
                NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
                NSArray<NSString *> *components = [parseQuotedString(encoding) componentsSeparatedByCharactersInSet:separators];
                NSArray<NSString *> *protocols = map_nn([components subarrayWithRange:NSMakeRange(1, components.count - 1)], ^NSString *(NSString *p) {
                    return p.length == 0 ? nil : p;
                });
                return [[RDObjectType alloc] initWithClassName:components.firstObject protocolNames:protocols];
            }
                
            case RDCompositeTypeKindPointer:
            case RDCompositeTypeKindConst:
            case RDCompositeTypeKindAtomic:
            case RDCompositeTypeKindComplex:
            case RDCompositeTypeKindVector: {
                RDCompositeTypeKind kind = (RDCompositeTypeKind)*((*encoding)++);
                const char *e = *encoding;
                if (RDType *type = parseType(encoding); type != nil) {
                    return [[RDCompositeType alloc] initWithKind:kind type:type];
                } else {
                    *encoding = e;
                    return [[RDCompositeType alloc] initWithKind:kind type:RDUnknownType.instance];
                }
            }
                
            case RDSpecialTypeKindBitfield: {
                ++(*encoding);
                NSUInteger size = parseNumber(encoding);
                return [[RDBitfieldType alloc] initWithSizeInBits:size];
            }
                
            case RDTypeEncodingSymbolArrayBegin: {
                ++(*encoding);
                NSUInteger size = parseNumber(encoding);
                if (**encoding == RDTypeEncodingSymbolArrayEnd && ++(*encoding))
                    return [[RDArrayType alloc] initWithCount:size elementsOfType:nil];
                
                RDType *type = parseType(encoding);
                if (type == nil)
                    return nil;
                
                if (*((*encoding)++) != RDTypeEncodingSymbolArrayEnd)
                    return nil;
                
                return [[RDArrayType alloc] initWithCount:size elementsOfType:type];
            }
                
            case RDTypeEncodingSymbolUnionBegin:
            case RDTypeEncodingSymbolStructBegin: {
                char op = *((*encoding)++);
                bool isStruct = op == RDTypeEncodingSymbolStructBegin;
                char cl = (isStruct ? RDTypeEncodingSymbolStructEnd : RDTypeEncodingSymbolUnionEnd);
                
                static constexpr size_t LIMIT = 8192;
                char buff[LIMIT] = {};
                unsigned index = 0;
                while (index < LIMIT && **encoding != RDTypeEncodingSymbolStructBodySep && **encoding != cl && **encoding != '\0')
                    buff[index++] = *((*encoding)++);
                
                NSString *name = buff[0] == '?' && buff[1] == '\0' ? nil : [NSString stringWithUTF8String:buff];
                
                std::vector<RDField> fields;
                
                if (**encoding == RDTypeEncodingSymbolStructBodySep) {
                    ++(*encoding);
                    
                    while (**encoding != cl && **encoding != '\0') {
                        NSString *name = parseQuotedString(encoding);
                        if (**encoding == RDTypeEncodingSymbolQuote || **encoding == cl)
                            fields.emplace_back((RDField) {.type=nil, .name=name, .offset=RDOffsetUnknown});
                        else if (RDType *type = parseType(encoding); type != nil)
                            fields.emplace_back((RDField) {.type=type, .name=name, .offset=RDOffsetUnknown});
                        else
                            break;
                    }
                }
                
                if (**encoding == cl)
                    ++(*encoding);
                
                RDAggregateTypeKind kind = isStruct ? RDAggregateTypeKindStruct : RDAggregateTypeKindUnion;
                return [[RDAggregateType alloc] initWithKind:kind name:name fields:fields.data() count:fields.size()];
            }
                
            default: {
                return nil;
            }
        }
    }
    return nil;
}

RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding) {
    RDMethodArgument (^parseMethodArgument)(const char *_Nonnull *_Nonnull) = ^RDMethodArgument (const char *_Nonnull *_Nonnull encoding) {
        RDMethodArgumentAttributes attributes = RDMethodArgumentAttributesNone;
        while (**encoding != '\0') {
            switch (**encoding) {
                case RDMethodArgumentAttributeKindConst:
                    attributes |= RDMethodArgumentAttributeConst;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindIn:
                    attributes |= RDMethodArgumentAttributeIn;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindOut:
                    attributes |= RDMethodArgumentAttributeOut;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindInOut:
                    attributes |= RDMethodArgumentAttributeInOut;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindByCopy:
                    attributes |= RDMethodArgumentAttributeByCopy;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindByRef:
                    attributes |= RDMethodArgumentAttributeByRef;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindOneWay:
                    attributes |= RDMethodArgumentAttributeOneWay;
                    ++(*encoding);
                    break;
                case RDMethodArgumentAttributeKindWTF:
                    attributes |= RDMethodArgumentAttributeWTF;
                    ++(*encoding);
                    break;
                default:
                    if (**encoding >= '0' && **encoding <= '9')
                        return (RDMethodArgument) {
                            .type=[RDUnknownType instance],
                            .offset=(RDOffset)parseNumber(encoding),
                            .attributes=attributes,
                        };
                    else
                        return (RDMethodArgument) {
                            .type=parseType(encoding),
                            .offset=(RDOffset)parseNumber(encoding),
                            .attributes=attributes
                        };
            }
        }
        return (RDMethodArgument) {
            .type=nil,
            .offset=RDOffsetUnknown,
            .attributes=RDMethodArgumentAttributesNone,
        };
    };
    
    std::vector<RDMethodArgument> arguments;
    while (**encoding != '\0')
        if (RDMethodArgument argument = parseMethodArgument(encoding); argument.type != nil)
            arguments.emplace_back(argument);
        else
            return nil;
    
    if (arguments.size() < 1)
        return nil;
    
    return [[RDMethodSignature alloc] initWithReturnValue:arguments.at(0)
                                                arguments:arguments.data() + 1
                                                    count:arguments.size() - 1];
}
 

RDPropertySignature *parsePropertySignature(const char *_Nonnull *_Nonnull encoding) {
    RDPropertyAttribute *(^parseAttribute)(const char *_Nonnull *_Nonnull) = ^RDPropertyAttribute *(const char **encoding) {
        if (**encoding == '\0')
            return nil;
        
        char c = *((*encoding)++);
        
        switch (c) {
            case RDPropertyAttributeReadOnly:
            case RDPropertyAttributeCopy:
            case RDPropertyAttributeRetain:
            case RDPropertyAttributeNonatomic:
            case RDPropertyAttributeDynamic:
            case RDPropertyAttributeWeak:
            case RDPropertyAttributeGarbageCollected:
                return [[RDPropertyAttribute alloc] initWithKind:(RDPropertyAttributeKind)c
                                                           value:nil];
                
            case RDPropertyAttributeLegacyEncoding:
            case RDPropertyAttributeGetter:
            case RDPropertyAttributeSetter:
                return [[RDPropertyAttribute alloc] initWithKind:(RDPropertyAttributeKind)c
                                                           value:parseString(encoding, ',')];
                
            default:
                return nil;
        }
    };
    
    if (**encoding == '\0' || *((*encoding)++) != 'T')
        return nil;
    
    RDType *type = parseType(encoding);
    if (type == nil && **encoding != ',')
        return nil;
    
    NSMutableArray<RDPropertyAttribute *> *attributes = [NSMutableArray array];
    NSString *name = nil;
    while (**encoding != '\0')
        if (*((*encoding)++) != ',')
            return nil;
        else if (**encoding == 'V' && ++(*encoding))
            name = parseString(encoding, '\0');
        else if(RDPropertyAttribute *attribute = parseAttribute(encoding); attribute != nil)
            [attributes addObject:attribute];
        else
            return nil;
    
    return [[RDPropertySignature alloc] initWithName:name type:type attributes:attributes];
}
