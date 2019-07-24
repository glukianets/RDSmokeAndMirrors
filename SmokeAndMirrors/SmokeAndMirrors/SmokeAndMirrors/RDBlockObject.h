#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDBlockObject : NSObject

@property (nonatomic, readonly, class) SEL selectorForCalling;
@property (nonatomic, readonly) void (^asBlock)(void);

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCFunctionPointer:(void (*_Nonnull)(id /*self*/, ...))fptr;

@end

NS_ASSUME_NONNULL_END
