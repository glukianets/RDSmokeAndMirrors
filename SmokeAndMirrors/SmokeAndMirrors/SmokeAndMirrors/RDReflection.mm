#import "RDReflection.h"

@implementation RDReflection

- (instancetype)initWithObject:(id)object {
    return [self initWithObject:object usingSmoke:nil];
}

- (instancetype)initWithObject:(id)object usingSmoke:(RDSmoke *)smoke {
    self = [super init];
    if (self) {
        _object = object;
    }
    return self;
}

- (id)objectAtKeyedSubscribt:(NSString *)ivarName {
    return nil;
}

@end
