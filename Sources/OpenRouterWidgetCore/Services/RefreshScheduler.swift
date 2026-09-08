import Foundation

/// Main-actor timer that drives automatic refreshes. Manually refresh can
/// happen at any time; the scheduler only fires when armed with an interval.
@MainActor
public final class RefreshScheduler {
    private var timer: Timer?

    public init() {}

    deinit {
        timer?.invalidate()
    }

    /// Starts repeating. A non-positive interval means "manual only".
    public func start(interval: TimeInterval, action: @escaping () -> Void) {
        stop()
        guard interval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
