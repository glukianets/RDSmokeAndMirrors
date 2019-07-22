#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

typedef struct {
    double a, b;
    unsigned long x, y;
} RDDummyStruct;

@interface RDInvocationDummy : NSObject
@property (nonatomic, readonly) XCTestExpectation *expectation;
@end

@implementation RDInvocationDummy

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation {
    self = [super init];
    if (self) {
        _expectation = expectation;
    }
    return self;
}

- (instancetype)init {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"invoke"];
    expectation.assertForOverFulfill = YES;
    return [self initWithExpectation:expectation];
}

- (NSUInteger)unboxNSUInteger:(NSNumber *)arg {
    NSAssert(sel_isEqual(_cmd, @selector(unboxNSUInteger:)), @"Incorrect selector called");
    [self.expectation fulfill];
    return arg.unsignedIntegerValue;
}

- (RDDummyStruct)swapFieldsIn:(RDDummyStruct)strct {
    NSAssert(sel_isEqual(_cmd, @selector(swapFieldsIn:)), @"Incorrect selector called");
    [self.expectation fulfill];
    
    double c = strct.a;
    strct.a = strct.b;
    strct.b = c;
    
    unsigned long z = strct.x;
    strct.x = strct.y;
    strct.y = z;
    
    return strct;
}

@end

@interface RDInvocationTests : XCTestCase
@end

@implementation RDInvocationTests

- (void)testInvocation {
    NSUInteger const cannary = 42;
    
    RDInvocationDummy *dummy = [RDInvocationDummy new];
    RDInvocation *invocation = [RDInvocation invocationWithArguments:RDValueTuple(@(cannary))];
    NSError *error = nil;
    RDValue *value = [invocation invokeWithTarget:dummy selector:@selector(unboxNSUInteger:) error:&error];
    XCTAssertNil(error, @"Should return without error");
    XCTAssertNotNil(value, @"Should return value");
    NSUInteger result;
    XCTAssertTrue(RDValueGet(value, &result));
    XCTAssertEqual(result, cannary, @"Cannary returned massacred");
    [self waitForExpectations:@[dummy.expectation] timeout:0];
}

- (void)testInvocationStret {
    RDDummyStruct const cannary = { .a=10, .b=20, .x=30, .y=40 };
    
    RDInvocationDummy *dummy = [RDInvocationDummy new];
    RDInvocation *invocation = [RDInvocation invocationWithArguments:RDValueTuple(cannary)];
    NSError *error = nil;
    RDValue *value = [invocation invokeWithTarget:dummy selector:@selector(swapFieldsIn:) error:&error];
    XCTAssertNil(error, @"Should return without error");
    XCTAssertNotNil(value, @"Should return value");
    RDDummyStruct result;
    XCTAssertTrue(RDValueGet(value, &result));
    XCTAssertEqual(result.a, 20, @"Result returned corrupted");
    XCTAssertEqual(result.b, 10, @"Result returned corrupted");
    XCTAssertEqual(result.x, 40, @"Result returned corrupted");
    XCTAssertEqual(result.y, 30, @"Result returned corrupted");
    [self waitForExpectations:@[dummy.expectation] timeout:0];
}

@end
