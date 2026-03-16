#!/usr/bin/swift
import CoreGraphics
import Foundation

let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: mask,
    callback: { _, _, event, _ -> Unmanaged<CGEvent>? in
        let a1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let a2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let f1 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let f2 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let p1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let p2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        // Only print if anything is non-zero
        if a1 != 0 || a2 != 0 || f1 != 0 || f2 != 0 || p1 != 0 || p2 != 0 {
            print("int(\(a1),\(a2))  fixed(\(f1),\(f2))  point(\(p1),\(p2))")
        }
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
) else {
    print("ERROR: Could not create event tap.")
    print("→ Grant Accessibility permission to Terminal in:")
    print("  System Settings → Privacy & Security → Accessibility")
    exit(1)
}

let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("Watching scroll events — scroll both wheels now. Press Ctrl+C to stop.")
CFRunLoopRun()
