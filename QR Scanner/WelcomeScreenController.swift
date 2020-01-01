//
//  WelcomeScreenController.swift
//  QR Scanner
//
//  Created by Mark Stuart on 16/10/19.
//  Copyright © 2019 Mark Stuart. All rights reserved.
//

import UIKit
import AppAuth

class WelcomeScreenController: UIViewController {
    
    let model = Model.sharedInstance
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var startLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Go directly to settings screen if a required setting is missing.
        if model.apiUrl == nil || model.authUrl == nil {
            performSegue(withIdentifier: "toSettings", sender: nil)
        }
        
        if !model.isLoggedIn() {
            showLogin()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - Authentication
 
    // Runs whenever the login button is pressed.
    @IBAction func signOut() {
        if model.isLoggedIn() {
            model.signOut();
            showLogin()
        } else {
            model.login(view: self);
            showLogout()
        }

    }
    
    func showLogin() {
        loginButton.setTitle("Sign In", for: .normal)
        startButton.isHidden = true
        startLabel.isHidden = true
    }
    
    func showLogout() {
        loginButton.setTitle("Sign Out", for: .normal)
        startButton.isHidden = false
        startLabel.isHidden = false
    }
}
