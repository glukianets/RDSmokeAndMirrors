#import "RDMirror.h"
#import "RDMirrorPrivate.h"
#import "RDSmoke.h"
#import "RDPrivate.h"

NSString *methodString(SEL selector, RDMethodSignature *signature, BOOL isInstanceLevel);
NSString *blockString(NSString *name, RDMethodSignature *signature);
NSString *propertyString(NSString *name, RDPropertySignature *signature, BOOL isInstanceLevel);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMirror()
- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;
@end

@implementation RDMirror

- (instancetype)initWithSmoke:(RDSmoke *)smoke {
    self = [super init];
    if (self) {
        _smoke = smoke;
    }
    return self;
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDClass()

@property (nonatomic, readonly) __unsafe_unretained Class objcClass;
@property (nonatomic, readonly) __unsafe_unretained Class objcSuper;
@property (nonatomic, readonly) __unsafe_unretained Class objcMeta;

- (instancetype)initWithObjcClass:(Class)cls
                          inSmoke:(RDSmoke *)smoke
                         withName:(NSString *)name
                          version:(int)version
                     instanceSize:(size_t)instanceSize
                            image:(NSString *)image
                             supr:(Class)supr
                             meta:(Class)meta
                        protocols:(NSArray<RDProtocol *> *)protocols
                          methods:(NSArray<RDMethod *> *)methods
                            ivars:(NSArray<RDIvar *> *)ivars
                       properties:(NSArray<RDProperty *> *)properties NS_DESIGNATED_INITIALIZER;

@end

@implementation RDClass
@synthesize super = _super;
@synthesize meta = _meta;

- (instancetype)initWithObjcClass:(Class)cls
                          inSmoke:(RDSmoke *)smoke
                         withName:(NSString *)name
                          version:(int)version
                     instanceSize:(size_t)instanceSize
                            image:(NSString *)image
                             supr:(Class)supr
                             meta:(Class)meta
                        protocols:(NSArray<RDProtocol *> *)protocols
                          methods:(NSArray<RDMethod *> *)methods
                            ivars:(NSArray<RDIvar *> *)ivars
                       properties:(NSArray<RDProperty *> *)properties
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _objcClass = cls;
        _objcSuper = supr;
        _objcMeta = meta;
        _name = name.copy;
        _version = version;
        _instanceSize = instanceSize;
        _imageName = image.copy;
        _protocols = protocols.copy;
        _methods = methods.copy;
        _ivars = ivars.copy;
        _properties = properties.copy;
        _objcSuper = class_getSuperclass(cls);
        _objcMeta = object_getClass(cls);
    }
    return self;
}

- (instancetype)initWithObjcClass:(__unsafe_unretained Class)cls inSmoke:(RDSmoke *)smoke {
    if (cls == Nil)
        return nil;
    
    self = [super initWithSmoke:smoke];
    if (self) {
        _objcClass = cls;
        _objcSuper = class_getSuperclass(cls);
        _objcMeta = object_getClass(cls);

        _name = ({
            const char *name = class_getName(cls);
            name == NULL ? nil : [NSString stringWithUTF8String:class_getName(cls)];
        });

       _imageName = ({
            const char *imageName = class_getImageName(cls);
            imageName == NULL ? nil : [NSString stringWithUTF8String:imageName];
        });

        _version = class_getVersion(cls);

        _instanceSize = class_getInstanceSize(cls);
        
        _protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = class_copyProtocolList(cls, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [smoke mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });

        _methods = ({
            unsigned count;
            Method *methodList = class_copyMethodList(cls, &count);
            RDMethod *methods[count];
            for (unsigned i = 0; i < count; ++i)
                methods[i] = [smoke mirrorForObjcMethod:methodList[i]];
            free(methodList);
            [NSArray arrayWithObjects:methods count:count];
        });

        _ivars = ^{
            unsigned int count;
            Ivar *ivarList = class_copyIvarList(cls, &count);
            if (count == 0)
                return (void)free(ivarList), @[];
            
            RDIvar *ivars[count];
            for (unsigned i = 0; i < count; ++i)
                ivars[i] = [smoke mirrorForObjcIvar:ivarList[i]];
            free(ivarList);
                        
            auto layoutIndices = ^NSIndexSet *(const uint8_t *layout, size_t istart) {
                NSUInteger startIndex = istart / sizeof(id);
                if (istart % sizeof(id) != 0 || layout == NULL)
                    return nil;
                
                NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
                while (*layout != '\0') {
                    startIndex += (*layout & 0xf0) >> 4;
                    size_t len = *layout & 0x0f;
                    [indices addIndexesInRange:NSMakeRange(startIndex, len)];
                    startIndex += len;
                    ++layout;
                }
                return indices;
            };
            
            size_t istart = ivars[0].offset;
            const uint8_t *strongLayout = class_getIvarLayout(cls);
            NSIndexSet *istrong = layoutIndices(strongLayout, istart);
            const uint8_t *weakLayout = class_getWeakIvarLayout(cls);
            NSIndexSet *iweak = layoutIndices(weakLayout, istart);
            const size_t ss = sizeof(id); // slot size
            
            for (unsigned i = 0; i < count; ++i)
                if (ptrdiff_t offset = ivars[i].offset; offset % ss == 0)
                    ivars[i].retention = [iweak containsIndex:offset / ss] ? RDRetentionTypeWeak
                                       : [istrong containsIndex:offset / ss] ? RDRetentionTypeStrong
                                       : RDRetentionTypeUnsafeUnretained;
            
            return [NSArray arrayWithObjects:ivars count:count];
        }();
        
        _properties = ({
            unsigned int count;
            Property *propertyList = class_copyPropertyList(cls, &count);
            RDProperty *properties[count];
            for (unsigned i = 0; i < count; ++i)
                properties[i] = [smoke mirrorForObjcProperty:propertyList[i]];
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
    NSString *super = ({
        self.super ? [NSString stringWithFormat:@" : %@", self.super.name] : @"";
    });
    
    return [NSString stringWithFormat:@"@interface %@%@%@%@%@%@@end",
            self.name,
            super,
            protocols,
            ivars,
            properties,
            methods];
}

- (RDClass *)super {
    if (_super == nil && self.objcSuper != Nil)
        _super = [self.smoke mirrorForObjcClass:self.objcSuper];

    return _super;
}

- (RDClass *)meta {
    if (_meta == nil) {
        if (self.objcMeta == Nil || self.objcMeta == self.objcClass)
            return self;
        else
            _meta = [self.smoke mirrorForObjcClass:self.objcMeta];
    }
    
    return _meta;
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

- (instancetype)initWithObjcCounterpart:(MethodDescription)method required:(BOOL)required classLevel:(BOOL)classLevel {
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
@end

@implementation RDProtocolProperty

- (instancetype)initWithObjcCounterpart:(Property)property required:(BOOL)required classLevel:(BOOL)classLevel {
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

@end

@implementation RDProtocol

- (instancetype)initWithObjcProtocol:(Protocol *)protocol inSmoke:(RDSmoke *)smoke {
    static NSSet<NSString *> *excludedProtocolNames = [NSSet setWithObjects:
                                                       @"NSItemProviderReading",
                                                       @"_NSAsynchronousPreparationInputParameters",
                                                       @"SFDigestOperation",
                                                       @"SFKeyDerivingOperation",
                                                       @"MPSCNNBatchNormalizationDataSource",
                                                       @"NSItemProviderWriting",
                                                       @"ROCKForwardingInterposable",
                                                       @"NSSecureCoding",
                                                       nil];

    self = [super initWithSmoke:smoke];
    if (self) {
        _protocol = protocol;
        
        _name = ({
            const char *name = protocol_getName(protocol);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        
        _protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = protocol_copyProtocolList(protocol, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [smoke mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });

        if ([excludedProtocolNames containsObject:_name])
            return self;
        
        _properties = ({
            NSMutableArray<RDProtocolProperty *> *properties = [NSMutableArray array];
            for (BOOL isRequired : {YES, NO}) {
                for (BOOL isInstanceLevel : {YES, NO}) {
                    unsigned int count = 0;
                    Property *propertyList = protocol_copyPropertyList2(protocol, &count, isRequired, isInstanceLevel);
                    for (unsigned i = 0; i < count; ++i)
                        [properties addObject:[[RDProtocolProperty alloc] initWithObjcCounterpart:propertyList[i]
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
                        [methods addObject:[[RDProtocolMethod alloc] initWithObjcCounterpart:methodList[i]
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
    auto requiredFilter = ^__kindof RDProtocolItem *(__kindof RDProtocolItem *i) { return i.isRequired ? i : nil; };
    auto optionalFilter = ^__kindof RDProtocolItem *(__kindof RDProtocolItem *i) { return i.isRequired ? nil : i; };
    
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
@end

@implementation RDMethod

- (instancetype)initWithObjcMethod:(Method)method inSmoke:(RDSmoke *)smoke {
    self = [super initWithSmoke:smoke];
    if (self) {
        _method = method;
        _selector = method_getName(method);
        _signature = ({
            RDMethodSignature *signature = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
            NSUInteger argCount = 0;
            for (const char *sel = sel_getName(_selector); *sel != '\0'; ++sel)
                if (*sel == ':')
                    ++argCount;

            signature.isMethodSignature ? signature : nil;
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
@end

@implementation RDProperty

- (instancetype)initWithObjcProperty:(Property)property inSmoke:(RDSmoke *)smoke {
    self = [super initWithSmoke:smoke];
    if (self) {
        _property = property;

        _name = ({
            const char *name = property_getName(property);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        
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
@end

@implementation RDIvar

- (instancetype)initWithObjcIvar:(Ivar)ivar inSmoke:(RDSmoke *)smoke {
    self = [super initWithSmoke:smoke];
    if (self) {
        _ivar = ivar;
        
        _offset = ivar_getOffset(ivar);
        
        _name = ({
            const char *name = ivar_getName(ivar);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        
        _type = ({
            RDType *type = nil;
            if (const char *encoding = ivar_getTypeEncoding(ivar); encoding != NULL && *encoding != '\0')
                type = [RDType typeWithObjcTypeEncoding:encoding];
            type;
        });
    }
    return self;
}

- (NSString *)description {
    NSString *retention = ^{
        if ([self.type isKindOfClass:RDObjectType.self])
            switch (self.retention) {
            case RDRetentionTypeStrong: return @"";
            case RDRetentionTypeWeak: return @"__weak ";
            case RDRetentionTypeUnsafeUnretained: return @"__unsafe_unretained ";
            }
        else
            return @"";
    }();
    return [NSString stringWithFormat:@"%@%@;", retention, [NSString stringWithFormat:self.type.format ?: @"%@", self.name ?: @"_"]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBlock()
@property (nonatomic, readonly) RDBlockDescriptor *descriptor;
@end

@implementation RDBlock

- (instancetype)initWithBlockInfo:(RDBlockInfo *)blockInfo inSmoke:(RDSmoke *)smoke {
    RDClass *prototype = [smoke mirrorForObjcClass:blockInfo->isa];
    self = [super initWithObjcClass:prototype.objcClass
                            inSmoke:smoke
                           withName:prototype.name
                            version:prototype.version
                       instanceSize:RDBlockInfoGetInstanceSize(blockInfo)
                              image:prototype.imageName
                               supr:prototype.objcSuper
                               meta:prototype.objcMeta
                          protocols:prototype.protocols
                            methods:prototype.methods
                              ivars:prototype.ivars
                         properties:prototype.properties];
    if (self) {
        _descriptor = blockInfo->descriptor;
        _signature = [RDMethodSignature signatureWithObjcTypeEncoding:RDBlockInfoGetObjcSignature(blockInfo)];
        _kind = RDBlockInfoGetKind(blockInfo);
    }
    return self;
}

- (NSString *)description {
    return blockString([self.class nameForKind:self.kind], self.signature);
}

+ (NSString *)nameForKind:(RDBlockKind)kind {
    switch (kind) {
        case RDBlockKindGlobal:
            return @"globalBlock";
        case RDBlockKindStack:
            return @"stackBlock";
        case RDBlockKindMalloc:
            return @"mallocBlock";
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *methodArgumentString(RDMethodArgument *argument) {
    if (argument == nil)
        return nil;
    
    NSMutableString *attributesString = [NSMutableString string];
    RDType *type = argument->type;
    BOOL isConst = RD_CAST(type, RDCompositeType).kind == RDCompositeTypeKindConst;
    
    if (argument->attributes & RDMethodArgumentAttributeConst && !isConst)
        [attributesString appendString:@"const "];
    if (argument->attributes & RDMethodArgumentAttributeIn)
        [attributesString appendString:@"in "];
    if (argument->attributes & RDMethodArgumentAttributeOut)
        [attributesString appendString:@"out "];
    if (argument->attributes & RDMethodArgumentAttributeInOut)
        [attributesString appendString:@"inout "];
    if (argument->attributes & RDMethodArgumentAttributeByCopy)
        [attributesString appendString:@"bycopy "];
    if (argument->attributes & RDMethodArgumentAttributeByRef)
        [attributesString appendString:@"byref "];
    if (argument->attributes & RDMethodArgumentAttributeOneWay)
        [attributesString appendString:@"oneway "];
    
    [attributesString appendString:argument->type.description ?: @"?"];
    return attributesString;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *blockString(NSString *name, RDMethodSignature *signature) {
    NSString *returnType = methodArgumentString(signature.returnValue);
    NSMutableArray<NSString *> *arguments = [NSMutableArray array];
    for (NSUInteger i = 0; i < signature.argumentsCount; ++i)
        [arguments addObject:methodArgumentString([signature argumentAtIndex:i]) ?: @""];
    return [NSString stringWithFormat:@"^%@(%@);", returnType, [arguments componentsJoinedByString:@", "]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *methodString(SEL selector, RDMethodSignature *signature, BOOL isInstanceLevel) {
    NSMutableString *result = [NSMutableString string];
    [result appendFormat:@"%c ", isInstanceLevel ? '-' : '+'];
    if (NSString *ret = methodArgumentString(signature.returnValue); ret.length > 0)
        [result appendFormat:@"(%@)", ret ?: @""];

    NSString *selectorString = [NSString stringWithUTF8String:sel_getName(selector)];
    if (RDSelectorArgumentsCount(selector) == 0) {
        [result appendFormat:@"%@;", selectorString];
    } else {
        NSArray<NSString *> *nameParts = [selectorString componentsSeparatedByString:@":"];
        nameParts = [nameParts subarrayWithRange:NSMakeRange(0, nameParts.count - 1)];
        NSUInteger argCount = MAX(nameParts.count, (MAX(signature.argumentsCount, 2) - 2));
        for (NSUInteger i = 0; i < argCount; ++i)
            [result appendFormat:@"%s%@:(%@)arg%zu",
             i > 0 ? " " : "",
             i < nameParts.count && nameParts[i] ? nameParts[i] : @"",
             methodArgumentString([signature argumentAtIndex:i + 2]) ?: @"",
             i];
        [result appendString:@";"];
    }
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *propertyAttributeString(RDPropertyAttribute *attribute) {
    if (attribute == NULL)
        return nil;
    
    switch (attribute->kind) {
        case RDPropertyAttributeKindReadOnly:
            return @"readonly";
        case RDPropertyAttributeKindCopy:
            return @"copy";
        case RDPropertyAttributeKindRetain:
            return @"retain";
        case RDPropertyAttributeKindNonatomic:
            return @"nonatomic";
        case RDPropertyAttributeKindGetter:
            return [NSString stringWithFormat:@"getter=%@", attribute->value];
        case RDPropertyAttributeKindSetter:
            return [NSString stringWithFormat:@"setter=%@", attribute->value];
        case RDPropertyAttributeKindDynamic:
            return @"dynamic";
        case RDPropertyAttributeKindWeak:
            return @"weak";
        case RDPropertyAttributeKindGarbageCollected:
            return @"gc";
        case RDPropertyAttributeKindLegacyEncoding:
            return @"legacy";
        case RDPropertyAttributeKindIvarName:
            return [NSString stringWithFormat:@"ivar=%@", attribute->value];
    }
}

NSString *propertyString(NSString *name, RDPropertySignature *signature, BOOL isInstanceLevel) {
    NSArray<NSString *> *attributeStrings = map_nn(RDAllPropertyAttributeKinds(), ^NSString *(NSNumber *attribute) {
        return propertyAttributeString([signature attributeWithKind:(RDPropertyAttributeKind)attribute.charValue]);
    });
    
    if (!isInstanceLevel)
        attributeStrings = [attributeStrings arrayByAddingObject:@"class"];
    
    NSString *attributes = attributeStrings.count == 0 ? nil : [NSString stringWithFormat:@"(%@)", [attributeStrings componentsJoinedByString:@", "]];
    
    NSString *typeName = [NSString stringWithFormat:signature.type.format ?: @"%@", name];
    
    return [NSString stringWithFormat:@"@property %@%@;", [attributes stringByAppendingString:@" "] ?: @"", typeName];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
