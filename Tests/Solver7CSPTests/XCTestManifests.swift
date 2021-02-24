import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(Solver7CSPTests.allTests),
        testCase(LinkedListQueueTests.allTests),
        testCase(NonSelectableChannelTests.allTests),
        testCase(LockTests.allTests),
        testCase(TimeoutTests.allTests),
        testCase(CDLLTests.allTests),

    ]
}
#endif
