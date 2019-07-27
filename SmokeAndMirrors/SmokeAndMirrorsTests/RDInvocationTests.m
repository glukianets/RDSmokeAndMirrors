#import <XCTest/XCTest.h>

#import "SmokeAndMirrors.h"

typedef struct {
    double a, b;
    unsigned long x, y;
} RDDummyStruct;

@interface RDInvocationDummy : RDBlockObject
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

+ (SEL)selectorForCalling {
    return @selector(invokeWithItem:);
}

- (void)invokeWithItem:(id)item {
    NSLog(@"%@", item);
    [self.expectation fulfill];
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

const char *_Block_dump(id block);

- (void)testBlockject {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"invoke"];
    void (^block)(id) = nil;
    RDInvocationDummy *dummy = [[RDInvocationDummy alloc] initWithExpectation:expectation];
    block = (id)[dummy asBlock];
    dummy = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        block(@"BATMAN!");
    });
    block = nil;
    [self waitForExpectations:@[expectation] timeout:2];
}

@end
