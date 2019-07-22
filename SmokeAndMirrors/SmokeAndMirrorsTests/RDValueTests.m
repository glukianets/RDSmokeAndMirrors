#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

@interface RDValueTests : XCTestCase

@end

@implementation RDValueTests

- (void)testClusterCounters {
    for (NSUInteger i = 0; i < 100; ++i) {
        RDValue *value = [RDValue alloc];
        XCTAssertEqual(CFGetRetainCount((__bridge CFTypeRef)value), 2, @"Should be 2");
        if (i % 2 == 0)
            value = [value initWithBytes:&i objCType:@encode(typeof(i))];
        else
            value = [value init];
        XCTAssertEqual(CFGetRetainCount((__bridge CFTypeRef)value), i % 2 + 1, @"Should be either 1 for [initWithBytes:objCType] or 2 for [init]");
    }
}

- (void)test {
    NSString *cannary1 = [NSString stringWithFormat:@"Red can%@!", @"nary"];
    NSString *cannary2 = [NSString stringWithFormat:@"Blue can%@!", @"nary"];
    NSString *cannary3 = [NSString stringWithFormat:@"Lying can%@!", @"nary"];

    struct T { id obj; char tag[4]; };
    struct T t = {.obj=cannary1, .tag="sup"};
    
    RDValue *value = RDValueBox(t);
    XCTAssertNotNil(value, @"Should create");
    XCTAssertEqual(value, value.copy, @"Should elide copy");
    
    NSLog(@"%@\n\n%@", value.debugDescription, value);
    
    NSString *c1 = nil;
    RDValueGet(value[0], &c1);
    XCTAssertEqual(c1, cannary1, @"Should extract value by index");
    c1 = nil;
    RDValueGetAt(value, 0, &c1);
    XCTAssertEqual(c1, cannary1, @"Should extract bytes by index");

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
