#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

@interface SmokeAndMirrorsTests : XCTestCase

@end

@implementation SmokeAndMirrorsTests

- (void)setUp { }

- (void)tearDown { }

- (void)testParseRuntimeClasses {
    RDSmoke *smoke = [RDSmoke new];
    [self measureBlock:^{
        unsigned count = 0;
        Class *classlist = objc_copyClassList(&count);
        for (unsigned i = 0; i < count; ++i) {
            @autoreleasepool {
                XCTAssertNotNil([smoke mirrorForObjcClass:classlist[i]]);
            }
        }
        free(classlist);
    }];
}

- (void)testParseRuntimeProtocols {
    RDSmoke *smoke = [RDSmoke new];
    [self measureBlock:^{
        unsigned count = 0;
        Protocol *__unsafe_unretained *protocolList = objc_copyProtocolList(&count);
        for (unsigned i = 0; i < count; ++i) {
            @autoreleasepool {
                XCTAssertNotNil([smoke mirrorForObjcProtocol:protocolList[i]]);
            }
        }
        free(protocolList);
    }];
}

- (void)test {
    RDSmoke *smoke = [RDSmoke new];
    //object_getClass(^{ NSLog(@"%p", self); })
    RDBlock *cls = [smoke mirrorForObjcBlock:[^id (id _){ return nil; } copy]];
    NSLog(@"%@", cls);
}

@end
