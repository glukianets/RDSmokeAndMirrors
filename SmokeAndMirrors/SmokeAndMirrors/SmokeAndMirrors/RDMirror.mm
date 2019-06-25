#import "RDMirror.h"

#include <initializer_list>
#include <algorithm>

static size_t parseCountSucceded = 0;
static size_t parseCountFailed = 0;

RDType *parseType(const char *_Nonnull *_Nonnull encoding);
RDMethodSignature *parseMethodSignature(const char *_Nonnull *_Nonnull encoding);
RDPropertySignature *parsePropertySignature(const char *_Nonnull *_Nonnull encoding);
NSString *methodString(SEL selector, RDMethodSignature *signature, BOOL isInstanceLevel);
NSString *propertyString(NSString *name, RDPropertySignature *signature, BOOL isInstanceLevel);

template<typename T, typename U>
NSArray<U *> *_Nullable map_nn(NSArray<T *> *_Nullable source, U *_Nullable (^_Nonnull block)(T *_Nonnull)) {
    if (source == nil)
        return nil;
    
    NSMutableArray<U *> *result = [NSMutableArray arrayWithCapacity:source.count];
    for (T *obj in source)
        if (U *res = block(obj); res)
            [result addObject:res];
    
    return result;
}

template<typename R, typename ... T>
NSArray<R *> *zip(R *_Nullable (^_Nonnull zipper)(T *_Nonnull...), NSArray<T *> *... args) {
    NSMutableArray<R *> *result = [NSMutableArray array];
    for (NSUInteger i = 0; i < std::min(args.count...); ++i)
        if (R *object = zipper(args[i]...); object)
            [result addObject:object];
    
    return result;
}

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
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


RD_FINAL_CLASS
@interface RDObjcOpaqueItem : NSObject<NSCopying>

+ (instancetype)itemWithClass:(Class)cls;
+ (instancetype)itemWithProtocol:(Protocol *)proto;
+ (instancetype)itemWithProperty:(Property)prop;
+ (instancetype)itemWithMethod:(Method)method;
+ (instancetype)itemWithIvar:(Ivar)ivar;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation RDObjcOpaqueItem {
@private
    uintptr_t _value;
}

+ (instancetype)itemWithClass:(Class)cls {
    return [[self alloc] initWithPointerValue:(uintptr_t)cls];
}

+ (instancetype)itemWithProtocol:(Protocol *)proto {
    return [[self alloc] initWithPointerValue:(uintptr_t)proto];
}

+ (instancetype)itemWithProperty:(Property)prop {
    return [[self alloc] initWithPointerValue:(uintptr_t)prop];
}

+ (instancetype)itemWithMethod:(Method)method {
    return [[self alloc] initWithPointerValue:(uintptr_t)method];
}

+ (instancetype)itemWithIvar:(Ivar)ivar {
    return [[self alloc] initWithPointerValue:(uintptr_t)ivar];
}

- (instancetype)initWithPointerValue:(uintptr_t)ptr {
    self = [super init];
    if (self) {
        _value = ptr;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    return self == object || ([object isKindOfClass:self.class] && ((RDObjcOpaqueItem *)object)->_value == _value);
}

- (NSUInteger)hash {
    return (NSUInteger)_value;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSCache<RDObjcOpaqueItem *, RDMirror *> *mirrorsCache = [NSCache new];

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMirror()
@end

@implementation RDMirror
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDClass()

@property (nonatomic, readonly) __unsafe_unretained Class cls;

- (instancetype)initWithClass:(Class)cls registry:(NSMutableDictionary<RDObjcOpaqueItem *, RDClass *> *)regirsty NS_DESIGNATED_INITIALIZER;

@end

@implementation RDClass

+ (instancetype)mirrorForObjcClass:(Class)cls {
    return [self mirrorForObjcClass:cls registry:[NSMutableDictionary dictionary]];
}

+ (instancetype)mirrorForObjcClass:(Class)cls registry:(NSMutableDictionary<RDObjcOpaqueItem *, RDClass *> *)registry {
    @synchronized (mirrorsCache) {
        RDObjcOpaqueItem *item = [RDObjcOpaqueItem itemWithClass:cls];
        RDMirror *mirror = registry[item];
        if (mirror == nil) {
            mirror = [mirrorsCache objectForKey:item];
            if (mirror == nil) {
                mirror = [[self alloc] initWithClass:cls registry:registry];
                [mirrorsCache setObject:mirror forKey:item];
            }
            NSAssert([mirror isKindOfClass:self], @"Mistyped cached object %@ for item %@", mirror, item);
        }
        return (id)mirror;
    }
}

- (instancetype)initWithClass:(Class)cls registry:(NSMutableDictionary<RDObjcOpaqueItem *, RDClass *> *)registry {
    self = [super init];
    if (self) {
        registry[[RDObjcOpaqueItem itemWithClass:cls]] = self;
        
        _cls = cls;

        _super = ({
            Class supr = class_getSuperclass(cls);
            supr == Nil ? nil : [RDClass mirrorForObjcClass:supr registry:registry];
        });
        
        _meta = ({
            Class meta = object_getClass(cls);
            meta == cls ? self : [RDClass mirrorForObjcClass:meta registry:registry];
        });
        
        _name = ({
            const char *name = class_getName(cls);
            name == NULL ? nil : [NSString stringWithUTF8String:class_getName(cls)];
        });
        
        _imageName = ({
            const char *imageName = class_getImageName(cls);
            imageName == NULL ? nil : [NSString stringWithUTF8String:imageName];
        });

        _version = class_getVersion(cls);
        
        _protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = class_copyProtocolList(cls, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [RDProtocol mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });
        
        _methods = ({
            unsigned count;
            Method *methodList = class_copyMethodList(cls, &count);
            RDMethod *methods[count];
            for (unsigned i = 0; i < count; ++i)
                methods[i] = [RDMethod mirrorForObjcMethod:methodList[i]];
            free(methodList);
            [NSArray arrayWithObjects:methods count:count];
        });
        
        _ivars = ({
            unsigned int count;
            Ivar *ivarList = class_copyIvarList(cls, &count);
            RDIvar *ivars[count];
            for (unsigned i = 0; i < count; ++i)
                ivars[i] = [RDIvar mirrorForObjcIvar:ivarList[i]];
            free(ivarList);
            [NSArray arrayWithObjects:ivars count:count];
        });
        
        _properties = ({
            unsigned int count;
            Property *propertyList = class_copyPropertyList(cls, &count);
            RDProperty *properties[count];
            for (unsigned i = 0; i < count; ++i)
                properties[i] = [RDProperty mirrorForObjcProperty:propertyList[i]];
            free(propertyList);
            [NSArray arrayWithObjects:properties count:count];
        });
    }
    return self;
}

- (NSString *)description {
    NSString *protocols = self.protocols.count == 0 ? @"" : ({
        NSString *comps = [[self.protocols valueForKeyPath:@"@unionOfObjects.name"] componentsJoinedByString:@", "];
        [NSString stringWithFormat:@" <%@>", comps];
    });
    NSString *ivars = self.ivars.count == 0 ? @"\n\n" : ({
        NSString *ivars = [self.ivars componentsJoinedByString:@"\n    "];
        [NSString stringWithFormat:@" {\n    %@\n}\n\n", ivars];
    });
    NSString *properties = self.properties.count == 0 ? @"" : ({
        [[self.properties componentsJoinedByString:@"\n"] stringByAppendingString:@"\n\n"];
    });
    NSString *methods = self.methods.count == 0 ? @"" : ({
        [[self.methods componentsJoinedByString:@"\n"] stringByAppendingString:@"\n\n"];
    });
    
    return [NSString stringWithFormat:@"@interface %@ : %@%@%@%@%@@end",
            self.name,
            self.super.name,
            protocols,
            ivars,
            properties,
            methods];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDProtocolItem

- (instancetype)initAsRequired:(BOOL)required atClassLevel:(BOOL)classLevel {
    self = [super init];
    if (self) {
        _required = required;
        _classLevel = classLevel;
    }
    return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocolMethod()
@property (nonatomic, readonly) MethodDescription method;
@end

@implementation RDProtocolMethod

- (instancetype)initWithObjcConterpart:(MethodDescription)method required:(BOOL)required classLevel:(BOOL)classLevel {
    self = [super initAsRequired:required atClassLevel:classLevel];
    if (self) {
        _method = method;
        _selector = method.name;
        _signature = [RDMethodSignature signatureWithObjcTypeEncoding:method.types];
    }
    return self;
}

- (NSString *)description {
    return methodString(self.selector, self.signature, !self.isClassLevel);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocolProperty()
@property (nonatomic, readonly) Property property;
@property (nonatomic, readonly) RDPropertySignature *signature;
@end

@implementation RDProtocolProperty

- (instancetype)initWithObjcConterpart:(Property)property required:(BOOL)required classLevel:(BOOL)classLevel {
    self = [super initAsRequired:required atClassLevel:classLevel];
    if (self) {
        _property = property;
        _name = [NSString stringWithUTF8String:property_getName(property)];
        _signature = [RDPropertySignature signatureWithObjcTypeEncoding:property_getAttributes(property)];
    }
    return self;
}

- (NSString *)description {
    return propertyString(self.name, self.signature, !self.isClassLevel);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocol()

@property (nonatomic, readonly) Protocol *protocol;

- (instancetype)initWithProtocol:(Protocol *)protocol NS_DESIGNATED_INITIALIZER;

@end

@implementation RDProtocol

+ (instancetype)mirrorForObjcProtocol:(Protocol *)protocol {
    @synchronized (mirrorsCache) {
        RDObjcOpaqueItem *item = [RDObjcOpaqueItem itemWithProtocol:protocol];
        RDMirror *mirror = [mirrorsCache objectForKey:item];
        if (mirror == nil) {
            mirror = [[self alloc] initWithProtocol:protocol];
            [mirrorsCache setObject:mirror forKey:item];
        }
        NSAssert([mirror isKindOfClass:self], @"Mistyped cached object %@ for item %@", mirror, item);
        return (id)mirror;
    }
}

+ (NSSet<NSString *> *)excludedProtocolNames {
    static NSSet<NSString *> *set = [NSSet setWithObjects:
                                     @"NSItemProviderReading",
                                     @"_NSAsynchronousPreparationInputParameters",
                                     @"SFDigestOperation",
                                     @"MPSCNNBatchNormalizationDataSource",
                                     nil];
    return set;
}

- (instancetype)initWithProtocol:(Protocol *)protocol {
    self = [super init];
    if (self) {
        _protocol = protocol;
        _name = [NSString stringWithUTF8String:protocol_getName(protocol)];
        if ([self.class.excludedProtocolNames containsObject:_name])
            return self;
        
        _protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = protocol_copyProtocolList(protocol, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [RDProtocol mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });
        
        _properties = ({
            NSMutableArray<RDProtocolProperty *> *properties = [NSMutableArray array];
            for (BOOL isRequired : {YES, NO}) {
                for (BOOL isInstanceLevel : {YES, NO}) {
                    unsigned int count = 0;
                    Property *propertyList = protocol_copyPropertyList2(protocol, &count, isRequired, isInstanceLevel);
                    for (unsigned i = 0; i < count; ++i)
                        [properties addObject:[[RDProtocolProperty alloc] initWithObjcConterpart:propertyList[i]
                                                                                        required:isRequired
                                                                                      classLevel:!isInstanceLevel]];
                    free(propertyList);
                }
            }
            properties;
        });
        
        _methods = ({
            NSMutableArray<RDProtocolMethod *> *methods = [NSMutableArray array];
            for (BOOL isRequired : {YES, NO}) {
                for (BOOL isInstanceLevel : {YES, NO}) {
                    unsigned count = 0;
                    MethodDescription *methodList = protocol_copyMethodDescriptionList(protocol, isRequired, isInstanceLevel, &count);
                    for (unsigned i = 0; i < count; ++i)
                        [methods addObject:[[RDProtocolMethod alloc] initWithObjcConterpart:methodList[i]
                                                                                   required:isRequired
                                                                                 classLevel:!isInstanceLevel]];
                    free(methodList);
                }
            }
            methods;
        });
    }
    return self;
}

- (NSString *)description {
    __auto_type requiredFilter = ^__kindof RDProtocolItem *(__kindof RDProtocolItem *i) { return i.isRequired ? i : nil; };
    __auto_type optionalFilter = ^__kindof RDProtocolItem *(__kindof RDProtocolItem *i) { return i.isRequired ? nil : i; };
    
    NSString *optionalSection = ({
        NSMutableArray *section = [NSMutableArray array];
        if (NSArray *array = map_nn(self.properties, optionalFilter); array.count > 0)
            [section addObject:[[array componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]];
        if (NSArray *array = map_nn(self.methods, optionalFilter); array.count > 0)
            [section addObject:[array componentsJoinedByString:@"\n"]];
        section.count > 0 ? [section componentsJoinedByString:@"\n"] : nil;
    });
    
    NSString *requiredSection = ({
        NSMutableArray *section = [NSMutableArray array];
        if (NSArray *array = map_nn(self.properties, requiredFilter); array.count > 0)
            [section addObject:[[array componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]];
        if (NSArray *array = map_nn(self.methods, requiredFilter); array.count > 0)
            [section addObject:[array componentsJoinedByString:@"\n"]];
        section.count > 0 ? [section componentsJoinedByString:@"\n"] : nil;
    });
    
    return [NSString stringWithFormat:@"@protocol %@ <%@>\n\n%@%@@end",
            self.name,
            [[self.protocols valueForKeyPath:@"@unionOfObjects.name"] componentsJoinedByString:@", "],
            requiredSection ? [NSString stringWithFormat:@"%@\n\n", requiredSection] : @"",
            optionalSection ? [NSString stringWithFormat:@"@optional\n%@\n\n", optionalSection] : @""
            ];
}


@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethod()

@property (nonatomic, readonly) Method method;

- (instancetype)initWithMethod:(Method)method NS_DESIGNATED_INITIALIZER;

@end

@implementation RDMethod

+(instancetype)mirrorForObjcMethod:(Method)method {
    @synchronized (mirrorsCache) {
        RDObjcOpaqueItem *item = [RDObjcOpaqueItem itemWithMethod:method];
        RDMirror *mirror = [mirrorsCache objectForKey:item];
        if (mirror == nil) {
            mirror = [[self alloc] initWithMethod:method];
            [mirrorsCache setObject:mirror forKey:item];
        }
        NSAssert([mirror isKindOfClass:self], @"Mistyped cached object %@ for item %@", mirror, item);
        return (id)mirror;
    }
}

- (instancetype)initWithMethod:(Method)method {
    self = [super init];
    if (self) {
        _method = method;
        _selector = method_getName(method);
        _signature = ({
            RDMethodSignature *signature = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
            NSUInteger argCount = 0;
            for (const char *sel = sel_getName(_selector); *sel != '\0'; ++sel)
                if (*sel == ':')
                    ++argCount;
            
            signature.arguments.count == argCount + 2 ? signature : nil;
        });
    }
    return self;
}

- (NSString *)description {
    return methodString(self.selector, self.signature, YES);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProperty()

@property (nonatomic, readonly) Property property;

- (instancetype)initWithProperty:(Property)property NS_DESIGNATED_INITIALIZER;

@end

@implementation RDProperty

+ (instancetype)mirrorForObjcProperty:(Property)property {
    @synchronized (mirrorsCache) {
        RDObjcOpaqueItem *item = [RDObjcOpaqueItem itemWithProperty:property];
        RDMirror *mirror = [mirrorsCache objectForKey:item];
        if (mirror == nil) {
            mirror = [[self alloc] initWithProperty:property];
            [mirrorsCache setObject:mirror forKey:item];
        }
        NSAssert([mirror isKindOfClass:self], @"Mistyped cached object %@ for item %@", mirror, item);
        return (id)mirror;
    }
}

- (instancetype)initWithProperty:(Property)property {
    self = [super init];
    if (self) {
        _property = property;
        _name = [NSString stringWithUTF8String:property_getName(property)];
        _signature = [RDPropertySignature signatureWithObjcTypeEncoding:property_getAttributes(property)];
    }
    return self;
}

- (NSString *)description {
    return propertyString(self.name, self.signature, YES);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDIvar()

@property (nonatomic, readonly) Ivar ivar;

- (instancetype)initWithIvar:(Ivar)ivar NS_DESIGNATED_INITIALIZER;

@end

@implementation RDIvar

+ (instancetype)mirrorForObjcIvar:(Ivar)ivar {
    @synchronized (mirrorsCache) {
        RDObjcOpaqueItem *item = [RDObjcOpaqueItem itemWithIvar:ivar];
        RDMirror *mirror = [mirrorsCache objectForKey:item];
        if (mirror == nil) {
            mirror = [[self alloc] initWithIvar:ivar];
            [mirrorsCache setObject:mirror forKey:item];
        }
        NSAssert([mirror isKindOfClass:self], @"Mistyped cached object %@ for item %@", mirror, item);
        return (id)mirror;
    }
}

- (instancetype)initWithIvar:(Ivar)ivar {
    self = [super init];
    if (self) {
        _ivar = ivar;
        _name = [NSString stringWithUTF8String:ivar_getName(ivar)];
        _offset = ivar_getOffset(ivar);
        if (const char *encoding = ivar_getTypeEncoding(ivar); encoding != NULL && *encoding != '\0')
            _type = parseCheck(parseType, &encoding);
    }
    return self;
}

- (NSString *)description {
    return [[NSString stringWithFormat:self.type.format ?: @"%@", self.name ?: @"_"] stringByAppendingString:@";"];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
    return [NSString stringWithFormat:@"(%@%@)", attrs, self.type.description ?: @""];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *methodString(SEL selector, RDMethodSignature *signature, BOOL isInstanceLevel) {
    NSString *returnType = signature.returnValue.description ?: @"()";
    NSString *body = ({
        NSString *body;
        NSArray<NSString *> *nameParts = [[NSString stringWithUTF8String:sel_getName(selector)] componentsSeparatedByString:@":"];
        if (nameParts.count == 1) {
            body = nameParts.firstObject;
        } else {
            NSArray<RDMethodArgument *> *arguments = [signature.arguments subarrayWithRange:NSMakeRange(2, signature.arguments.count - 2)];
            body = [zip(^NSString *(NSString *name, RDMethodArgument *argument) {
                return [name stringByAppendingFormat:@":%@arg%d", argument.description ?: @"", 1];
            }, nameParts, arguments) componentsJoinedByString:@" "];
        }
        body;
    });
    return [NSString stringWithFormat:@"%c %@%@;", isInstanceLevel ? '-' : '+' , returnType, body];
}

NSString *propertyString(NSString *name, RDPropertySignature *signature, BOOL isInstanceLevel) {
    NSMutableArray<NSString *> *attributeStrings = map_nn(signature.attributes, ^NSString *(RDPropertyAttribute *attribute) {
        return attribute.description;
    }).mutableCopy;
    
    if (!isInstanceLevel)
        [attributeStrings addObject:@"class"];
    
    NSString *attributes = attributeStrings.count == 0 ? nil : [NSString stringWithFormat:@"(%@)", [attributeStrings componentsJoinedByString:@", "]];
    
    NSString *typeName = [NSString stringWithFormat:signature.type.format ?: @"%@", name];
    
    return [NSString stringWithFormat:@"@property %@%@;", [attributes stringByAppendingString:@" "] ?: @"", typeName];
}
