#import "RDClassBuilder.h"
#import "RDPrivate.h"
#import "RDSmoke.h"
#import <unordered_map>

#define VALUE(VALUE) (void)(error != NULL && (*error = nil)), (VALUE)
#define ERROR(VALUE, CODE) (void)(error != NULL && (*error = (CODE))), (VALUE)
#define ECODE(VALUE, CODE) (void)(error != NULL && (*error = [NSError errorWithDomain:RDClassBuilderErrorDomain code:(CODE) userInfo:nil])), (VALUE)

NSErrorDomain const RDClassBuilderErrorDomain = @"RDClassBuilderErrorDomain";
NSInteger const RDClassBuilderInvalidNameCode = 257;
NSInteger const RDClassBuilderInvalidArgumentCode = 258;
NSInteger const RDClassBuilderReflectionErrorCode = 259;

@interface RDCBIvar : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) RDType *type;
@property (nonatomic) RDRetentionType retention;
@end

@implementation RDCBIvar
@end

@interface RDCBMethod : NSObject
@property (nonatomic) SEL selector;
@property (nonatomic) RDMethodSignature *signature;
@property (nonatomic) IMP implementation;
@property (nonatomic) void (^block)(void);
@end

@implementation RDCBMethod : NSObject
@end

@interface RDCBProperty : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) RDType *type;
@property (nonatomic, copy) RDPropertySignature *signature;
@end

@implementation RDCBProperty : NSObject
@end

@interface RDCBProtocol : NSObject
@property (nonatomic) Protocol *protocol;
@end

@implementation RDCBProtocol
@end

@interface RDClassBuilder()
@property (nonatomic, readonly) NSMutableDictionary<NSString *, RDCBIvar *> *ivars;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, RDCBMethod *> *methods;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, RDCBProperty *> *properties;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, RDCBProtocol *> *protocols;
@end

@implementation RDClassBuilder

+ (instancetype)buildNamed:(NSString *)name {
    return [[self alloc] initWithName:name];
}

- (instancetype)initWithName:(NSString *)name {
    NSParameterAssert(name);
    self = [super init];
    if (self) {
        _name = name.copy;
        _super = NSObject.self;
    }
    return self;
}

- (void)addIvarWithName:(NSString *)name type:(RDType *)type {
    return [self addIvarWithName:name type:type retention:type._defaultRetention];
}

- (void)addIvarWithName:(NSString *)name type:(RDType *)type retention:(RDRetentionType)retention {
    NSParameterAssert(name);
    NSParameterAssert(type);
    self.ivars[name] = ({
        RDCBIvar *ivar = [RDCBIvar new];
        ivar.name = name.copy;
        ivar.type = type;
        ivar.retention = retention;
        ivar;
    });
}

- (void)addMethodWithSelector:(SEL)selector block:(void (^)(void))block {
    NSParameterAssert(selector);
    NSParameterAssert(block);
    self.methods[[NSString stringWithUTF8String:sel_getName(selector)]] = ({
        RDCBMethod *method = [RDCBMethod new];
        method.selector = selector;
        method.block = block;
        method;
    });
}

- (void)addMethodWithSelector:(SEL)selector signature:(RDMethodSignature *)signature implementation:(IMP)implementation {
    NSParameterAssert(selector);
    NSParameterAssert(signature);
    NSParameterAssert(implementation);
    self.methods[[NSString stringWithUTF8String:sel_getName(selector)]] = ({
        RDCBMethod *method = [RDCBMethod new];
        method.selector = selector;
        method.signature = signature;
        method.implementation = implementation;
        method;
    });
}

- (void)addPropertyWithName:(NSString *)name type:(RDType *)type {
}

- (void)addPropertyWithName:(NSString *)name signature:(RDPropertySignature *)signature {
    NSParameterAssert(name);
    NSParameterAssert(signature);
    self.properties[name] = ({
        RDCBProperty *property = [RDCBProperty new];
        property.name = name;
        property.signature = signature;
        property;
    });
}

- (void)addProtocolConformance:(Protocol *)protocol {
    NSParameterAssert(protocol);
    self.protocols[[NSString stringWithUTF8String:protocol_getName(protocol)]] = ({
        RDCBProtocol *proto = [RDCBProtocol new];
        proto.protocol = protocol;
        proto;
    });
}

- (void)setSuper:(Class)cls {
    _super = cls ?: NSObject.self;
}

- (Class)buildNamed:(NSString *)name {
    NSError *error = nil;
    __unsafe_unretained Class result = [self buildNamed:name error:&error];
    if (result == nil || error != nil)
        @throw [NSException exceptionWithName:@"RDClassBuildingException"
                                       reason:error.description
                                     userInfo:error == nil ? nil : @{ NSUnderlyingErrorKey: error }];
    else
        return result;
}

- (nullable Class)buildNamed:(NSString *)name error:(NSError *_Nullable *_Nullable)error {
    if (name.length == 0)
        return ECODE(Nil, RDClassBuilderInvalidNameCode);
    
    __unsafe_unretained Class cls = objc_allocateClassPair(self.superclass, name.UTF8String, 0);

    if (NSError *err = nil; (void)[self _buildClass:cls error:&err], err == nil) {
        objc_registerClassPair(cls);
        return VALUE(cls);
    } else {
        objc_disposeClassPair(cls);
        return ERROR(Nil, err);
    }
}

- (void)buildUpon:(Class)cls {
    NSError *error = nil;
    [self buildUpon:cls error:&error];
    if (cls == nil || error != nil)
        @throw [NSException exceptionWithName:@"RDClassBuildingException"
                                       reason:error.description
                                     userInfo:error == nil ? nil : @{ NSUnderlyingErrorKey: error }];
}

- (void)buildUpon:(Class)cls error:(NSError *_Nullable *_Nullable)error {
    [self _buildClass:cls error:error];
}

- (Class)_buildClass:(nullable Class)cls error:(NSError *_Nullable *_Nullable)error {
    if (cls == Nil)
        return ECODE(Nil, RDClassBuilderInvalidArgumentCode);
    
    RDSmoke *smoke = [RDSmoke currentThreadSmoke];
    RDClass *mirror = [smoke mirrorForObjcClass:self.superclass];
    if (mirror == nil)
        return ECODE(Nil, RDClassBuilderReflectionErrorCode);
    
    for (RDIvar *ivar in self.ivars) {
        RDType *type = ivar.type;
        size_t size = type.size;
        size_t alignment = type.alignment;
        const char *encoding = type.objCTypeEncoding;
        class_addIvar(cls, ivar.name.UTF8String, size, alignment, encoding);
    }
        
    return VALUE(Nil);
}

@end
