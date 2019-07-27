#import "RDPrivate.h"

NS_ASSUME_NONNULL_BEGIN

RD_EXTERN id _Nullable objc_autorelease(id _Nullable value);
RD_EXTERN void objc_autoreleasePoolPop(void *pool);
RD_EXTERN void *objc_autoreleasePoolPush(void);
RD_EXTERN id _Nullable objc_autoreleaseReturnValue(id _Nullable value);
RD_EXTERN void objc_copyWeak(id _Nullable *_Nonnull dest, id _Nullable *_Nonnull src);
RD_EXTERN void objc_destroyWeak(id _Nullable *_Nonnull object);
RD_EXTERN id objc_initWeak(id _Nullable *_Nonnull object, id _Nullable value);
RD_EXTERN id _Nullable objc_loadWeak(id _Nullable *_Nonnull object);
RD_EXTERN id _Nullable objc_loadWeakRetained(id _Nullable *_Nonnull object);
RD_EXTERN void objc_moveWeak(id _Nullable *_Nonnull dest, id _Nullable *_Nonnull src);
RD_EXTERN void objc_release(id _Nullable value);
RD_EXTERN id _Nullable objc_retain(id _Nullable value);
RD_EXTERN id _Nullable objc_retainAutorelease(id _Nullable value);
RD_EXTERN id _Nullable objc_retainAutoreleaseReturnValue(id _Nullable value);
RD_EXTERN id _Nullable objc_retainAutoreleasedReturnValue(id _Nullable value);
RD_EXTERN id _Nullable objc_retainBlock(id _Nullable value);
RD_EXTERN void objc_storeStrong(id _Nullable *_Nonnull object, id _Nullable value);
RD_EXTERN id objc_storeWeak(id _Nullable *_Nonnull object, id _Nullable value);

NS_ASSUME_NONNULL_END
