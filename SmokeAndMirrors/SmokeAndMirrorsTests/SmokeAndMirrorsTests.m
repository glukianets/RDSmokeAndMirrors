#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

@interface SmokeAndMirrorsTests : XCTestCase

@end

@implementation SmokeAndMirrorsTests

- (void)setUp { }

- (void)tearDown { }

- (void)testParseRuntimeClasses {
    [self measureBlock:^{
        unsigned count = 0;
        Class *classlist = objc_copyClassList(&count);
        for (unsigned i = 0; i < count; ++i) {
            @autoreleasepool {
                XCTAssertNotNil([RDClass mirrorForObjcClass:classlist[i]]);
            }
        }
        free(classlist);
    }];
}

- (void)testParseRuntimeProtocols {
    [self measureBlock:^{
        unsigned count = 0;
        Protocol *__unsafe_unretained *protocolList = objc_copyProtocolList(&count);
        for (unsigned i = 0; i < count; ++i) {
            @autoreleasepool {
                XCTAssertNotNil([RDProtocol mirrorForObjcProtocol:protocolList[i]]);
            }
        }
        free(protocolList);
    }];
}

@end
