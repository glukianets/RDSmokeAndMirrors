#import "RDType.h"
#import "RDCommon.h"
#import "RDPrivate.h"

#include <initializer_list>
#include <algorithm>
#include <utility>

size_t const RDTypeSizeUnknown = (size_t)0 - 1;
size_t const RDTypeAlignmentUnknown = (size_t)0 - 1;
size_t const RDFieldOffsetUnknown = (size_t)0 -1;

static size_t parseCountSucceded = 0;
static size_t parseCountFailed = 0;

RDType *parseType(const char *_Nonnull *_Nonnull encoding);
RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding);
RDPropertySignature *parsePropertySignature(const char *_Nonnull *_Nonnull encoding);
const char *cloneCString(const char *source, size_t length);

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

- (BOOL)isEqualToType:(nullable RDType *)type {
    //TODO: implement
    return NO;
}

- (BOOL)isAssignableFromType:(nullable RDType *)type {
    //TODO: implement
    return NO;
}

- (NSString *)description {
    return [[NSString stringWithFormat:self.format ?: @"%@", @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString *)format {
    return @"%@";
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
    static RDUnknownType *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RDUnknownType alloc] initWithByteSize:RDTypeSizeUnknown alignment:RDTypeAlignmentUnknown];
    });
    return instance;
}

- (NSString *)format {
    return @"? %@";
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
    static NSDictionary *instances;
    static dispatch_once_t onceToken;
#define RD_INSTANCE(TYPE) @(TYPE): [[RDPrimitiveType alloc] initWithKind:TYPE]
    dispatch_once(&onceToken, ^{
        instances = @{
            RD_INSTANCE(RDPrimitiveTypeKindUnknown),
            RD_INSTANCE(RDPrimitiveTypeKindVoid),
            RD_INSTANCE(RDPrimitiveTypeKindClass),
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
    });
#undef RD_INSTANCE
    return instances[@(kind)];
}

- (NSString *)format {
    switch (self.kind) {
        case RDPrimitiveTypeKindUnknown:
            return nil;
        case RDPrimitiveTypeKindVoid:
            return @"void %@";
        case RDPrimitiveTypeKindClass:
            return @"Class %@";
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
        case RDPrimitiveTypeKindUnknown:
            return { RDTypeSizeUnknown, RDTypeAlignmentUnknown };
        case RDPrimitiveTypeKindVoid:
            return { 0, RDTypeAlignmentUnknown };
        case RDPrimitiveTypeKindClass:
            return { sizeof(Class), alignof(Class) };
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDObjectType

- (instancetype)initWithClassName:(NSString *)cls protocolNames:(NSArray<NSString *> *)protocols {
    self = [super initWithByteSize:sizeof(id) alignment:alignof(id)];
    if (self) {
        _className = cls.copy;
        _protocolNames = protocols.copy;
    }
    return self;
}

- (NSString *)format {
    NSString *protocols = self.protocolNames.count == 0 ? @"" : [NSString stringWithFormat:@"<%@>", [self.protocolNames componentsJoinedByString:@", "]];
    NSString *cls = self.className.length > 0 ? self.className : nil;
    return [NSString stringWithFormat:@"%@%@ %@%%@", cls ? cls : @"id", protocols, cls ? @"*" : @""];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDBlockType

- (instancetype)initWithArgumentString:(NSString *)string {
    self = [super initWithByteSize:sizeof(void (^)(void)) alignment:alignof(void (^)(void))];
    return self;
}

- (NSString *)format {
    return @"void (^%@)(...)";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPointerType

- (instancetype)initWithPointeeType:(RDType *)type {
    self = [super initWithByteSize:sizeof(void *) alignment:alignof(void *)];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [NSString stringWithFormat:fmt, @"*%@"];
    else
        return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDConstType

- (instancetype)initWithType:(RDType *)type {
    self = [super initWithByteSize:type.size alignment:type.alignment];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [NSString stringWithFormat:fmt, @"const %@"];
    else
        return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDAtomicType

- (instancetype)initWithType:(RDType *)type {
    self = [super initWithByteSize:type.size alignment:type.alignment]; // is this assumption safe?
    if (self) {
        _type = type;
    }
    return self;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [NSString stringWithFormat:fmt, @"_Atomic %@"];
    else
        return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDComplexType

- (instancetype)initWithType:(RDType *)type {
    self = [super initWithByteSize:type.size * 2 alignment:type.alignment];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSString *)format {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [NSString stringWithFormat:fmt, @"_Complex %@"];
    else
        return nil;
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDArrayType

- (instancetype)initWithCount:(NSUInteger)count elementsOfType:(RDType *)type {
    type = type ?: [[RDPointerType alloc] initWithPointeeType:[RDPrimitiveType instanceWithKind:RDPrimitiveTypeKindVoid]];
    self = [super initWithByteSize:type.size * count alignment:type.alignment];
    if (self) {
        _count = count;
        _type = type;
    }
    return self;
}

- (size_t)offsetForElementAtIndex:(NSUInteger)index {
    if (index >= self.count)
        return RDFieldOffsetUnknown;

    if (self.type == nil)
        return RDFieldOffsetUnknown;
    
    size_t size = self.type.size;
    size_t alignment = self.type.alignment;

    if (size == 0 || size == RDTypeSizeUnknown || alignment == RDTypeSizeUnknown)
        return RDFieldOffsetUnknown;
    
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDField

- (instancetype)initWithName:(NSString *)name type:(RDType *)type {
    self = [super init];
    if (self) {
        _name = name.copy;
        _type = type;
    }
    return self;
}

- (NSString *)description {
    if (NSString *fmt = self.type.format; fmt.length > 1)
        return [[NSString stringWithFormat:fmt, self.name ?: @"_"] stringByAppendingString:@";"];
    else
        return self.name ?: @"_";
}

- (void)setOffset:(size_t)offset {
    _offset = offset;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDStructType

- (instancetype)initWithName:(NSString *)name fields:(NSArray<RDField *> *)fields {
    size_t offset = 0;
    size_t alignment = 1;

    for (RDField *field in fields) {
        size_t falignment = field.type.alignment;
        size_t fsize = field.type.size;

        if (field.type == nil || falignment == RDTypeAlignmentUnknown || fsize == RDTypeSizeUnknown) {
            offset = RDTypeSizeUnknown;
            alignment = RDTypeAlignmentUnknown;
            break;
        }

        while (offset % falignment != 0)
            ++offset;

        field.offset = offset;
        offset += field.type.size;
        alignment = MAX(falignment, alignment);
    }
    
    if (offset == RDTypeSizeUnknown || alignment == RDTypeAlignmentUnknown)
        for (RDField *field in fields)
            field.offset = RDFieldOffsetUnknown;
    else
        while (offset != RDTypeSizeUnknown && offset % alignment != 0)
            ++offset;

    self = [super initWithByteSize:MAX(1, offset) alignment:alignment];
    if (self) {
        _name = name.copy;
        _fields = fields.copy;
    }
    return self;
}

- (NSString *)format {
    return [NSString stringWithFormat:@"struct %@ { %@ } %%@", self.name ?: @"", [self.fields componentsJoinedByString:@" "]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDUnionType

- (instancetype)initWithName:(NSString *)name fields:(NSArray<RDField *> *)fields {
    size_t size = 1;
    size_t alignment = 1;
    for (RDField *field in fields) {
        size = MAX(field.type.size, size);
        alignment = MAX(field.type.alignment, alignment);
        field.offset = 0u;
    }
    
    self = [super initWithByteSize:size alignment:alignment];
    if (self) {
        _name = name.copy;
        _fields = fields.copy;
    }
    return self;
}

- (NSString *)format {
    return [NSString stringWithFormat:@"union %@ { %@ } %%@", self.name, [self.fields componentsJoinedByString:@" "]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDMethodArgumentAttribute

- (instancetype)initWithKind:(RDMethodArgumentAttributeKind)kind {
    self = [super init];
    if (self) {
        _kind = kind;
    }
    return self;
}

- (NSString *)description {
    switch (self.kind) {
        case RDMethodArgumentAttributeKindConst:
            return @"const";
        case RDMethodArgumentAttributeKindIn:
            return @"in";
        case RDMethodArgumentAttributeKindOut:
            return @"inout";
        case RDMethodArgumentAttributeKindInOut:
            return @"out";
        case RDMethodArgumentAttributeKindByCopy:
            return @"bycopy";
        case RDMethodArgumentAttributeKindByRef:
            return @"byref";
        case RDMethodArgumentAttributeKindOneWay:
            return @"oneway";
        case RDMethodArgumentAttributeKindWTF:
            return @"?";
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDMethodArgument

- (instancetype)initWithType:(RDType *)type offset:(NSUInteger)offset attributes:(NSOrderedSet<RDMethodArgumentAttribute *> *)attributes {
    self = [super init];
    if (self) {
        _type = type;
        _offset = offset;
        _attributes = attributes.copy;
    }
    return self;
}

- (NSString *)description {
    NSString *attrs = self.attributes.count > 0 ? [[self.attributes.array componentsJoinedByString:@" "] stringByAppendingString:@" "] : @"";
    return [attrs stringByAppendingString:self.type.description ?: @""];
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

- (instancetype)initWithArguments:(NSArray<RDMethodArgument *> *)arguments {
    self = [super init];
    if (self) {
        if (arguments.count < 2)
            return nil;
        
        _returnValue = arguments.firstObject;
        _arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)];
    }
    return self;
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
            case RDPrimitiveTypeKindClass:
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
            case RDPrimitiveTypeKindVoid:
            case RDPrimitiveTypeKindCString:
            case RDPrimitiveTypeKindAtom:
            case RDPrimitiveTypeKindUnknown: {
                return [RDPrimitiveType instanceWithKind:(RDPrimitiveTypeKind)*((*encoding)++)];
            }
                
            case RDCompositeTypeKindObject: {
                ++(*encoding);
                if (**encoding == RDPrimitiveTypeKindUnknown) {
                    NSString *args = nil;
                    if (*(++(*encoding)) == RDTypeEncodingSymbolBlockArgsBegin)
                        args = parseString(encoding, RDTypeEncodingSymbolBlockArgsEnd);
                    return [[RDBlockType alloc] initWithArgumentString:args];
                }
                NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
                NSArray<NSString *> *components = [parseQuotedString(encoding) componentsSeparatedByCharactersInSet:separators];
                NSArray<NSString *> *protocols = map_nn([components subarrayWithRange:NSMakeRange(1, components.count - 1)], ^NSString *(NSString *p) {
                    return p.length == 0 ? nil : p;
                });
                return [[RDObjectType alloc] initWithClassName:components.firstObject protocolNames:protocols];
            }
                
            case RDCompositeTypeKindPointer: {
                ++(*encoding);
                const char *e = *encoding;
                if (RDType *type = parseType(encoding); type != nil)
                    return [[RDPointerType alloc] initWithPointeeType:type];
                
                *encoding = e;
                return [[RDPointerType alloc] initWithPointeeType:nil];
            }
                
            case RDCompositeTypeKindConst: {
                ++(*encoding);
                RDType *type = parseType(encoding);
                if (type == nil)
                    return nil;
                
                return [[RDConstType alloc] initWithType:type];
            }
                
            case RDCompositeTypeKindAtomic: {
                ++(*encoding);
                RDType *type = parseType(encoding);
                if (type == nil)
                    return nil;
                
                return [[RDAtomicType alloc] initWithType:type];
            }
            case RDCompositeTypeKindComplex: {
                ++(*encoding);
                RDType *type = parseType(encoding);
                if (type == nil)
                    return nil;
                
                return [[RDComplexType alloc] initWithType:type];
            }
                
            case RDCompositeTypeKindBitfield: {
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
                
                RDField *(^parseField)(const char *_Nonnull *_Nonnull) = ^RDField *(const char *_Nonnull *_Nonnull encoding) {
                    NSString *name = parseQuotedString(encoding);
                    if (**encoding == RDTypeEncodingSymbolQuote || **encoding == cl)
                        return [[RDField alloc] initWithName:name type:nil];
                    else if (RDType *type = parseType(encoding); type != nil)
                        return [[RDField alloc] initWithName:name type:type];
                    else
                        return nil;
                };
                
                static constexpr size_t LIMIT = 8192;
                char buff[LIMIT] = {};
                unsigned index = 0;
                while (index < LIMIT && **encoding != RDTypeEncodingSymbolStructBodySep && **encoding != cl && **encoding != '\0')
                    buff[index++] = *((*encoding)++);
                
                NSString *name = buff[0] == '?' && buff[1] == '\0' ? nil : [NSString stringWithUTF8String:buff];
                
                NSMutableArray<RDField *> *fields = nil;
                
                if (**encoding == RDTypeEncodingSymbolStructBodySep) {
                    ++(*encoding);
                    
                    fields = [NSMutableArray array];
                    while (**encoding != cl && **encoding != '\0')
                        if (RDField *field = parseField(encoding); field != nil)
                            [fields addObject:field];
                        else
                            return nil;
                }
                
                if (**encoding == cl)
                    ++(*encoding);
                
                if (isStruct)
                    return [[RDStructType alloc] initWithName:name fields:fields];
                else
                    return [[RDUnionType alloc] initWithName:name fields:fields];
            }
                
            default: {
                return nil;
            }
        }
    }
    return nil;
}

RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding) {
    RDMethodArgument *(^parseMethodArgument)(const char *_Nonnull *_Nonnull) = ^RDMethodArgument *(const char *_Nonnull *_Nonnull encoding) {
        NSMutableOrderedSet<RDMethodArgumentAttribute *> *attributes = [NSMutableOrderedSet orderedSet];
        while (**encoding != '\0') {
            switch (**encoding) {
                case RDMethodArgumentAttributeKindConst:
                case RDMethodArgumentAttributeKindIn:
                case RDMethodArgumentAttributeKindOut:
                case RDMethodArgumentAttributeKindInOut:
                case RDMethodArgumentAttributeKindByCopy:
                case RDMethodArgumentAttributeKindByRef:
                case RDMethodArgumentAttributeKindOneWay:
                case RDMethodArgumentAttributeKindWTF:
                    [attributes addObject:[[RDMethodArgumentAttribute alloc] initWithKind:(RDMethodArgumentAttributeKind)*((*encoding)++)]];
                    break;
                default:
                    if (**encoding >= '0' && **encoding <= '9')
                        return [[RDMethodArgument alloc] initWithType:nil offset:parseNumber(encoding) attributes:attributes];
                    
                    RDType *type = parseType(encoding);
                    if (type == nil)
                        return nil;
                    
                    NSUInteger offset = parseNumber(encoding);
                    return [[RDMethodArgument alloc] initWithType:type offset:offset attributes:attributes];
            }
        }
        return nil;
    };
    
    NSMutableArray<RDMethodArgument *> *arguments = [NSMutableArray array];
    while (**encoding != '\0')
        if (RDMethodArgument *argument = parseMethodArgument(encoding); argument != nil)
            [arguments addObject:argument];
        else
            return nil;
    
    return [[RDMethodSignature alloc] initWithArguments:arguments];
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
