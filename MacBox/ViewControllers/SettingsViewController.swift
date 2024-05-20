//
//  SettingsViewController.swift
//  MacBox
//
//  Created by Moonif on 1/12/24.
//

import Cocoa

class SettingsViewController: NSViewController {
    
    // IBOutlets
    @IBOutlet weak var appearancePicker: NSPopUpButton!
    @IBOutlet weak var macboxPathPicker: NSPopUpButton!
    @IBOutlet weak var defaultPathPicker: NSPopUpButton!
    @IBOutlet weak var updateChannelPicker: NSPopUpButton!
    @IBOutlet weak var macboxPathTextField: NSTextField!
    @IBOutlet weak var pathTextField: NSTextField!
    @IBOutlet weak var preventDisplaySleepCheckbox: NSButton!
    
    // Variables
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private var macboxCustomPathString: String?
    private var emulatorCustomPathString: String?
    private let defaultHomeDir = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Config views
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
        // Set the appearance picker selected item
        if let appAppearance = userDefaults.string(forKey: "appAppearance") {
            switch appAppearance {
            case "aqua":
                appearancePicker.selectItem(at: 2)
            case "darkAqua":
                appearancePicker.selectItem(at: 3)
            default:
                break
            }
        }
        
        // Set the Prevent Display Sleep Checkbox state
        let disableScreensaver = userDefaults.bool(forKey: "disableScreensaver")
        if disableScreensaver == true {
            preventDisplaySleepCheckbox.state = .on
        }
        
        // Set the MacBox default path picker selected item
        setMacBoxPathTextField(text: MainViewController.instance.homeDirURL.path)
        if let _ = userDefaults.string(forKey: "homeDirPath") {
            macboxPathPicker.selectItem(at: 1)
        }
        
        // Set the 86Box default path picker selected item
        setEmulatorPathTextField(text: MainViewController.instance.versionInfoObject.emulatorAutoUrl?.relativePath ?? NSLocalizedString("86Box is not installed.", comment: ""))
        if let emulatorDefaultPath = userDefaults.string(forKey: "emulatorDefaultPath") {
            if emulatorDefaultPath != "auto" {
                defaultPathPicker.selectItem(at: 1)
                setEmulatorPathTextField(text: emulatorDefaultPath)
                emulatorCustomPathString = emulatorDefaultPath
            }
        }
        
        // Set the 86Box update channel picker selected item
        if let emulatorUpdateChannel = userDefaults.string(forKey: "emulatorUpdateChannel") {
            switch emulatorUpdateChannel {
            case "stable":
                updateChannelPicker.selectItem(at: 0)
            default:
                break
            }
        }
    }
    
    // Set MacBox path text
    private func setMacBoxPathTextField(text: String) {
        macboxPathTextField.stringValue = text
    }
    
    // Reset the MacBox path picker selection back to default
    private func resetMacBoxPathPickerSelection() {
        if macboxCustomPathString == nil {
            macboxPathPicker.selectItem(at: 0)
        }
    }
    
    // Set 86Box path text
    private func setEmulatorPathTextField(text: String) {
        pathTextField.stringValue = text
    }
    
    // Reset the path picker selection back to default
    private func resetPathPickerSelection() {
        if emulatorCustomPathString == nil {
            defaultPathPicker.selectItem(at: 0)
        }
    }
    
    // Move MacBox home directory to custom location
    private func relocateHomeDir(destination: URL?) {
        do {
            let currentHomeDir = MainViewController.instance.homeDirURL
            let homeDirFiles = try fileManager.contentsOfDirectory(at: currentHomeDir, includingPropertiesForKeys: nil)
            
            if let customLocation = destination {
                // Custom location
                for homeDirFileURL in homeDirFiles {
                    var customLocationFileURL = customLocation
                    if #available(macOS 13.0, *) {
                        customLocationFileURL = customLocationFileURL.appending(component: homeDirFileURL.lastPathComponent)
                    } else {
                        // Fallback on earlier versions
                        customLocationFileURL = customLocationFileURL.appendingPathComponent(homeDirFileURL.lastPathComponent)
                    }
                    // Move the files
                    if !fileManager.fileExists(atPath: customLocationFileURL.path) {
                       try fileManager.moveItem(at: homeDirFileURL, to: customLocationFileURL)
                    }
                }
                MainViewController.instance.updateConfigFile(previousLocation: currentHomeDir, newLocation: customLocation)
                userDefaults.set(customLocation.path, forKey: "homeDirPath")
            }
            else {
                // Default location
                for homeDirFileURL in homeDirFiles {
                    var defaultLocationFileURL = defaultHomeDir
                    if #available(macOS 13.0, *) {
                        defaultLocationFileURL = defaultLocationFileURL.appending(component: homeDirFileURL.lastPathComponent)
                    } else {
                        // Fallback on earlier versions
                        defaultLocationFileURL = defaultLocationFileURL.appendingPathComponent(homeDirFileURL.lastPathComponent)
                    }
                    
                    // Try recreating the default home directory in case it was deleted by user
                    try fileManager.createDirectory(atPath: defaultHomeDir.path, withIntermediateDirectories: true)
                    // Move the files
                    if !fileManager.fileExists(atPath: defaultLocationFileURL.path) {
                        try fileManager.moveItem(at: homeDirFileURL, to: defaultLocationFileURL)
                    }
                }
                MainViewController.instance.updateConfigFile(previousLocation: currentHomeDir, newLocation: defaultHomeDir)
                userDefaults.removeObject(forKey: "homeDirPath")
            }
        }
        catch {
            // Show error alert
            let alert = NSAlert()
            
            alert.messageText = "Error: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            
            let _ = alert.runModal()
        }
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // Appearance Picker Action
    @IBAction func appearancePickerAction(_ sender: NSPopUpButton) {
        if let selectedItem = sender.selectedItem {
            switch selectedItem.identifier {
            case NSUserInterfaceItemIdentifier(rawValue: "appearanceLight"):
                NSApp.appearance = NSAppearance(named: .aqua)
                userDefaults.set("aqua", forKey: "appAppearance")
            case NSUserInterfaceItemIdentifier(rawValue: "appearanceDark"):
                NSApp.appearance = NSAppearance(named: .darkAqua)
                userDefaults.set("darkAqua", forKey: "appAppearance")
            default:
                NSApp.appearance = NSAppearance()
                userDefaults.set("system", forKey: "appAppearance")
            }
        }
    }
    
    // Enable/Disable Display Sleep
    @IBAction func preventDisplaySleepCheckboxAction(_ sender: NSButton) {
        switch sender.state {
        case .on:
            // Disable Display Sleep
            MainViewController.instance.screensaverManager.disableScreensaver()
            userDefaults.set(true, forKey: "disableScreensaver")
        default:
            // Enable Display Sleep
            MainViewController.instance.screensaverManager.enableScreensaver()
            userDefaults.set(false, forKey: "disableScreensaver")
        }
    }
    
    // MacBox Path Picker Action
    @IBAction func macboxPathPickerAction(_ sender: NSPopUpButton) {
        if let selectedItem = sender.selectedItem {
            switch selectedItem.identifier {
            case NSUserInterfaceItemIdentifier(rawValue: "macboxPathCustom"):
                // Open the file picker
                let filePickerPanel = NSOpenPanel()
                
                filePickerPanel.allowsMultipleSelection = false
                filePickerPanel.canChooseDirectories = true
                filePickerPanel.canChooseFiles = false
                filePickerPanel.canCreateDirectories = true
                
                if filePickerPanel.runModal() == .OK {
                    if let newHomeDirURL = filePickerPanel.url {
                        macboxCustomPathString = newHomeDirURL.relativePath
                        // Set path text
                        setMacBoxPathTextField(text: macboxCustomPathString ?? "-")
                        // Move the Home directory to the selected URL
                        relocateHomeDir(destination: newHomeDirURL)
                        // Refresh 86Box auto path
                        if emulatorCustomPathString == nil {
                            setEmulatorPathTextField(text: MainViewController.instance.versionInfoObject.emulatorAutoUrl?.relativePath ?? NSLocalizedString("86Box is not installed.", comment: ""))
                        }
                    }
                }
                else {
                    // Reset selection
                    resetMacBoxPathPickerSelection()
                }
            default:
                macboxCustomPathString = nil
                // Set path text
                setMacBoxPathTextField(text: defaultHomeDir.path)
                // Reset MacBox HomeDirURL
                if let _ = userDefaults.string(forKey: "homeDirPath") {
                    relocateHomeDir(destination: nil)
                }
                // Refresh 86Box auto path
                if emulatorCustomPathString == nil {
                    setEmulatorPathTextField(text: MainViewController.instance.versionInfoObject.emulatorAutoUrl?.relativePath ?? NSLocalizedString("86Box is not installed.", comment: ""))
                }
            }
        }
    }
    
    // Default 86Box Path Picker Action
    @IBAction func defaultPathPickerAction(_ sender: NSPopUpButton) {
        if let selectedItem = sender.selectedItem {
            switch selectedItem.identifier {
            case NSUserInterfaceItemIdentifier(rawValue: "pathCustom"):
                // Open the file picker
                let filePickerPanel = NSOpenPanel()
                
                filePickerPanel.allowsMultipleSelection = false
                filePickerPanel.canChooseDirectories = false
                filePickerPanel.canChooseFiles = true
                filePickerPanel.allowedFileTypes = ["app"]
                
                if filePickerPanel.runModal() == .OK {
                    if let appURL = filePickerPanel.url {
                        if let bundle = Bundle(url: appURL) {
                            // Check if selected app is 86Box
                            if bundle.bundleIdentifier == "net.86Box.86Box" {
                                emulatorCustomPathString = appURL.relativePath
                                userDefaults.set(emulatorCustomPathString ?? "-", forKey: "emulatorDefaultPath")
                                setEmulatorPathTextField(text: emulatorCustomPathString ?? "-")
                                // Update version status in MainVC
                                MainViewController.instance.versionInfoObject.emulatorCustomUrl = appURL
                                MainViewController.instance.checkFor86Box()
                            }
                            else {
                                // Not 86Box; Reset selection
                                resetPathPickerSelection()
                            }
                        }
                        else {
                            // Reset selection
                            resetPathPickerSelection()
                        }
                    }
                }
                else {
                    // Reset selection
                    resetPathPickerSelection()
                }
            default:
                userDefaults.set("auto", forKey: "emulatorDefaultPath")
                setEmulatorPathTextField(text: MainViewController.instance.versionInfoObject.emulatorAutoUrl?.relativePath ?? NSLocalizedString("86Box is not installed.", comment: ""))
                emulatorCustomPathString = nil
                // Update version status in MainVC
                MainViewController.instance.versionInfoObject.emulatorCustomUrl = nil
                MainViewController.instance.checkFor86Box()
            }
        }
    }
    
    // Update Channel Picker Action
    @IBAction func updateChannelPickerAction(_ sender: NSPopUpButton) {
        if let selectedItem = sender.selectedItem {
            var updateChannelStr = ""
            
            switch selectedItem.identifier {
            case NSUserInterfaceItemIdentifier(rawValue: "updateStable"):
                updateChannelStr = "stable"
                userDefaults.set(updateChannelStr, forKey: "emulatorUpdateChannel")
            default:
                updateChannelStr = "beta"
                userDefaults.set(updateChannelStr, forKey: "emulatorUpdateChannel")
            }
            
            // Update version status in MainVC
            MainViewController.instance.versionInfoObject.emulatorUpdateChannel = updateChannelStr
            MainViewController.instance.checkFor86Box(url: nil, appVer: nil, buildVer: nil, ignoreVersionCheck: true)
        }
    }
}
