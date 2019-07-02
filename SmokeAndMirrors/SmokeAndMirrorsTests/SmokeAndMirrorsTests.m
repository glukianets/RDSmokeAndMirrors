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

- (void)testValue {
    NSString *cannary1 = [NSString stringWithFormat:@"Red can%@!", @"nary"];
    NSString *cannary2 = [NSString stringWithFormat:@"Blue can%@!", @"nary"];
    NSString *cannary3 = [NSString stringWithFormat:@"Lying can%@!", @"nary"];

    struct T { id obj; char tag[4]; };
    struct T t = {.obj=cannary1, .tag="sup"};
    
    for (NSUInteger i = 0; i < 100; ++i) {
        RDValue *value = [RDValue alloc];
        NSLog(@"+%p - %ld", value, CFGetRetainCount((__bridge CFTypeRef)value));
        if (i % 2 == 0)
            value = [value initWithBytes:&t objCType:@encode(struct T)];
        else
            value = [value init];
        NSLog(@"-%p - %ld", value, CFGetRetainCount((__bridge CFTypeRef)value));
    }

    RDValue *value = RDValueBox(t);
    XCTAssertNotNil(value, @"Should create");
    XCTAssertEqual(value, value.copy, @"Should elide copy");
    
    NSLog(@"%@\n\n%@", value.debugDescription, value);
    
    NSString *c1 = nil;
    RDValueGet(value[0], &c1);
    XCTAssertEqual(c1, cannary1, @"Should extract value by index");
    
    RDMutableValue *mvalue = [value mutableCopy];
    XCTAssertNotNil(mvalue, @"Should mutable copy");

    t.obj = nil;
    XCTAssert(RDValueGet(value, &t), @"Should get");
    XCTAssertEqual(t.obj, cannary1, @"Should preserve value");

    t.obj = cannary2;
    XCTAssert(RDValueSet(mvalue, t), @"Should set");

    t.obj = cannary3;
    XCTAssert(RDValueGet(mvalue, &t), @"Should get");
    XCTAssertEqual(t.obj, cannary2, @"Should preserve value");
    
    value = nil;
    mvalue = nil;
}

@end
