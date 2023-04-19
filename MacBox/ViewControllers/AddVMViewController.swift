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
    
    // Variables
    let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var mainVC = MainViewController()
    
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
    }
    
    // Create VM
    private func createVM(name: String, description: String?, path: String?) -> VM {
        var vm = VM()
        
        // Set name and description
        vm.name = name
        vm.description = description
        
        // Set path
        var defaultPath = homeDirURL
        if #available(macOS 13.0, *) {
            defaultPath = homeDirURL.appending(component: "\(vm.name ?? "")")
        } else {
            // Fallback on earlier versions
            defaultPath = homeDirURL.appendingPathComponent("\(vm.name ?? "")")
        }
        vm.path = path != nil ? path : defaultPath.path
        
        return vm
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
        let vm = createVM(name: vmNameTextField.stringValue, description: vmDescriptionTextField.stringValue, path: nil)
        mainVC.addVM(vm: vm)
        
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
