#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDBlockObject : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCFunctionPointer:(void (*_Nonnull)(id /*self*/, ...))fptr;

@end

NS_ASSUME_NONNULL_END
