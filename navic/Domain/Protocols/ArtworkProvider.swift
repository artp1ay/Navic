import Foundation
import AppKit

protocol ArtworkProvider: AnyObject {
    func artwork(for track: Track, size: Int) async throws -> NSImage?
}
