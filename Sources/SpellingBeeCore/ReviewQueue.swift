import Foundation

/// Spaced repetition for missed words. A missed word comes back after a few
/// other words. Each time it's spelled right it waits longer, and after
/// enough right answers it graduates out of the queue.
public struct ReviewQueue: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable {
        public var key: String
        /// 0 = just missed. Each correct review moves it up one box.
        public var box: Int
        /// The turn number when it is due again.
        public var dueTurn: Int
    }

    /// Turns to wait in each box. A word in the last box that is spelled right graduates.
    public static let gaps = [3, 6, 12]

    public private(set) var items: [Item] = []
    public private(set) var turn: Int = 0

    public init() {}

    public var count: Int { items.count }
    public func contains(_ key: String) -> Bool { items.contains { $0.key == key } }

    /// Call once per word asked.
    public mutating func advance() { turn += 1 }

    /// A missed word goes (back) to the first box.
    public mutating func missed(_ key: String) {
        items.removeAll { $0.key == key }
        items.append(Item(key: key, box: 0, dueTurn: turn + Self.gaps[0]))
    }

    /// A correct spelling of a queued word moves it along or graduates it.
    public mutating func correct(_ key: String) {
        guard let index = items.firstIndex(where: { $0.key == key }) else { return }
        let nextBox = items[index].box + 1
        if nextBox >= Self.gaps.count {
            items.remove(at: index)
        } else {
            items[index].box = nextBox
            items[index].dueTurn = turn + Self.gaps[nextBox]
        }
    }

    /// The most overdue word, if any is due now.
    public func due() -> String? {
        items.filter { $0.dueTurn <= turn }.min { $0.dueTurn < $1.dueTurn }?.key
    }
}
