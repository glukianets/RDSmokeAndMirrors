#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDClass()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcClass:(Class)cls
                          inSmoke:(RDSmoke *)smoke
                         withName:(NSString *)name
                          version:(int)version
                            image:(NSString *)image
                             supr:(nullable Class)supr
                             meta:(Class)meta
                        protocols:(NSArray<RDProtocol *> *)protocols
                          methods:(NSArray<RDMethod *> *)methods
                            ivars:(NSArray<RDIvar *> *)ivars
                       properties:(NSArray<RDProperty *> *)properties NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocolMethod()
- (instancetype)initWithObjcCounterpart:(MethodDescription)method
                               required:(BOOL)required
                             classLevel:(BOOL)classLevel;
@end

@interface RDProtocolProperty()
- (instancetype)initWithObjcCounterpart:(Property)property
                               required:(BOOL)required
                             classLevel:(BOOL)classLevel;
@end

@interface RDProtocol()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcProtocol:(Protocol *)protocol
                             inSmoke:(RDSmoke *)smoke
                            withName:(NSString *)name
                           protocols:(NSArray<RDProtocol *> *)protocols
                              methos:(NSArray<RDProtocolMethod *> *)methods
                          properties:(NSArray<RDProtocolProperty *> *)properties NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethod()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcMethod:(Method)method
                           inSmoke:(RDSmoke *)smoke
                      withSelector:(SEL)selector
                      andSignature:(RDMethodSignature *)signature NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProperty()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithProperty:(Property)property
                         inSmoke:(RDSmoke *)smoke
                        withName:(NSString *)name
                    andSignature:(RDPropertySignature *)signature NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDIvar()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithIvar:(Ivar)ivar
                     inSmoke:(RDSmoke *)smoke
                    withName:(NSString *)name
                    atOffset:(ptrdiff_t)offset
                    withType:(RDType *)type NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END
