#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

@interface SmokeAndMirrorsTests : XCTestCase
@end

@implementation SmokeAndMirrorsTests

- (void)testParseRuntimeClasses {
    RDSmoke *smoke = [RDSmoke new];
    unsigned count = 0;
    Class *classlist = objc_copyClassList(&count);
    for (unsigned i = 0; i < count; ++i) {
        @autoreleasepool {
            RDClass *mirror = [smoke mirrorForObjcClass:classlist[i]];
            XCTAssertNotNil(mirror);
            printf("\n\n%s\n\n", mirror.description.UTF8String);
        }
    }
    free(classlist);
}

- (void)testParseRuntimeProtocols {
    RDSmoke *smoke = [RDSmoke new];
    unsigned count = 0;
    Protocol *__unsafe_unretained *protocolList = objc_copyProtocolList(&count);
    for (unsigned i = 0; i < count; ++i) {
        @autoreleasepool {
            RDProtocol *mirror = [smoke mirrorForObjcProtocol:protocolList[i]];
            XCTAssertNotNil(mirror);
            printf("\n\n%s\n\n", mirror.description.UTF8String);
        }
    }
    free(protocolList);
}

@end
