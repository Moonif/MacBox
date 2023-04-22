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
    @IBOutlet weak var vmDescriptionTextField: NSTextField!
    @IBOutlet weak var vmPathStatusTextField: NSTextField!
    @IBOutlet weak var vmTemplateComboBox: NSComboBox!
    @IBOutlet weak var vmSpecMachine: NSTextField!
    @IBOutlet weak var vmSpecCPU: NSTextField!
    @IBOutlet weak var vmSpecRAM: NSTextField!
    @IBOutlet weak var vmSpecMachineLogo: NSImageView!
    
    // Variables
    let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var mainVC = MainViewController()
    var vmTemplateList: [VMTemplate] = []
    var currentTemplateConfigPath: String?
    
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
        // Patch status text
        vmPathStatusTextField.stringValue = "VM will be created at: \"\(homeDirURL.path)\"."
    }
    
    // Populate VM templates
    private func populateVMTemplates() {
        // Add default item
        vmTemplateList.append(VMTemplate())
        
        // Add VM templates paths
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
                
                vmTemplate.name = "[\(vmTemplateYear)] \(vmTemplateDescription)"
                
                if let machineLogo = ini.parseConfig(vmTemplate.infoPath ?? "")["General"]?["Logo"] {
                    vmTemplate.machineLogo = machineLogo
                }
            }
            
            vmTemplateList.append(vmTemplate)
        }
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
            if let machineLogo = vmTemplateList[vmTemplateComboBox.indexOfSelectedItem].machineLogo {
                logo = machineLogo
            }
        }
        
        let vm = createVM(name: vmNameTextField.stringValue, description: vmDescriptionTextField.stringValue, path: nil, logo: logo)
        mainVC.addVM(vm: vm, vmTemplateConfigPath: currentTemplateConfigPath)
        
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
        return vmTemplateList[index].name
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if vmTemplateComboBox.indexOfSelectedItem >= 0 {
            let vmTemplateConfigFilePath = vmTemplateList[vmTemplateComboBox.indexOfSelectedItem].configPath
            currentTemplateConfigPath = vmTemplateComboBox.indexOfSelectedItem == 0 ? nil : vmTemplateConfigFilePath
            setVMSpecs(vmConfigPath: vmTemplateConfigFilePath ?? "")
        }
    }
}
