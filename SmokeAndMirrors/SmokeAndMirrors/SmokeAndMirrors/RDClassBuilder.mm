#import "RDClassBuilder.h"
#import "RDPrivate.h"
#import <unordered_map>

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
@property (nonatomic, copy) NSArray<RDPropertyAttribute *> *attributes;
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
    [self addPropertyWithName:name type:type attributes:@[]];
}

- (void)addPropertyWithName:(NSString *)name type:(RDType *)type attributes:(NSArray<RDPropertyAttribute *> *)attributes {
    NSParameterAssert(name);
    NSParameterAssert(type);
    NSParameterAssert(attributes);
    self.properties[name] = ({
        RDCBProperty *property = [RDCBProperty new];
        property.name = name;
        property.type = type;
        property.attributes = attributes.copy;
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

- (Class)build {
    NSError *error = nil;
    __unsafe_unretained Class result = [self buildError:&error];
    if (result == nil || error != nil)
        @throw [NSException exceptionWithName:@"RDClassBuildingException"
                                       reason:error.description
                                     userInfo:error == nil ? nil : @{ NSUnderlyingErrorKey: error }];
    else
        return result;
}

- (nullable Class)buildError:(NSError *_Nullable *_Nullable)error {
    return nil;
}

@end
