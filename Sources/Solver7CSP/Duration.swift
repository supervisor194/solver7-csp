import Foundation

struct Duration {
    private var startTime: UInt64 = 0
    private var stopTime: UInt64 = 0
    private let numer: UInt64
    private let denom: UInt64

    init() {
        var info = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&info)
        numer = UInt64(info.numer)
        denom = UInt64(info.denom)
    }

    public mutating func start() {
        startTime = mach_absolute_time()
    }

    public mutating func stop() {
        stopTime = mach_absolute_time()
    }

    public var nanoseconds: UInt64 {
        ((stopTime - startTime) * numer) / denom
    }

    public var milliseconds: Double {
        Double(nanoseconds) / 1_000_000
    }

    public var seconds: Double {
        Double(nanoseconds) / 1_000_000_000
    }
}