#import <XCTest/XCTest.h>


@interface CocoaExampleTests : XCTestCase

@property (strong, nonatomic) NSApplication* app;

@end

@implementation CocoaExampleTests

- (void)setUp
{
    [super setUp];
    self.app = [NSApplication sharedApplication];

}

- (void)testExample {
    XCTAssert(YES, @"Pass");
}

- (void)testExample2 {
    XCTAssert(YES, @"Pass");
}

- (void)testExample3 {
    XCTAssert(YES, @"Pass");
}

- (void) tearDown {
    //[[self.app delegate] applicationShouldTerminate:self.app];
    [super tearDown];
}

@end
