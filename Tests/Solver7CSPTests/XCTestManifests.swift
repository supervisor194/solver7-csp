import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(PipelineTests.allTests),
        testCase(CircularDoubleLinkedListTests.allTests),
        testCase(LatchTests.allTests),
        testCase(LinkedListQueueTests.allTests),
        testCase(LockTests.allTests),
        testCase(NonSelectableChannelTests.allTests),
        testCase(SelectableChannelTests.allTests),
        testCase(SemaphoreTests.allTests),
        testCase(TimeoutTests.allTests),

    ]
}
#endif
