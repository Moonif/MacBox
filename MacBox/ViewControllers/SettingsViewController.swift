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
    @IBOutlet weak var defaultPathPicker: NSPopUpButton!
    @IBOutlet weak var updateChannelPicker: NSPopUpButton!
    @IBOutlet weak var pathTextField: NSTextField!
    
    // Variables
    private let userDefaults = UserDefaults.standard
    private var emulatorCustomPathString: String?
    
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
    
    // Set 86Box path text
    func setEmulatorPathTextField(text: String) {
        pathTextField.stringValue = text
    }
    
    // Reset the path picker selection back to default
    private func resetPathPickerSelection() {
        if emulatorCustomPathString == nil {
            defaultPathPicker.selectItem(at: 0)
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
    
    // Default Path Picker Action
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
