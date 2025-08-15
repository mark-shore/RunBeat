import Foundation

enum VO2Phase {
	case highIntensity
	case rest
}

struct VO2IntervalState {
	var phase: VO2Phase
	var start: Date
	var duration: TimeInterval

	var end: Date { start.addingTimeInterval(duration) }

	func remaining(at now: Date) -> TimeInterval {
		max(0, end.timeIntervalSince(now))
	}
}


