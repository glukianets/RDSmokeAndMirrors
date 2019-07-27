#import "RDMirror.h"
#import "RDPrivate.h"

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDClass()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcClass:(__unsafe_unretained Class)cls inSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;

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
- (instancetype)initWithObjcProtocol:(Protocol *)protocol inSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethod()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcMethod:(Method)method inSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProperty()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcProperty:(Property)property inSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDIvar()

@property (nonatomic, readwrite) RDRetentionType retention;

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithObjcIvar:(Ivar)ivar inSmoke:(RDSmoke *)smoke NS_DESIGNATED_INITIALIZER;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBlock()

- (instancetype)initWithSmoke:(RDSmoke *)smoke NS_UNAVAILABLE;
- (instancetype)initWithBlockInfo:(RDBlockInfo *)info inSmoke:(RDSmoke *)smoke;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END
