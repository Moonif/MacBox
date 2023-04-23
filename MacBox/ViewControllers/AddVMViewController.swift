//
//  AddVMViewController.swift
//  MacBox
//
//  Created by Moonif on 4/10/23.
//

import Cocoa

class AddVMViewController: NSViewController {
    
    // IBOutlets
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet var vmDescriptionTextView: NSTextView!
    @IBOutlet weak var vmPathStatusTextField: NSTextField!
    @IBOutlet weak var vmTemplateComboBox: NSComboBox!
    @IBOutlet weak var vmSpecMachine: NSTextField!
    @IBOutlet weak var vmSpecCPU: NSTextField!
    @IBOutlet weak var vmSpecRAM: NSTextField!
    @IBOutlet weak var vmSpecHDD: NSTextField!
    @IBOutlet weak var vmSpecMachineLogo: NSImageView!
    @IBOutlet weak var vmTemplateShaderOption: NSButton!
    
    // Variables
    let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var mainVC = MainViewController()
    var vmTemplateList: [VMTemplate] = []
    var currentVMTemplate: VMTemplate?
    
    let nameTextFieldMaxLimit: Int = 32

    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegates
        vmNameTextField.delegate = self
        vmTemplateComboBox.delegate = self
        vmTemplateComboBox.dataSource = self
        
        // Config views
        configView()
        
        // Populate VM templates
        populateVMTemplates()
    }
    
    // View will appear
    override func viewWillAppear() {
        // Remove fullscreen window button
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // Config views initial properties
    private func configView() {
        // Specs text
        vmSpecMachine.stringValue = "-"
        vmSpecCPU.stringValue = "-"
        vmSpecRAM.stringValue = "-"
        vmSpecHDD.stringValue = "-"
        vmSpecMachineLogo.image = nil
        // Patch status text
        vmPathStatusTextField.stringValue = "VM will be created at: \"\(homeDirURL.path)\"."
        // Shader option
        vmTemplateShaderOption.isTransparent = true
    }
    
    // Populate VM templates
    private func populateVMTemplates() {
        // Clear list
        vmTemplateList.removeAll()
        // Add default item
        vmTemplateList.append(VMTemplate())
        
        // Add VM templates paths
        var vmTemplateListSort: [VMTemplate] = []
        let vmTemplatesPaths = Bundle.main.paths(forResourcesOfType: nil, inDirectory: "Templates")
        for path in vmTemplatesPaths {
            // Create and add VM template
            var vmTemplate = VMTemplate()
            
            // Set template data paths
            vmTemplate.infoPath = path.appending("/macbox.inf")
            vmTemplate.configPath = path.appending("/86box.cfg")
            
            if FileManager.default.fileExists(atPath: vmTemplate.infoPath ?? "") {
                let ini = IniParser()
                
                let vmTemplateDescription = ini.parseConfig(vmTemplate.infoPath ?? "")["General"]?["Description"] ?? ""
                let vmTemplateYear = ini.parseConfig(vmTemplate.infoPath ?? "")["General"]?["Year"] ?? ""
                
                // VM template name
                vmTemplate.name = vmTemplateDescription
                // VM template year
                vmTemplate.year = vmTemplateYear
                // VM template logo
                if let machineLogo = ini.parseConfig(vmTemplate.infoPath ?? "")["General"]?["Logo"] {
                    vmTemplate.machineLogo = machineLogo
                }
            }
            
            vmTemplateListSort.append(vmTemplate)
        }
        // Add and sort VM templates list
        vmTemplateList.append(contentsOf: vmTemplateListSort.sorted(by: { $0.year ?? "" < $1.year ?? "" }))

        // Reload combo box data
        vmTemplateComboBox.reloadData()
    }
    
    // Create VM
    private func createVM(name: String, description: String?, path: String?, logo: String?) -> VM {
        var vm = VM()
        
        // Set VM properties
        vm.name = name
        vm.description = description
        vm.path = path
        vm.logo = logo
        
        return vm
    }
    
    // Set current VM specs
    private func setVMSpecs(vmConfigPath: String) {
        if vmConfigPath != "" {
            let ini = IniParser()
            // Parse machine type
            let machineType = ini.parseConfig(vmConfigPath)["Machine"]?["machine"]
            // Parse cpu family
            let cpuFamily = ini.parseConfig(vmConfigPath)["Machine"]?["cpu_family"]
            // Parse cpu speed
            let cpuSpeed = ini.parseConfig(vmConfigPath)["Machine"]?["cpu_speed"] ?? "0"
            // Parse ram size
            let ramSize = ini.parseConfig(vmConfigPath)["Machine"]?["mem_size"] ?? "0"
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
                    vmSpecMachine.stringValue = machinesDef[machineType ?? ""] ?? "-"
                }
                else {
                    vmSpecMachine.stringValue = machineType ?? "-"
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
            vmSpecCPU.stringValue = "\(cpuFamilyName) \(cpuSpeedRounded) MHz"
            
            // Define and format ram size
            let ramBCF = ByteCountFormatter()
            ramBCF.allowedUnits = [.useAll]
            ramBCF.countStyle = .memory
            let ramSizeConverted = ramBCF.string(fromByteCount: (Int64(ramSize) ?? 0) * 1024)
            vmSpecRAM.stringValue = "RAM \(ramSizeConverted)"
            
            // Define hdd size
            if hddPath != nil {
                // Calculate hdd size
                let hddSize = hddS * hddH * hddC * 512
                // Format hdd size
                let hddBCF = ByteCountFormatter()
                hddBCF.allowedUnits = [.useAll]
                hddBCF.countStyle = .binary
                let hddSizeConverted = hddBCF.string(fromByteCount: hddSize)
                vmSpecHDD.stringValue = "HDD \(hddSizeConverted)"
            }
            else {
                vmSpecHDD.stringValue = "No HDD"
            }
            
            // Define machine logo
            if let machineLogo = vmTemplateList[vmTemplateComboBox.indexOfSelectedItem].machineLogo {
                vmSpecMachineLogo.image = NSImage(named: machineLogo)
            }
            else {
                vmSpecMachineLogo.image = nil
            }
        }
        else {
            // Empty template selected
            vmSpecMachine.stringValue = "-"
            vmSpecCPU.stringValue = "-"
            vmSpecRAM.stringValue = "-"
            vmSpecHDD.stringValue = "-"
            vmSpecMachineLogo.image = nil
        }
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // Add VM button action
    @IBAction func addVMButtonAction(_ sender: NSButton) {
        // Check if VM name was provided
        if vmNameTextField.stringValue.isEmpty {
            vmNameTextField.backgroundColor = .systemRed
            return
        }
        
        // Check if VM name was already taken
        for vmListEntry in mainVC.vmList {
            if vmNameTextField.stringValue == vmListEntry.name {
                // Show name taken alert
                let alert = NSAlert()
                
                alert.messageText = "VM name is already taken!"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                
                let _ = alert.runModal()
                
                return
            }
        }
        
        // Create a VM and add it to the table view
        var logo: String?
        if vmTemplateComboBox.indexOfSelectedItem > 0 {
            // Logo
            if let machineLogo = currentVMTemplate?.machineLogo {
                logo = machineLogo
            }
            // Shader
            if vmTemplateShaderOption.state == .on {
                currentVMTemplate?.useShader = true
            }
        }
        
        let vm = createVM(name: vmNameTextField.stringValue, description: vmDescriptionTextView.string, path: nil, logo: logo)
        mainVC.addVM(vm: vm, vmTemplate: currentVMTemplate)
        
        // Dismiss the add VM tabVC modal view
        if let tabVC = self.parent as? NSTabViewController {
            dismiss(tabVC)
        }
    }
}

// ------------------------------------
// TextField Delegate
// ------------------------------------
extension AddVMViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            textField.backgroundColor = NSColor.textBackgroundColor
            if textField.stringValue.count > nameTextFieldMaxLimit {
                textField.stringValue = String(textField.stringValue.dropLast())
            }
        }
    }
}

// ------------------------------------
// VMTemplate ComboBox Delegate
// ------------------------------------
extension AddVMViewController: NSComboBoxDelegate, NSComboBoxDataSource {
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return vmTemplateList.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        var vmDescription = ""
        if let vmYear = vmTemplateList[index].year {
            vmDescription.append("[\(vmYear)]")
        }
        if let vmName = vmTemplateList[index].name {
            vmDescription.append(" \(vmName)")
        }
        return vmDescription
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if vmTemplateComboBox.indexOfSelectedItem >= 0 {
            if vmTemplateComboBox.indexOfSelectedItem > 0 {
                vmTemplateShaderOption.isTransparent = false
                vmTemplateShaderOption.state = .on
            }
            else {
                vmTemplateShaderOption.isTransparent = true
            }
            let vmTemplate = vmTemplateList[vmTemplateComboBox.indexOfSelectedItem]
            currentVMTemplate = vmTemplateComboBox.indexOfSelectedItem == 0 ? nil : vmTemplate
            setVMSpecs(vmConfigPath: vmTemplate.configPath ?? "")
        }
    }
}
