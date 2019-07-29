#import <Foundation/Foundation.h>
#import <RDType.h>
#import <ffi/ffi.h>
#import "RDMirror.h"

NS_ASSUME_NONNULL_BEGIN

@interface RDType(RDPrivate)

- (void)_value_retainBytes:(void *)bytes;
- (void)_value_releaseBytes:(void *)bytes;
- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(nullable NSMutableArray<NSString *> *)info;
- (NSString *)_value_formatWithBytes:(void *)bytes;
- (ffi_type *_Nullable)_ffi_type;
+ (void)_ffi_type_destroy:(ffi_type *)type;
- (RDRetentionType)_defaultRetention;

@end

NS_ASSUME_NONNULL_END
