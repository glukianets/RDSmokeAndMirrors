#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#define RD_FINAL_CLASS __attribute__((objc_subclassing_restricted))

#define RD_RETURNS_RETAINED __attribute__((ns_returns_retained))
#define RD_RETURNS_UNRETAINED __attribute__((ns_returns_not_retained))
#define RD_RETURNS_AUTORELEASED __attribute__((ns_returns_autoreleased))

NS_ASSUME_NONNULL_END
