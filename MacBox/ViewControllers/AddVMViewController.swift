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
    @IBOutlet weak var clearVMButton: NSButton!
    
    // Variables
    let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var mainVC = MainViewController()
    var importedVMPath : String?
    
    let nameTextFieldMaxLimit: Int = 32

    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegates
        vmNameTextField.delegate = self
        
        configView()
    }
    
    // View will appear
    override func viewWillAppear() {
        // Remove fullscreen window button
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // Config views initial properties
    private func configView() {
        vmPathStatusTextField.stringValue = "VM will be created at: \"\(homeDirURL.path)\"."
        clearVMButton.isEnabled = false
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
        var vm = VM()
        
        vm.name = vmNameTextField.stringValue
        vm.description = vmDescriptionTextField.stringValue
        vm.path = importedVMPath
        
        mainVC.addVM(vm: vm)
        
        // Dismiss the add VM modal view
        dismiss(self)
    }
    
    // Import an existing VM
    @IBAction func importVMButtonAction(_ sender: NSButton) {
        let filePickerPanel = NSOpenPanel()
        
        filePickerPanel.allowsMultipleSelection = false
        filePickerPanel.canChooseDirectories = true
        filePickerPanel.canChooseFiles = false
        
        if filePickerPanel.runModal() == .OK {
            if let vmDirectoryURL = filePickerPanel.url?.path {
                let VMConfigFileURL = vmDirectoryURL.appending("/86box.cfg")
                if FileManager.default.fileExists(atPath: VMConfigFileURL) {
                    importedVMPath = vmDirectoryURL
                    vmPathStatusTextField.stringValue = "🟢 86Box config file was found.\nVM is located at: \"\(importedVMPath ?? "")\"."
                    clearVMButton.isEnabled = true
                }
                else {
                    importedVMPath = nil
                    vmPathStatusTextField.stringValue = "🔴 Could not find 86Box config file.\nA new VM will be created at: \"\(homeDirURL.path)\"."
                    clearVMButton.isEnabled = false
                }
            }
        }
    }
    
    @IBAction func clearVMButtonAction(_ sender: NSButton) {
        importedVMPath = nil
        configView()
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
