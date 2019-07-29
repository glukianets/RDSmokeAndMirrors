#import <Foundation/Foundation.h>
#import "RDCommon.h"
#import "RDType.h"
#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

@interface RDClassBuilder : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, unsafe_unretained, null_resettable) Class super;

+ (instancetype)buildNamed:(NSString *)name;
- (instancetype)initWithName:(NSString *)name;

- (nullable Class)buildError:(NSError *_Nullable *_Nullable)error;
- (Class)build;

- (void)addIvarWithName:(NSString *)name type:(RDType *)type;
- (void)addIvarWithName:(NSString *)name type:(RDType *)type retention:(RDRetentionType)retention;

- (void)addMethodWithSelector:(SEL)selector block:(void (^)(void))block;
- (void)addMethodWithSelector:(SEL)selector signature:(RDMethodSignature *)signature implementation:(IMP)implementation;

- (void)addPropertyWithName:(NSString *)name type:(RDType *)type;
- (void)addPropertyWithName:(NSString *)name type:(RDType *)type attributes:(NSArray<RDPropertyAttribute *> *)attributes;

- (void)addProtocolConformance:(Protocol *)protocol;

@end

NS_ASSUME_NONNULL_END
