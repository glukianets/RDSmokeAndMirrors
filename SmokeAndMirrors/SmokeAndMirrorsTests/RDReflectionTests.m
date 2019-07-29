#import <XCTest/XCTest.h>
#import <SmokeAndMirrors/SmokeAndMirrors.h>

@interface RDReflectionTests : XCTestCase

@property (nonatomic) RDSmoke *smoke;

@end

@implementation RDReflectionTests

- (void)setUp {
    self.smoke = [RDSmoke new];
}

- (void)tearDown {
    self.smoke = nil;
}

- (void)test {
    RDReflection *reflection = [[self.smoke mirrorForObjcClass:RDReflection.self] rd_reflect];
//    RDReflection *reflection = [^{} rd_reflect];
//    NSLog(@"%@", reflection.debugDescription);
}

@end
