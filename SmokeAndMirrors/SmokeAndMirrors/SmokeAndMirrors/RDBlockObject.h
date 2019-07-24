#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDBlockObject : NSObject<NSCopying>

@property (nonatomic, readonly, class) SEL selectorForCalling;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCFunctionPointer:(void (*_Nonnull)(id /*self*/, ...))fptr;

@end

NS_ASSUME_NONNULL_END
