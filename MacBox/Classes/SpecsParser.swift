//
//  SpecsParser.swift
//  MacBox
//
//  Created by Moonif on 4/26/23.
//

import Foundation

class SpecsParser {
    
    // Parse config file and return machine specs in a string format
    public func ParseVMConfigFile(vmConfigPath: String) -> (machine: String, cpu: String, ram: String, hdd: String) {
        var machineString = ""
        var cpuString = ""
        var ramString = ""
        var hddString = ""
        
        let ini = IniParser()
        // Parse machine type
        let machineType = ini.parseConfig(vmConfigPath)["Machine"]?["machine"]
        // Parse cpu family
        let cpuFamily = ini.parseConfig(vmConfigPath)["Machine"]?["cpu_family"]
        // Parse cpu speed
        let cpuSpeed = ini.parseConfig(vmConfigPath)["Machine"]?["cpu_speed"] ?? "0"
        // Parse ram size
        let ramSize = ini.parseConfig(vmConfigPath)["Machine"]?["mem_size"] ?? "0"
        // Parse ram expansion size
        let ramExpansionSize = ini.parseConfig(vmConfigPath)["IBM PC/XT Memory Expansion #1"]?["size"] ?? "0"
        // Parse hdd size
        let hddPath = ini.parseConfig(vmConfigPath)["Hard disks"]?["hdd_01_fn"] ?? nil
        // Parse hdd parameters
        let hddParams = ini.parseConfig(vmConfigPath)["Hard disks"]?["hdd_01_parameters"] ?? ""
        let hddParamsSplit = hddParams.split(separator: ",")
        var hddS: Int64 = 0
        var hddH: Int64 = 0
        var hddC: Int64 = 0
        if hddParamsSplit.count > 0 {
            hddS = Int64(hddParamsSplit[0].trimmingCharacters(in: .whitespaces)) ?? 0
            hddH = Int64(hddParamsSplit[1].trimmingCharacters(in: .whitespaces)) ?? 0
            hddC = Int64(hddParamsSplit[2].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        
        // Parse and define devices name
        let nameDefs = Bundle.main.path(forResource: "namedefs.inf", ofType: nil)
        
        // Define machine type name
        if let machinesDef = (ini.parseConfig(nameDefs ?? "")["machine"]) {
            if machinesDef[machineType ?? ""] != nil {
                machineString = machinesDef[machineType ?? ""] ?? "-"
            }
            else {
                machineString = machineType ?? "-"
            }
        }
        
        // Define cpu family name
        var cpuFamilyName = ""
        if let cpuDef = (ini.parseConfig(nameDefs ?? "")["cpu_family"]) {
            if cpuDef[cpuFamily ?? ""] != nil {
                cpuFamilyName = cpuDef[cpuFamily ?? ""] ?? "-"
            }
            else {
                cpuFamilyName = cpuFamily ?? "-"
            }
        }
        
        // Define cpu speed
        let cpuSpeedConverted = (Float(cpuSpeed) ?? 0.0) / 1000000
        let cpuSpeedRounded = String(format: "%.2f", cpuSpeedConverted)
        cpuString = "\(cpuFamilyName) \(cpuSpeedRounded) MHz"
        
        // Define and format ram size
        let ramBCF = ByteCountFormatter()
        ramBCF.allowedUnits = [.useAll]
        ramBCF.countStyle = .memory
        let ramSizeConverted = ramBCF.string(fromByteCount: (Int64(ramSize) ?? 0) * 1024)
        ramString = "RAM \(ramSizeConverted)"
        
        // Define ram expansion
        if Int64(ramExpansionSize) ?? 0 > 0 {
            let ramExpansionSizeConverted = ramBCF.string(fromByteCount: (Int64(ramExpansionSize) ?? 0) * 1024)
            ramString = "RAM \(ramSizeConverted) + \(ramExpansionSizeConverted) Expansion"
        }
        
        // Define hdd size
        if hddPath != nil {
            // Calculate hdd size
            let hddSize = hddS * hddH * hddC * 512
            // Format hdd size
            let hddBCF = ByteCountFormatter()
            hddBCF.allowedUnits = [.useAll]
            hddBCF.countStyle = .binary
            let hddSizeConverted = hddBCF.string(fromByteCount: hddSize)
            hddString = "HDD \(hddSizeConverted)"
        }
        else {
            hddString = "No HDD"
        }
        // Return strings
        return (machineString, cpuString, ramString, hddString)
    }
}
