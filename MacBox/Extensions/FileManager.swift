//
//  FileManager.swift
//  MacBox
//
//  Created by Moonif on 4/18/23.
//

import Foundation

extension FileManager {
    func sizeOfFile(atPath path: String) -> Int64? {
        guard let attrs = try? attributesOfItem(atPath: path) else {
            return nil
        }

        return attrs[.size] as? Int64
    }
    
    func sizeOfDirectory(atPath path: String) -> Int? {
        let url = URL(fileURLWithPath: path)
        if let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey], options: [], errorHandler: { (_, error) -> Bool in
            print("Error: \(error.localizedDescription)")
            return false
        }) {
            var bytes = 0
            for case let url as URL in enumerator {
                bytes += url.fileSize ?? 0
            }
            return bytes
        } else {
            return nil
        }
    }
}
