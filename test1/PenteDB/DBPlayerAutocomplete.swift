import Foundation

/// Gate in front of `/players`: skips short queries, debounces keystrokes and
/// delivers only the latest query's result. Main-actor only.
@MainActor
final class DBPlayerAutocomplete {
    private let client: DBClient
    private let debounce: TimeInterval
    private let gate = DBRequestGate()
    private var task: Task<Void, Never>?

    init(client: DBClient, debounce: TimeInterval = 0.25) {
        self.client = client
        self.debounce = debounce
    }

    func query(_ text: String, completion: @escaping ([String]) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = gate.next(.players)
        task?.cancel()
        task = nil
        guard trimmed.count >= 2 else {
            completion([])
            return
        }
        let wait = debounce
        task = Task { [weak self] in
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            guard let self, !Task.isCancelled, self.gate.isLatest(id, .players) else { return }
            let result = (try? await self.client.players(query: trimmed)) ?? []
            guard !Task.isCancelled, self.gate.isLatest(id, .players) else { return }
            completion(result)
        }
    }
}
