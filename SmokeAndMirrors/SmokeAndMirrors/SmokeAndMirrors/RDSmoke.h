#import "RDCommon.h"
#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

RD_FINAL_CLASS
@interface RDSmoke : NSObject

- (RDClass *)mirrorForObjcClass:(Class)cls;
- (RDProtocol *)mirrorForObjcProtocol:(Protocol *)protocol;
- (RDMethod *)mirrorForObjcMethod:(Method)method;
- (RDProperty *)mirrorForObjcProperty:(Property)property;
- (RDIvar *)mirrorForObjcIvar:(Ivar)ivar;
- (RDBlock *)mirrorForObjcBlock:(NS_NOESCAPE id)block;

@end

NS_ASSUME_NONNULL_END
