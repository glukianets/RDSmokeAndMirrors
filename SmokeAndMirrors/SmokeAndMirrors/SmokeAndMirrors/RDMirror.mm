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
@end

@implementation RDClass
@synthesize super = _super;
@synthesize meta = _meta;

- (instancetype)initWithObjcClass:(Class)cls
                          inSmoke:(RDSmoke *)smoke
                         withName:(NSString *)name
                          version:(int)version
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
        _imageName = image.copy;
        _protocols = protocols.copy;
        _methods = methods.copy;
        _ivars = ivars.copy;
        _properties = properties.copy;
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
        if (self.objcMeta == Nil)
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
@property (nonatomic, readonly) RDPropertySignature *signature;
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

- (instancetype)initWithObjcProtocol:(Protocol *)protocol
                             inSmoke:(RDSmoke *)smoke
                            withName:(NSString *)name
                           protocols:(NSArray<RDProtocol *> *)protocols
                              methos:(NSArray<RDProtocolMethod *> *)methods
                          properties:(NSArray<RDProtocolProperty *> *)properties
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _protocol = protocol;
        _name = name.copy;
        _protocols = protocols.copy;
        _methods = methods.copy;
        _properties = properties.copy;
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

- (instancetype)initWithObjcMethod:(Method)method
                           inSmoke:(RDSmoke *)smoke
                      withSelector:(SEL)selector
                      andSignature:(RDMethodSignature *)signature
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _method = method;
        _selector = selector;
        _signature = signature;
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

- (instancetype)initWithProperty:(Property)property
                         inSmoke:(RDSmoke *)smoke
                        withName:(NSString *)name
                    andSignature:(RDPropertySignature *)signature
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _property = property;
        _name = name.copy;
        _signature = signature;
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

- (instancetype)initWithIvar:(Ivar)ivar
                     inSmoke:(RDSmoke *)smoke
                    withName:(NSString *)name
                    atOffset:(ptrdiff_t)offset
                    withType:(RDType *)type
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _ivar = ivar;
        _name = name.copy;
        _offset = offset;
        _type = type;
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

@interface RDBlock()

@property (nonatomic, readonly) RDBlockKind kind;

@end

@implementation RDBlock

- (instancetype)initWithKind:(RDBlockKind)kind
                     inSmoke:(RDSmoke *)smoke
                        clss:(RDClass *)clss
                        size:(size_t)size
                   signature:(RDMethodSignature *)signature
{
    self = [super initWithSmoke:smoke];
    if (self) {
        _kind = kind;
        _clss = clss;
        _size = size;
        _signature = signature;
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

NSString *blockString(NSString *name, RDMethodSignature *signature) {
    NSString *returnType = signature.returnValue.description ?: @"";
    NSString *body = ({
        NSString *arguments = [map_nn(signature.arguments, ^NSString *(RDMethodArgument *arg) {
            return arg.description ?: nil;
        }) componentsJoinedByString:@", "];
        [NSString stringWithFormat:@"(%@)", arguments];
    });
    return [NSString stringWithFormat:@"^%@%@;", returnType, body];
}

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
                NSString *argdesc = argument.description ?: @"";
                return [name stringByAppendingFormat:@":%@arg%d", argdesc, 1];
            }, nameParts, arguments) componentsJoinedByString:@" "];
        }
        body;
    });
    return [NSString stringWithFormat:@"%c %@%@;", isInstanceLevel ? '-' : '+' , returnType, body];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
