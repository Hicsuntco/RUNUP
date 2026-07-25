import Foundation

/// Builds a standard GPX 1.1 track file from a real GPS run — the one honest way to let her take
/// her own data elsewhere (Strava, Garmin Connect, a spreadsheet) instead of it being locked into
/// RunUp forever. Deliberately minimal: just `<trkpt lat lon>` per recorded point — `RunRecord`
/// only ever stored lat/lng (see `RoutePoint`), no per-point timestamp or elevation, so this
/// doesn't claim data it doesn't have. A manually-logged or no-GPS run has an empty `route` and
/// has nothing real to export — callers should check `run.route.isEmpty` before offering this.
enum GPXExporter {
    static func build(run: RunRecord) -> String {
        let points = run.route.map { "      <trkpt lat=\"\($0.lat)\" lon=\"\($0.lng)\"></trkpt>" }.joined(separator: "\n")
        let name = xmlEscape(run.title)
        let isoDate = ISO8601DateFormatter().string(from: run.date)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="RunUp" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(name)</name>
            <time>\(isoDate)</time>
          </metadata>
          <trk>
            <name>\(name)</name>
            <trkseg>
        \(points)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    /// Writes to a temp file and returns its URL, or nil if there's nothing real to write —
    /// callers hand this straight to `ShareLink(item:)`.
    static func fileURL(for run: RunRecord) -> URL? {
        guard !run.route.isEmpty else { return nil }
        let filename = "RunUp-\(Int(run.date.timeIntervalSince1970)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try build(run: run).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
