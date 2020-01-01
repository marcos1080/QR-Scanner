//
//  Model.swift
//  QR Scanner
//
//  Created by Mark Stuart on 10/11/19.
//  Copyright © 2019 Mark Stuart. All rights reserved.
//

import Foundation
import UIKit
import AVKit

class Model {
    
    let appAuthManager: AppAuthManager
    let restManager: RestManager
    
    // Audio
    var clickPlayer: AVAudioPlayer?
    var audioPlayer: AVAudioPlayer?
    let cameraClickFile = Bundle.main.path(forResource: "camera", ofType: "mp3")
    let errorBeepFile = Bundle.main.path(forResource: "error", ofType: "mp3")
    
    // Settings
    struct defaultsKeys {
        static let apiUrl = "apiUrl"
        static let authUrl = "authUrl"
        static let id = "id"
    }
    
    // List of scopes to allow token for. Add to this array for each scope.
    let scopes: [String] = []
    
    static let sharedInstance: Model = {
        let instance = Model()
        
        return instance
    }()
    
    private init() {
        appAuthManager = AppAuthManager(
            clientId: "ios",
            redirectionUriScheme: "io.identityserver.demo",
            redirectionUriEndpoint: ":/oauthredirect",
            authStateKey: "authState",
            scopes: scopes
        )
        
        restManager = RestManager()
    }
    
    // MARK: - Authentication
    
    func isLoggedIn() -> Bool {
        appAuthManager.loadState()
        return appAuthManager.authState == nil ? false : true
    }
    
    func login(view: UIViewController) {
        appAuthManager.loadState()
        appAuthManager.issuerUrl = self.authUrl!
        
        // Login function.
        if appAuthManager.authState == nil {
            appAuthManager.authorizeRp(view: view, issuerUrl: appAuthManager.issuerUrl, configuration: nil)
        }
    }
    
    // Modified from code sourced from https://developer.forgerock.com/docs/platform/how-tos/implementing-oauth-20-authorization-code-grant-protected-pkce-appauth-sdk-ios#simple
    func signOut() {
        if let idToken = appAuthManager.authState?.lastTokenResponse?.idToken {
            appAuthManager.issuerUrl = self.authUrl!
            
            /**
             OIDC Provider `end_session_endpoint`.
             
             At the moment, AppAuth does not support [RP-initiated logout](https://openid.net/specs/openid-connect-session-1_0.html#RPLogout), although it [may in the future](https://github.com/openid/AppAuth-iOS/pull/191), and the `end_session_endpoint` is not captured from the OIDC discovery document; hence, the endpoint may need to be provided manually.
             */
            if let endSessionEndpointUrl = URL(string: appAuthManager.issuerUrl! + "connect/endsession" + "?id_token_hint=" + idToken) {
                let urlRequest = URLRequest(url: endSessionEndpointUrl)
                
                appAuthManager.sendUrlRequest(urlRequest: urlRequest) {
                    data, response, request in
                    
                    if !(200...299).contains(response.statusCode) {
                        // Handling server errors
                        print("RP-initiated logout HTTP response code: \(response.statusCode)")
                    } else {
                        self.appAuthManager.setAuthState(nil)
                        URLCache.shared.removeAllCachedResponses()
                        URLCache.shared.diskCapacity = 0
                        URLCache.shared.memoryCapacity = 0
                    }
                    
                    if data != nil, data!.count > 0 {
                        // Handling RP-initiated logout errors
                        print("RP-initiated logout response: \(String(describing: String(data: data!, encoding: .utf8)))")
                    }
                }
            }
        }
        
        appAuthManager.setAuthState(nil)
    }
    
    // MARK: - Send data to server
    
    func sendQRToServer(messageLabel:UILabel, qrString: String) {
        let currentAccessToken: String? = appAuthManager.authState?.lastTokenResponse?.accessToken
        
        appAuthManager.authState?.performAction() {
            accessToken, idToken, error in
            
            if error != nil {
                print("Error fetching fresh tokens: \(error?.localizedDescription ?? "")")
                
                return
            }
            
            guard let accessToken = accessToken else {
                print("Error getting accessToken")
                
                return
            }
            
            if currentAccessToken != accessToken {
                print("Access token was refreshed automatically (\(currentAccessToken ?? "none") to \(accessToken))")
            } else {
                print("Access token was fresh and not updated \(accessToken)")
            }
            
            guard let url = URL(string: self.apiUrl!) else { return }
            
            self.restManager.requestHttpHeaders.add(value: "application/json", forKey: "Content-Type")
            self.restManager.requestHttpHeaders.add(value: "Bearer " + accessToken, forKey: "Authorization")
            self.restManager.httpBodyParameters.add(value: qrString, forKey: "Data")
            
            // If id is empty just send data.
            if let id = self.id {
                self.restManager.httpBodyParameters.add(value: id, forKey: "Id")
            }
            
            self.restManager.makeRequest(toURL: url, withHttpMethod: .post) { (results) in
                guard let response = results.response else {
                    print("couldn't send data")
                    return
                }
                
                var message: String
                print(response.httpStatusCode)
                
                if response.httpStatusCode == 200 {
                    message = qrString
                } else {
                    message = "Server Error"
                    self.playSound(sound: "error")
                }
                
                // Write to message field
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    messageLabel.text = message
                }
            }
        }
    }
    
    // MARK: - Audio played during scan
    
    func playSound(sound: String) {
        do {
            if (sound == "error") {
                self.audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: self.errorBeepFile!))
                self.audioPlayer?.play()
            } else {
                self.clickPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: self.cameraClickFile!))
                self.clickPlayer?.play()
            }
        } catch let error {
            print("Can't play the audio file failed with an error \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings properties
    
    var apiUrl: String? {
        get {
            return fetchSetting(key: defaultsKeys.apiUrl)
        }
        
        set(newUrl) {
            saveSetting(value: newUrl, key: defaultsKeys.apiUrl)
        }
    }
    
    var authUrl: String? {
        get {
            return fetchSetting(key: defaultsKeys.authUrl)
        }
        
        set(newUrl) {
            saveSetting(value: newUrl, key: defaultsKeys.authUrl)
        }
    }
    var id: String? {
        get {
            return fetchSetting(key: defaultsKeys.id)
        }
        
        set(newId) {
            saveSetting(value: newId, key: defaultsKeys.id)
        }
    }
    
    func fetchSetting(key: String) -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: key)
    }
    
    func saveSetting(value: String?, key: String) {
        let defaults = UserDefaults.standard
        
        // TODO: check for valid values.
        if  value == nil || value == "" {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(value, forKey: key)
        }
    }
}
