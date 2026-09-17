import Foundation
import IOKit.hid

// Protocol reference: https://github.com/samhenrigold/LidAngleSensor
// Independent implementation from protocol facts; no source code copied.
@MainActor
final class LidAngleReader {
    // A separate owner ensures cleanup on destruction without an actor-isolated
    // deinit. It never escapes this reader. No run-loop scheduling is needed
    // because feature reports are synchronous and the caller polls.
    private final class Handles {
        let manager: IOHIDManager
        var device: IOHIDDevice?

        init(manager: IOHIDManager) {
            self.manager = manager
        }

        deinit {
            if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    private var handles: Handles?

    init() {}

    /// Returns degrees, or nil when unavailable. Retries discovery after failure.
    func read() -> Double? {
        if let device = handles?.device {
            guard let angle = readReport(device) else {
                close()
                return nil
            }
            return angle
        }

        // Independent devices make each successful device open ours to close,
        // rather than also being opened/closed implicitly by the manager.
        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue
        )
        let matching: [String: Int] = [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDDeviceUsagePageKey: 0x20,
            kIOHIDDeviceUsageKey: 0x8A
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let owner = Handles(manager: manager)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let candidates = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }

        for candidate in candidates {
            guard IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                continue
            }
            if let angle = readReport(candidate) {
                owner.device = candidate
                handles = owner // Keep both manager and working device alive.
                return angle
            }
            IOHIDDeviceClose(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        return nil
    }

    /// Idempotent; the next read can reopen. Destruction also closes all handles.
    func close() {
        handles = nil
    }

    private func readReport(_ device: IOHIDDevice) -> Double? {
        let advertisedLength = (IOHIDDeviceGetProperty(
            device, kIOHIDMaxFeatureReportSizeKey as CFString
        ) as? NSNumber)?.intValue ?? 64
        var report = [UInt8](repeating: 0, count: max(3, advertisedLength))
        report[0] = 1
        var length = report.count
        let status = report.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, buffer.baseAddress!, &length)
        }
        guard status == kIOReturnSuccess, length >= 3, length <= report.count else { return nil }
        let angle = UInt16(report[1]) | (UInt16(report[2]) << 8)
        guard angle <= 180 else { return nil } // UInt16 also enforces the lower bound.
        return Double(angle)
    }
}
