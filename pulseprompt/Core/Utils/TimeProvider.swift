import Foundation

protocol TimeProvider {
	func now() -> Date
}

struct SystemTimeProvider: TimeProvider {
	func now() -> Date { Date() }
}


