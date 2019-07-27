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

+ (instancetype)itemWithPointer:(void *)ptr {
    return [[self alloc] initWithPointerValue:(uintptr_t)ptr];
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
        return [[RDClass alloc] initWithObjcClass:cls inSmoke:self];
    }];
}


- (RDProtocol *)mirrorForObjcProtocol:(Protocol *)protocol {
    if (protocol == nil)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithProtocol:protocol] valueProducer:^RDProtocol *{
        return [[RDProtocol alloc] initWithObjcProtocol:protocol inSmoke:self];
    }];
}

- (RDMethod *)mirrorForObjcMethod:(Method)method {
    if (method == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithMethod:method] valueProducer:^RDMirror *{
        return [[RDMethod alloc] initWithObjcMethod:method inSmoke:self];
    }];
}

- (RDProperty *)mirrorForObjcProperty:(Property)property {
    if (property == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithProperty:property] valueProducer:^RDMirror *{
        return [[RDProperty alloc] initWithObjCProperty:property inSmoke:self];
    }];
}

- (RDIvar *)mirrorForObjcIvar:(Ivar)ivar {
    if (ivar == NULL)
        return nil;
    
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithIvar:ivar] valueProducer:^__kindof RDMirror *{
        return [[RDIvar alloc] initWithObjCIvar:ivar inSmoke:self];
    }];
}

- (RDBlock *)mirrorForObjcBlock:(NS_NOESCAPE id)block {
    if (block == nil)
        return nil;
    
    RDBlockInfo *blockInfo = RDGetBlockInfo(block);
    return [self mirrorForItem:[RDObjcOpaqueItem itemWithPointer:blockInfo->descriptor] valueProducer:^RDMirror *{
        return [[RDBlock alloc] initWithBlockInfo:blockInfo inSmoke:self];
    }];
}

@end
