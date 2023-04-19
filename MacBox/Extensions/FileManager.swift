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
}
