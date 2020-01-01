# QR-Scanner
IOS 9 QR scanner in swift

This is a basic prototype to scan a QR code then send that data to a RESTful API.

It uses OAuth2.0 to handle authorization with the API. In my case I used IdentityServer4 to log in and request the access token required for API access.

These 3 tutorials contain the main elements for this prototype.

QR scanning:
  Simon Ng
  https://www.appcoda.com/barcode-reader-swift/
  
REST API communication:
  Gabriel Theodoropoulos
  https://www.appcoda.com/restful-api-library-swift/
  
OAuth authentication and authorization:
  Konstantin Lapine
  https://developer.forgerock.com/docs/platform/how-tos/implementing-oauth-20-authorization-code-grant-protected-pkce-appauth-sdk-ios
  

The following pods are needed:
  AppAuth
