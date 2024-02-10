//
//  URL.swift
//  MacBox
//
//  Created by Moonif on 1/31/24.
//

import Foundation

extension URL {
    var fileSize: Int? {
        do {
            let val = try self.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            return val.totalFileAllocatedSize ?? val.fileAllocatedSize
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
}
