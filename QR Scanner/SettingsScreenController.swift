//
//  SettingsScreenController.swift
//  QR Scanner
//
//  Created by Mark Stuart on 31/12/19.
//  Copyright © 2019 Mark Stuart. All rights reserved.
//

import UIKit
import AppAuth

class SettingsScreenController: UIViewController, UITextFieldDelegate {
    
    let model = Model.sharedInstance
    
    @IBOutlet weak var apiUrlField: UITextField!
    @IBOutlet weak var authServerField: UITextField!
    @IBOutlet weak var idField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fill api url
        if let apiUrl = model.apiUrl {
            apiUrlField.text = apiUrl
        }
        
        // Fill auth server
        if let authUrl = model.authUrl {
            authServerField.text = authUrl
        }
        
        // Fill id
        if let id = model.id {
            idField.text = id
        }
        
        disableSaveButton()
        
        // Set delegates in order to close keyboard when rturn is pressed.
        apiUrlField.delegate = self
        authServerField.delegate = self
        idField.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - Save
    @IBAction func save(_ sender: Any) {
        disableSaveButton()
        saveField(field: apiUrlField, target: &model.apiUrl)
        saveField(field: authServerField, target: &model.authUrl)
        saveField(field: idField, target: &model.id)
        
        // Navigate back.
        _ = navigationController?.popViewController(animated: true)
    }
    
    func saveField(field: UITextField, target: inout String?) {
        if let text = target {
            if text != field.text {
                target = field.text
            }
        } else {
            target = field.text
        }
    }

    @IBAction func textFieldChanged(_ sender: Any) {
        if !saveButton.isEnabled {
            enableSaveButton()
        }
    }
    
    func disableSaveButton() {
        saveButton.isEnabled = false
        saveButton.alpha = 0.5
    }
    
    func enableSaveButton() {
        saveButton.isEnabled = true
        saveButton.alpha = 1
    }
    
    // MARK: - Close keyboard
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

