// Stats on disk: ~/Library/Application Support/TypingMadness/stats.json

import Foundation

public enum StatsStore {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TypingMadness", isDirectory: true)
    }

    static var file: URL { directory.appendingPathComponent("stats.json") }

    public static func load() -> Stats {
        guard let data = try? Data(contentsOf: file),
              let stats = try? JSONDecoder().decode(Stats.self, from: data),
              stats.version == 1 else { return Stats() }
        return stats
    }

    public static func save(_ stats: Stats) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(stats).write(to: file, options: .atomic)
        } catch {
            NSLog("TypingMadness: could not save stats: \(error)")
        }
    }
}
