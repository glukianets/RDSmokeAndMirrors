#import <XCTest/XCTest.h>
#import <SmokeAndMirrors/SmokeAndMirrors.h>

@interface RDClassBuilderTests : XCTestCase

@end

@implementation RDClassBuilderTests

- (void)test {
    __unsafe_unretained Class cls1 = objc_allocateClassPair(NSObject.self, "test", 0);
    XCTAssertNotNil(cls1);
    __unsafe_unretained Class cls2 = objc_allocateClassPair(NSObject.self, "test", 0);
    XCTAssertNotNil(cls2);
    objc_registerClassPair(cls1);
    objc_registerClassPair(cls1);

//    RDClassBuilder *builder = [RDClassBuilder buildNamed:@"Test"];
//    XCTAssertNotNil(builder);
//
//    __unsafe_unretained Class cls = [builder build];
//    XCTAssertNotNil(cls);
}

@end
