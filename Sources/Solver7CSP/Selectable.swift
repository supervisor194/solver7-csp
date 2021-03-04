import Foundation


public protocol Selectable {

    func getId() -> String

    func isEnableable() -> Bool
    func setEnableable(_ b: Bool) -> Void

    func hasData() -> Bool

    func setHandler(_ handler: @escaping () -> Void) -> Void

    func handle() -> Void

    func setSelector(_ selector: Selector?) -> Void
    // func getSelector() -> Selector?

    func enable(_ selector: Selector) -> Bool

    func disable() -> Bool
}

