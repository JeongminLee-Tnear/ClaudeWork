import Foundation
import os

/// Parses NDJSON (newline-delimited JSON) data chunks into `StreamEvent` objects.
///
/// Claude CLI outputs one JSON object per line on stdout. This parser handles:
/// - Partial lines split across multiple `Data` chunks (buffering)
/// - Empty lines (skipped)
/// - Invalid JSON (logged and skipped)
enum NDJSONParser {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.claudework",
        category: "NDJSONParser"
    )

    /// Transform a raw data stream into a stream of parsed `StreamEvent` values.
    ///
    /// - Parameter dataStream: Raw bytes from a `Process` stdout pipe.
    /// - Returns: An `AsyncStream<StreamEvent>` that yields one event per valid NDJSON line.
    static func parse(_ dataStream: AsyncStream<Data>) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                var buffer = Data()

                for await chunk in dataStream {
                    buffer.append(chunk)

                    // Process every complete line (terminated by \n) in the buffer.
                    while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                        let lineData = buffer[buffer.startIndex..<newlineIndex]
                        buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                        // Skip empty lines.
                        guard !lineData.isEmpty else { continue }

                        do {
                            let event = try JSONDecoder().decode(
                                StreamEvent.self,
                                from: Data(lineData)
                            )
                            continuation.yield(event)
                        } catch {
                            let preview = String(
                                data: Data(lineData),
                                encoding: .utf8
                            )?.prefix(200) ?? "<non-utf8>"
                            logger.warning(
                                "Failed to parse line: \(preview, privacy: .public)"
                            )
                            logger.debug("Decode error: \(error, privacy: .public)")
                        }
                    }
                }

                // The upstream may close without a trailing newline.
                // Attempt to decode whatever remains in the buffer.
                if !buffer.isEmpty {
                    do {
                        let event = try JSONDecoder().decode(
                            StreamEvent.self,
                            from: buffer
                        )
                        continuation.yield(event)
                    } catch {
                        logger.debug(
                            "Ignoring trailing buffer (\(buffer.count) bytes): \(error, privacy: .public)"
                        )
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
