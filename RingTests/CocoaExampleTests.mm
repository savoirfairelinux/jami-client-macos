#import <XCTest/XCTest.h>

@interface CocoaExampleTests : XCTestCase

@end

@implementation CocoaExampleTests


- (void) setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    [[[XCUIApplication alloc] init] launch];
}

- (void)testExample {
    XCTAssert(YES, @"Pass");
    
}

@end
