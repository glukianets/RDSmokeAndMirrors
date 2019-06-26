#import "RDType.h"
#import "RDCommon.h"

#include <initializer_list>
#include <algorithm>

static size_t parseCountSucceded = 0;
static size_t parseCountFailed = 0;

RDType *parseType(const char *_Nonnull *_Nonnull encoding);
RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding);
RDPropertySignature *parsePropertySignature(const char *_Nonnull *_Nonnull encoding);

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
    return parseType(&encoding);
}

- (NSString *)description {
    return [[NSString stringWithFormat:self.format ?: @"%@", @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString *)format {
    return @"%@";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDUnknownType

- (NSString *)format {
    return @"? %@";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPrimitiveType : RDType

- (instancetype)initWithKind:(RDPrimitiveTypeKind)size {
    self = [super init];
    if (self) {
        _kind = size;
    }
    return self;
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDObjectType

- (instancetype)initWithClassName:(NSString *)cls protocolNames:(NSArray<NSString *> *)protocols {
    self = [super init];
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

- (NSString *)format {
    return @"void (^%@)(...)";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDPointerType

- (instancetype)initWithPointeeType:(RDType *)type {
    self = [super init];
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
    self = [super init];
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
    self = [super init];
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
    self = [super init];
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
    self = [super init];
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

- (instancetype)initWithSize:(NSUInteger)size elementsOfType:(RDType *)type {
    self = [super init];
    if (self) {
        _size = size;
        _type = type;
    }
    return self;
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDStructType

- (instancetype)initWithName:(NSString *)name fields:(NSArray<RDField *> *)fields {
    self = [super init];
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
    self = [super init];
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
                return [[RDPrimitiveType alloc] initWithKind:(RDPrimitiveTypeKind)*((*encoding)++)];
            }
                
            case RDCompositeTypeKindObject: {
                ++(*encoding);
                if (**encoding == RDPrimitiveTypeKindUnknown) {
                    if (*(++(*encoding)) == RDTypeEncodingSymbolBlockArgsBegin)
                        parseString(encoding, RDTypeEncodingSymbolBlockArgsEnd);
                    return [[RDBlockType alloc] init];
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
                    return [[RDArrayType alloc] initWithSize:size elementsOfType:nil];
                
                RDType *type = parseType(encoding);
                if (type == nil)
                    return nil;
                
                if (*((*encoding)++) != RDTypeEncodingSymbolArrayEnd)
                    return nil;
                
                return [[RDArrayType alloc] initWithSize:size elementsOfType:type];
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
                
                NSString *name = buff[0] == '?' && buff[1] == '\0' ? nil :  [NSString stringWithUTF8String:buff];
                
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
