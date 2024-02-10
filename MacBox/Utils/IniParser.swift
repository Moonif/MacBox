//
//  IniParser.swift
//  MacBox
//

import Foundation

class IniParser {
    typealias SectionConfig = [String: String]
    typealias Config = [String: SectionConfig]

    private func trim(_ s: String) -> String {
        let whitespaces = CharacterSet(charactersIn: " \n\r\t")
        return s.trimmingCharacters(in: whitespaces)
    }

     private func stripComment(_ line: String) -> String {
        let parts = line.split(
          separator: "#",
          maxSplits: 1,
          omittingEmptySubsequences: false)
        if parts.count > 0 {
            return String(parts[0])
        }
        return ""
    }

    private func parseSectionHeader(_ line: String) -> String {
        let from = line.index(after: line.startIndex)
        let to = line.index(before: line.endIndex)
        return String(line[from..<to])
    }

    private func parseLine(_ line: String) -> (String, String)? {
        let parts = stripComment(line).split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            let k = trim(String(parts[0]))
            let v = trim(String(parts[1]))
            return (k, v)
        }
        return nil
    }

    func parseConfig(_ filename : String) -> Config {
        var config = Config()
        
        if let f = try? String(contentsOfFile: filename) {
            var currentSectionName = "main"
            for l in f.components(separatedBy: "\n") {
                let line = trim(l)
                if line.hasPrefix("[") && line.hasSuffix("]") {
                    currentSectionName = parseSectionHeader(line)
                } else if let (k, v) = parseLine(line) {
                    var section = config[currentSectionName] ?? [:]
                    section[k] = v
                    config[currentSectionName] = section
                }
            }
        }
        
        return config
    }
}
