import XCTest
@testable import Solver7CSP

import Foundation

class CircularDoubleLinkedListTests: XCTestCase {

    func testOne() {
        let c = CircularDoubleLinkedList<String>()
        let n1 = c.add("howdy doody")
        XCTAssertEqual("howdy doody", n1.getValue())
        c.remove(n1)
        XCTAssertEqual(0, c.size)
    }

    func testMany() {
        let c = CircularDoubleLinkedList<String>()
        for i in 1...100 {
            c.add("howdy doody \(i)")
        }
        XCTAssertEqual(100, c.size)

        func f(node: CDLLNode<String>) -> CDLLNode<String>? {
            if node.value == "howdy doody 77" {
                return node
            }
            return nil
        }
        let found = c.find(finder: f)
        XCTAssertEqual("howdy doody 77", found?.value)
        c.remove(found!)
        XCTAssertEqual(99, c.size)

        var cnt = 0

        func f2(node: CDLLNode<String>) -> CDLLNode<String>? {
            cnt += 1
            if node.value == "howdy doody 88" {
                return node
            }
            return nil
        }
        let found2 = c.find(finder: f2)
        XCTAssertEqual("howdy doody 88", found2?.value)
        XCTAssertEqual(87, cnt)

        cnt = 0
        c.find(beginAt: found2?.next, finder: f2)
        XCTAssertEqual(99, cnt)

    }

    static var allTests = [
        ("testOne", testOne),
        ("testMany", testMany),
    ]
}
