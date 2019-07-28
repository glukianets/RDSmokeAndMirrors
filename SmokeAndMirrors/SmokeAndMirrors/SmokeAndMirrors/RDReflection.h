#import "RDCommon.h"
#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

RD_FINAL_CLASS
@interface RDReflection<Type> : NSObject

@property (nonatomic, readonly) RDClass *mirror;
@property (nonatomic, readonly) RDSmoke *smoke;
@property (nonatomic, readonly) Type object;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithObject:(Type)object;
- (instancetype)initWithObject:(Type)object usingSmoke:(nullable RDSmoke *)smoke;

- (nullable id)objectAtKeyedSubscribt:(NSString *)ivarName;

@end

@interface NSObject(RDReflection)

@property (nonatomic, readonly) RDReflection<NSObject *> *rd_reflect;

@end

RD_EXTERN RDReflection *_Nullable RDReflect(_Nullable id object);
RD_EXTERN RDReflection *_Nullable RDReflectAddress(uintptr_t address);

NS_ASSUME_NONNULL_END
