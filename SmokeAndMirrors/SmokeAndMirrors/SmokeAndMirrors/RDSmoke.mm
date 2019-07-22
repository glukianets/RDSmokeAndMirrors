#import "RDSmoke.h"
#import "RDMirrorPrivate.h"
#import "RDPrivate.h"

#include <unordered_map>

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDObjcOpaqueItem {
@private
    uintptr_t _value;
}

+ (instancetype)itemWithClass:(__unsafe_unretained Class)cls {
    return [[self alloc] initWithPointerValue:(uintptr_t)cls];
}

+ (instancetype)itemWithProtocol:(Protocol *__unsafe_unretained)proto {
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

@interface RDSmoke()
@property (nonatomic, readonly) NSMapTable<RDObjcOpaqueItem *, __kindof RDMirror *> *cache;
@end

@implementation RDSmoke

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (__kindof RDMirror *)mirrorForItem:(RDObjcOpaqueItem *)item
                       valueProducer:(__kindof RDMirror *(NS_NOESCAPE ^)())producer
{
    __kindof RDMirror *mirror = [self.cache objectForKey:item];
    if (mirror != nil) {
        return mirror;
    } else {
        mirror = producer();
        [self.cache setObject:mirror forKey:item];
    }
    return mirror;
}

- (RDClass *)mirrorForObjcClass:(__unsafe_unretained Class)cls {
    if (cls == Nil)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithClass:cls] valueProducer:^RDClass *{
        __unsafe_unretained Class meta = object_getClass(cls);
        __unsafe_unretained Class supr = class_getSuperclass(cls);

        NSString *name = ({
            const char *name = class_getName(cls);
            name == NULL ? nil : [NSString stringWithUTF8String:class_getName(cls)];
        });

        NSString *imageName = ({
            const char *imageName = class_getImageName(cls);
            imageName == NULL ? nil : [NSString stringWithUTF8String:imageName];
        });

        int version = class_getVersion(cls);

        NSArray<RDProtocol *> *protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = class_copyProtocolList(cls, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [self mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });

        NSArray<RDMethod *> *methods = ({
            unsigned count;
            Method *methodList = class_copyMethodList(cls, &count);
            RDMethod *methods[count];
            for (unsigned i = 0; i < count; ++i)
                methods[i] = [self mirrorForObjcMethod:methodList[i]];
            free(methodList);
            [NSArray arrayWithObjects:methods count:count];
        });

        NSArray<RDIvar *> *ivars = ({
            unsigned int count;
            Ivar *ivarList = class_copyIvarList(cls, &count);
            RDIvar *ivars[count];
            for (unsigned i = 0; i < count; ++i)
                ivars[i] = [self mirrorForObjcIvar:ivarList[i]];
            free(ivarList);
            [NSArray arrayWithObjects:ivars count:count];
        });

        NSArray<RDProperty *> *properties = ({
            unsigned int count;
            Property *propertyList = class_copyPropertyList(cls, &count);
            RDProperty *properties[count];
            for (unsigned i = 0; i < count; ++i)
                properties[i] = [self mirrorForObjcProperty:propertyList[i]];
            free(propertyList);
            [NSArray arrayWithObjects:properties count:count];
        });

        return [[RDClass alloc] initWithObjcClass:cls
                                          inSmoke:self withName:name
                                          version:version
                                            image:imageName
                                             supr:supr
                                             meta:meta == cls ? nil : meta
                                        protocols:protocols
                                          methods:methods
                                            ivars:ivars
                                       properties:properties];
    }];
}


- (RDProtocol *)mirrorForObjcProtocol:(Protocol *)protocol {
    if (protocol == nil)
        return nil;
    
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

    return [self mirrorForItem:[RDObjcOpaqueItem itemWithProtocol:protocol] valueProducer:^RDProtocol *{
        NSString *name = ({
            const char *name = protocol_getName(protocol);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        
        NSArray<RDProtocol *> *protocols = ({
            unsigned count;
            Protocol *__unsafe_unretained *protocolList = protocol_copyProtocolList(protocol, &count);
            RDProtocol *protocols[count];
            for (unsigned i = 0; i < count; ++i)
                protocols[i] = [self mirrorForObjcProtocol:protocolList[i]];
            free(protocolList);
            [NSArray arrayWithObjects:protocols count:count];
        });

        if ([excludedProtocolNames containsObject:name])
            return [[RDProtocol alloc] initWithObjcProtocol:protocol
                                                    inSmoke:self
                                                   withName:name
                                                  protocols:protocols
                                                     methos:[NSArray array]
                                                 properties:[NSArray array]];
        
        NSArray<RDProtocolProperty *> *properties = ({
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

        NSArray<RDProtocolMethod *> *methods = ({
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
        
        return [[RDProtocol alloc] initWithObjcProtocol:protocol
                                                inSmoke:self
                                               withName:name
                                              protocols:protocols
                                                 methos:methods
                                             properties:properties];
    }];
}

- (RDMethod *)mirrorForObjcMethod:(Method)method {
    if (method == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithMethod:method] valueProducer:^RDMirror *{
        SEL selector = method_getName(method);
        RDMethodSignature *signature = ({
            RDMethodSignature *signature = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
            NSUInteger argCount = 0;
            for (const char *sel = sel_getName(selector); *sel != '\0'; ++sel)
                if (*sel == ':')
                    ++argCount;

            signature.arguments.count == argCount + 2 ? signature : nil;
        });
        
        return [[RDMethod alloc] initWithObjcMethod:method
                                            inSmoke:self
                                       withSelector:selector
                                       andSignature:signature];
    }];
}

- (RDProperty *)mirrorForObjcProperty:(Property)property {
    if (property == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithProperty:property] valueProducer:^RDMirror *{
        NSString *name = ({
            const char *name = property_getName(property);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        RDPropertySignature *signature = [RDPropertySignature signatureWithObjcTypeEncoding:property_getAttributes(property)];

        return [[RDProperty alloc] initWithProperty:property
                                            inSmoke:self
                                           withName:name
                                       andSignature:signature];
    }];
}

- (RDIvar *)mirrorForObjcIvar:(Ivar)ivar {
    if (ivar == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithIvar:ivar] valueProducer:^__kindof RDMirror *{
        ptrdiff_t offset = ivar_getOffset(ivar);
        NSString *name = ({
            const char *name = ivar_getName(ivar);
            name == NULL ? nil : [NSString stringWithUTF8String:name];
        });
        RDType *type = ({
            RDType *type = nil;
            if (const char *encoding = ivar_getTypeEncoding(ivar); encoding != NULL && *encoding != '\0')
                type = [RDType typeWithObjcTypeEncoding:encoding];
            type;
        });
        
        return [[RDIvar alloc] initWithIvar:ivar
                                    inSmoke:self
                                   withName:name
                                   atOffset:offset
                                   withType:type];
    }];
}

- (RDBlock *)mirrorForObjcBlock:(NS_NOESCAPE id)block {
    if (block == nil)
        return nil;
    
    RDBlockInfo *blockInfo = RDBlockInfoOfBlock(block);
    RDMethodSignature *signature = [RDMethodSignature signatureWithObjcTypeEncoding:RDBlockInfoGetObjCSignature(blockInfo)];
    RDBlockKind kind = RDBlockInfoGetKind(blockInfo);
    
    RDClass *cls = [self mirrorForObjcClass:object_getClass(block)];
    
    return [[RDBlock alloc] initWithKind:kind
                                 inSmoke:self
                                    clss:cls
                                    size:blockInfo->descriptor->size
                               signature:signature];
}

@end
