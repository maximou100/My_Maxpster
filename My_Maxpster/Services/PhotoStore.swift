//
//  PhotoStore.swift
//  My_Maxpster
//

import Foundation
import UIKit

enum PhotoStore {
    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Saves the given image as a JPEG and returns a relative filename (e.g. "ABCD.jpg") to persist.
    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.85) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = directoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Loads a stored photo by its identifier. The identifier may be a bare filename
    /// (relative to the photos directory) or a full file URL string.
    static func load(_ identifier: String) -> UIImage? {
        let url: URL
        if identifier.hasPrefix("file://"), let parsed = URL(string: identifier) {
            url = parsed
        } else if identifier.contains("/") {
            url = URL(fileURLWithPath: identifier)
        } else {
            url = directoryURL.appendingPathComponent(identifier)
        }
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ identifier: String) {
        let url = directoryURL.appendingPathComponent(identifier)
        try? FileManager.default.removeItem(at: url)
    }
}
