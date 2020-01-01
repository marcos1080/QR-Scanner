//
//  AppAuthManager.swift
//  QR Scanner
//
//  Modified by Mark Stuart on 10/11/19.
//  Modified from code sourced from https://developer.forgerock.com/docs/platform/how-tos/implementing-oauth-20-authorization-code-grant-protected-pkce-appauth-sdk-ios#simple
//  Originally created by Konstantine Lapine
//

import Foundation
import AppAuth

class AppAuthManager: NSObject {
    /**
     OAuth 2 client ID.
     
     Dynamic client registration is not demonstrated in this example.
     */
    let clientId: String
    
    /**
     Scheme used in the redirection URI.
     
     This value is provided separately so that its presence in `Info.plist` can be easily checked and so that it can be reused with different redirection URIs.
     */
    let redirectionUriScheme: String
    let redirectionUriEndpoint: String
    
    /**
     OAuth 2 redirection URI for the client.
     
     The redirection URI is provided as a computed property, so that it can refer to the class' instance properties.
     */
    var redirectionUri: String {
        return redirectionUriScheme + redirectionUriEndpoint
    }
    
    /**
     Class property to store the authorization state.
     */
    var authState: OIDAuthState?
    
    /**
     The key under which the authorization state will be saved in a keyed archive.
     */
    let authStateKey: String
    
    /**
     OpenID Connect issuer URL, where the OpenID configuration can be obtained from.
     */
    var issuerUrl: String?
    
    // defines the scopes to request the token for.
    let scopes: [String]
    
    init(clientId: String, redirectionUriScheme: String, redirectionUriEndpoint: String, authStateKey: String, scopes: [String]) {
        self.clientId = clientId
        self.redirectionUriScheme = redirectionUriScheme
        self.redirectionUriEndpoint = redirectionUriEndpoint
        self.authStateKey = authStateKey
        self.issuerUrl = nil
        self.scopes = scopes + [OIDScopeOpenID, OIDScopeProfile]
    }
}

// MARK: OIDC Provider configuration
extension AppAuthManager {
    /**
     Returns OIDC Provider configuration.
     
     In this method the OP's endpoints are retrieved from the issuer's well-known OIDC configuration document location (asynchronously). The response is handled then with the passed in escaping callback.
     */
    func discoverOIDServiceConfiguration(_ issuerUrl: String, completion: @escaping (OIDServiceConfiguration?, Error?) -> Void) {
        // Checking if the issuer's URL can be constructed.
        guard let issuer = URL(string: issuerUrl) else {
            print("Error creating issuer URL for: \(issuerUrl)")
            
            return
        }
        
        print("Retrieving configuration for: \(issuer.absoluteURL)")
        
        // Discovering endpoints with AppAuth's convenience method.
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) {
            configuration, error in
            
            // Completing with the caller's callback.
            completion(configuration, error)
        }
    }
}

// MARK: Authorization methods
extension AppAuthManager {
    /**
     Performs the authorization code flow.
     
     Attempts to perform a request to authorization endpoint by utilizing AppAuth's convenience method.
     Completes authorization code flow with automatic code exchange.
     The response is then passed to the completion handler, which lets the caller to handle the results.
     */
    func authorizeWithAutoCodeExchange(
        view: UIViewController,
        configuration: OIDServiceConfiguration,
        clientId: String,
        redirectionUri: String,
        scopes: [String],
        completion: @escaping (OIDAuthState?, Error?) -> Void
        ) {
        // Checking if the redirection URL can be constructed.
        guard let redirectURI = URL(string: redirectionUri) else {
            print("Error creating redirection URL for : \(redirectionUri)")
            
            return
        }
        
        // Checking if the AppDelegate property holding the authorization session could be accessed
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("Error accessing AppDelegate")
            
            return
        }
        
        // Building authorization request.
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientId,
            clientSecret: nil,
            scopes: scopes,
            redirectURL: redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: ["prompt":"login"]
        )
        
        // Making authorization request.
        
        print("Initiating authorization request with scopes: \(request.scope ?? "no scope requested")")
        
        if #available(iOS 11, *) {
            appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) {
                authState, error in
                
                completion(authState, error)
            }
        } else {
            appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: view) {
                authState, error in
                
                completion(authState, error)
            }
        }
    }
    
    /**
     Authorizes the Relying Party with an OIDC Provider.
     
     - Parameter issuerUrl: The OP's `issuer` URL to use for OpenID configuration discovery
     - Parameter configuration: Ready to go OIDServiceConfiguration object populated with the OP's endpoints
     - Parameter completion: (Optional) Completion handler to execute after successful authorization.
     */
    func authorizeRp(view: UIViewController, issuerUrl: String?, configuration: OIDServiceConfiguration?, completion: (() -> Void)? = nil) {
        /**
         Performs authorization with an OIDC Provider configuration.
         
         A nested function to complete the authorization process after the OP's configuration has became available.
         
         - Parameter configuration: Ready to go OIDServiceConfiguration object populated with the OP's endpoints
         */
        func authorize(view: UIViewController, configuration: OIDServiceConfiguration) {
            print("Authorizing with configuration: \(configuration)")
            
            self.authorizeWithAutoCodeExchange(
                view: view,
                configuration: configuration,
                clientId: self.clientId,
                redirectionUri: self.redirectionUri,
                scopes: self.scopes
            ) {
                authState, error in
                
                if let authState = authState {
                    self.setAuthState(authState)
                    
                    print("Successful authorization.")
                    
                    self.showState()
                    
                    if let completion = completion {
                        completion()
                    }
                } else {
                    print("Authorization error: \(error?.localizedDescription ?? "")")
                    
                    self.setAuthState(nil)
                }
            }
        }
        
        if let issuerUrl = issuerUrl {
            // Discovering OP configuration
            discoverOIDServiceConfiguration(issuerUrl) {
                configuration, error in
                
                guard let configuration = configuration else {
                    print("Error retrieving discovery document for \(issuerUrl): \(error?.localizedDescription ?? "")")
                    
                    self.setAuthState(nil)
                    
                    return
                }
                
                authorize(view: view, configuration: configuration)
            }
        } else if let configuration = configuration {
            // Accepting passed-in OP configuration
            authorize(view: view, configuration: configuration)
        }
    }
}

// MARK: OIDAuthState methods
extension AppAuthManager {
    /**
     Saves authorization state in a storage.
     
     As an example, the user's defaults database serves as the persistent storage.
     */
    func saveState() {
        var data: Data? = nil
        
        if let authState = self.authState {
            if #available(iOS 12.0, *) {
                data = try! NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: false)
            } else {
                data = NSKeyedArchiver.archivedData(withRootObject: authState)
            }
        }
        
        UserDefaults.standard.set(data, forKey: authStateKey)
        UserDefaults.standard.synchronize()
        
        print("Authorization state has been saved.")
        self.showState()
    }
    
    /**
     Reacts on authorization state changes events.
     */
    func stateChanged() {
        self.saveState()
    }
    
    /**
     Assigns the passed in authorization state to the class property.
     Assigns this controller to the state delegate property.
     */
    func setAuthState(_ authState: OIDAuthState?) {
        if (self.authState != authState) {
            self.authState = authState
            
            self.authState?.stateChangeDelegate = self
            
            self.stateChanged()
        }
    }
    
    /**
     Loads authorization state from a storage.
     
     As an example, the user's defaults database serves as the persistent storage.
     */
    func loadState() {
        guard let data = UserDefaults.standard.object(forKey: authStateKey) as? Data else {
            return
        }
        
        var authState: OIDAuthState? = nil
        
        if #available(iOS 12.0, *) {
            authState = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? OIDAuthState
        } else {
            authState = NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState
        }
        
        if let authState = authState {
            print("Authorization state has been loaded.")
            
            self.setAuthState(authState)
        }
    }
    
    /**
     Displays selected information from the current authorization data.
     */
    func showState() {
        print("Current authorization state: ")
        
        print("Access token: \(authState?.lastTokenResponse?.accessToken ?? "none")")
        
        print("ID token: \(authState?.lastTokenResponse?.idToken ?? "none")")
        
        print("Expiration date: \(String(describing: authState?.lastTokenResponse?.accessTokenExpirationDate))")
    }
}

// MARK: OIDAuthState delegates
extension AppAuthManager: OIDAuthStateChangeDelegate {
    /**
     Responds to authorization state changes in the AppAuth library.
     */
    func didChange(_ state: OIDAuthState) {
        print("Authorization state change event.")
        
        self.stateChanged()
    }
}

extension AppAuthManager: OIDAuthStateErrorDelegate {
    /**
     Reports authorization errors in the AppAuth library.
     */
    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        print("Received authorization error: \(error)")
    }
}

extension AppAuthManager {
    func sendUrlRequest(urlRequest: URLRequest, completion: @escaping (Data?, HTTPURLResponse, URLRequest) -> Void) {
        print(urlRequest)
        let task = URLSession.shared.dataTask(with: urlRequest) {
            data, response, error in
            
            DispatchQueue.main.async {
                guard error == nil else {
                    // Handling transport error
                    print("HTTP request failed \(error?.localizedDescription ?? "")")
                    
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    // Expecting HTTP response
                    print("Non-HTTP response")
                    
                    return
                }
                
                completion(data, response, urlRequest)
            }
        }
        
        task.resume()
    }
}
