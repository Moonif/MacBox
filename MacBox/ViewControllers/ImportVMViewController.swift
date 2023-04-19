//
//  ImportVMViewController.swift
//  MacBox
//
//  Created by Moonif on 4/13/23.
//

import Cocoa

class ImportVMViewController: NSViewController {
    
    // IBOutlets
    @IBOutlet weak var configFilesTableView: NSTableView!
    @IBOutlet weak var spinningProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var searchText: NSTextField!
    @IBOutlet weak var foundText: NSTextField!
    @IBOutlet weak var addButton: NSButton!
    
    // Variables
    var mainVC = MainViewController()
    let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    private var cancelSearch: Bool = false
    private var configFilesList: [String] = []
    private var importedVMPath : String?

    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegates
        configFilesTableView.delegate = self
        configFilesTableView.dataSource = self
    }
    
    // Start the search when the view appear
    override func viewWillAppear() {
        // Config views
        configView()
        
        cancelSearch = false
        findConfigFiles()
    }
    
    // Cancel the search when the view disappear
    override func viewDidDisappear() {
        cancelSearch = true
    }
    
    // Config views initial properties
    private func configView() {
        spinningProgressIndicator.startAnimation(self)
        searchText.isHidden = false
        foundText.isHidden = true
        addButton.isEnabled = false
    }
    
    // Find 86Box config files
    private func findConfigFiles() {
        // Clear the config files list
        configFilesList.removeAll()
        configFilesTableView.reloadData()
        
        // Set the search path at the user's home directory
        let url = FileManager.default.homeDirectoryForCurrentUser
        let localFileManager = FileManager()
        
        if let enumerator: FileManager.DirectoryEnumerator = localFileManager.enumerator(atPath: url.path) {
            // Conduct the search as a background process as not to block the user interaction
            DispatchQueue.global(qos: .background).async {
                while let element = enumerator.nextObject() as? String {
                    if self.cancelSearch {
                        // Break the loop when cancel search is true
                        break
                    }
                    let configFileSuffix = "/86box.cfg"
                    guard element.hasSuffix(configFileSuffix) else { continue }
                    
                    let vmPath = "\(url.path)/\(element)".dropLast(configFileSuffix.count)
                    
                    // Check if path already present in the VMs list
                    let match = self.mainVC.vmList.contains(where: { vm in
                        if let path = vm.path {
                            if path == vmPath {
                                return true
                            }
                        }
                        return false
                    })
                    
                    // If path is not present, add it for import
                    if !match {
                        self.configFilesList.append(String(vmPath))
                    }
                    
                    DispatchQueue.main.async {
                        self.configFilesTableView.reloadData()
                    }
                }
                // Done
                DispatchQueue.main.async {
                    self.spinningProgressIndicator.stopAnimation(self)
                    self.searchText.isHidden = true
                    self.foundText.isHidden = false
                    if self.configFilesList.count > 0 {
                        self.foundText.stringValue = "MacBox found \(self.configFilesList.count) VMs on your Mac, press the \"Add\" button to import them."
                        self.addButton.isEnabled = true
                    }
                    else {
                        self.foundText.stringValue = "MacBox could not find any VM on your Mac."
                    }
                }
            }
        }
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
    
    // Dismiss the add VM tabVC modal view
    private func dismissView() {
        if let tabVC = self.parent as? NSTabViewController {
            dismiss(tabVC)
        }
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // Add button action
    @IBAction func addButtonAction(_ sender: NSButton) {
        for vmConfigPath in configFilesList {
            // Create a VM and add it to the table view
            let vmPathURL = URL(fileURLWithPath: vmConfigPath)
            let vm = createVM(name: vmPathURL.lastPathComponent, description: nil, path: vmConfigPath)
            mainVC.addVM(vm: vm)
        }
        
        // Dismiss the add VM tabVC modal view
        dismissView()
    }
    
    // Add manually button action
    @IBAction func addManuallyButtonAction(_ sender: NSButton) {
        // Cancel search
        cancelSearch = true
        
        // Open the file picker
        let filePickerPanel = NSOpenPanel()
        
        filePickerPanel.allowsMultipleSelection = false
        filePickerPanel.canChooseDirectories = true
        filePickerPanel.canChooseFiles = false
        
        if filePickerPanel.runModal() == .OK {
            if let vmDirectoryURL = filePickerPanel.url?.path {
                let VMConfigFileURL = vmDirectoryURL.appending("/86box.cfg")
                if FileManager.default.fileExists(atPath: VMConfigFileURL) {
                    // 86Box config file was found
                    importedVMPath = vmDirectoryURL
                    
                    // Create a VM and add it to the table view
                    let vm = createVM(name: filePickerPanel.url?.lastPathComponent ?? "Imported VM", description: nil, path: importedVMPath)
                    mainVC.addVM(vm: vm)
                    
                    // Dismiss the add VM tabVC modal view
                    dismissView()
                }
                else {
                    // No 86Box was found at path
                    importedVMPath = nil
                    
                    // Show error: No 86Box was found
                    let alert = NSAlert()
                    
                    alert.messageText = "No 86Box config files was found!"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    
                    let alertResult = alert.runModal()
                    if alertResult == .alertFirstButtonReturn {
                        // Config views
                        configView()
                        
                        cancelSearch = false
                        findConfigFiles()
                    }
                }
            }
        }
        else {
            // Config views
            configView()
            
            cancelSearch = false
            findConfigFiles()
        }
    }
}

// ------------------------------------
// Config files TableView Delegate and Datasource
// ------------------------------------
extension ImportVMViewController: NSTableViewDelegate, NSTableViewDataSource {
    // Return number of cells for config files table view
    func numberOfRows(in tableView: NSTableView) -> Int {
        return configFilesList.count
    }
    
    // Populate cells based on configFilesList data
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let vmObject = configFilesList[row]
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "textCellID"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = vmObject
        return cell
    }
}
