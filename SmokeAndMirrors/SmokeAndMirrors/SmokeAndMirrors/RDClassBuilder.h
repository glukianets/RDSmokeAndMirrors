#import <Foundation/Foundation.h>
#import "RDCommon.h"
#import "RDType.h"
#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

RD_EXTERN NSErrorDomain const RDClassBuilderErrorDomain;

@interface RDClassBuilder : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, unsafe_unretained, null_resettable) Class super;

- (nullable Class)buildNamed:(NSString *)name error:(NSError *_Nullable *_Nullable)error;
- (Class)buildNamed:(NSString *)name;

- (BOOL)buildUpon:(Class)cls error:(NSError *_Nullable *_Nullable)error;
- (void)buildUpon:(Class)cls;

- (void)addIvarWithName:(NSString *)name type:(RDType *)type;
- (void)addIvarWithName:(NSString *)name type:(RDType *)type retention:(RDRetentionType)retention;

- (void)addMethodWithSelector:(SEL)selector block:(void (^)(void))block;
- (void)addMethodWithSelector:(SEL)selector signature:(RDMethodSignature *)signature implementation:(IMP)implementation;

- (void)addPropertyWithName:(NSString *)name type:(RDType *)type;
- (void)addPropertyWithName:(NSString *)name signature:(RDPropertySignature *)signature;

- (void)addProtocolConformance:(Protocol *)protocol;

@end

NS_ASSUME_NONNULL_END
