import CoreGraphics
import AppKit
import os.log

var debugLogging = false

private let logger = Logger(subsystem: "com.peter.sidescrollconverter", category: "scroll")

private func scrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let ptr = userInfo {
            let interceptor = Unmanaged<ScrollInterceptor>.fromOpaque(ptr).takeUnretainedValue()
            if let tap = interceptor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return nil
    }

    guard type == .scrollWheel else { return Unmanaged.passRetained(event) }

    let axis1      = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let axis2      = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
    let fixedAxis1 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
    let fixedAxis2 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)
    let pointAxis1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    let pointAxis2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

    if debugLogging {
        let msg = "scroll  int:(\(axis1),\(axis2))  fixed:(\(fixedAxis1),\(fixedAxis2))  point:(\(pointAxis1),\(pointAxis2))\n"
        if let data = msg.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/sidescroll_debug.txt")
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            } else {
                try? data.write(to: url)
            }
        }
    }

    guard axis2 != 0 || fixedAxis2 != 0 || pointAxis2 != 0 else {
        return Unmanaged.passRetained(event)
    }

    // Read multiplier from interceptor
    let mult: Double
    if let ptr = userInfo {
        mult = Unmanaged<ScrollInterceptor>.fromOpaque(ptr).takeUnretainedValue().multiplier
    } else {
        mult = 1.0
    }

    let newAxis2  = Int64((Double(axis2)  * mult).rounded())
    let newFixed2 = Int64((Double(fixedAxis2) * mult).rounded())
    let newPoint2 = Int64((Double(pointAxis2) * mult).rounded())

    event.setIntegerValueField(.scrollWheelEventDeltaAxis1,        value: newAxis2)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2,        value: 0)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: newFixed2)
    event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1,   value: newPoint2)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2,   value: 0)

    return Unmanaged.passRetained(event)
}

class ScrollInterceptor {
    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isEnabled: Bool = false

    /// Speed multiplier — 1.0 = normal, 2.0 = double speed, etc.
    var multiplier: Double {
        didSet { UserDefaults.standard.set(multiplier, forKey: "scrollMultiplier") }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "scrollMultiplier")
        multiplier = saved > 0 ? saved : 1.0
    }

    func enable() -> Bool {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            isEnabled = true
            return true
        }

        let eventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: scrollEventCallback,
            userInfo: selfPtr
        ) else {
            logger.error("CGEvent.tapCreate failed — no Accessibility permission?")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
        return true
    }

    func disable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        isEnabled = false
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
    }
}
