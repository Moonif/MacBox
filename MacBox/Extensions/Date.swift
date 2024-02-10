//
//  Date.swift
//  MacBox
//
//  Created by Moonif on 1/17/24.
//

import Foundation

extension Date {
   func getFormattedDate(format: String) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        return dateformat.string(from: self)
    }
}
