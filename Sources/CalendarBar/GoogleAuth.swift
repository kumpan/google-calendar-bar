import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// No disk cache: calendar data and tokens never land on disk.
let googleSession = URLSession(configuration: .ephemeral)

/// Google sign-in for one or more accounts: OAuth 2.0 with PKCE through an "iOS" type client, which
/// needs no client secret. Refresh tokens live in the login keychain, keyed by email; access tokens only
/// in memory.
@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuth()

    /// OAuth client (type iOS, bundle id se.kumpan.calendarbar) in Kumpan's Google Cloud project; see
    /// README → For developers. Not a secret.
    nonisolated static let clientID = "285701156236-ircceb8m5glc8pnsd1pa3ej4ov0sunqs.apps.googleusercontent.com"
    nonisolated static var isConfigured: Bool { !clientID.hasPrefix("REPLACE_ME") }
    /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
    nonisolated static var callbackScheme: String { clientID.split(separator: ".").reversed().joined(separator: ".") }
    nonisolated static var redirectURI: String { "\(callbackScheme):/oauth2redirect" }
    /// The narrowest scopes for what the app reads: the calendar list and events.
    static let calendarScopes = ["https://www.googleapis.com/auth/calendar.calendarlist.readonly",
                                 "https://www.googleapis.com/auth/calendar.events.readonly"]
    static let scope = (["openid", "email"] + calendarScopes).joined(separator: " ")

    enum AuthError: LocalizedError {
        case signedOut(String), noCalendarAccess(String), cancelled
        var errorDescription: String? {
            switch self {
            case .signedOut(let account): "\(account) was signed out. Add it again in Settings."
            // Google's consent screen has a checkbox per permission, and this one isn't ticked by default.
            case .noCalendarAccess(let account):
                "\(account) didn't give CalendarBar access to its calendars. Add it again and tick both calendar permissions on Google's screen."
            case .cancelled: "Sign-in cancelled."
            }
        }
    }

    private var tokens: [String: (value: String, expiresAt: Date)] = [:]
    private var session: ASWebAuthenticationSession?

    /// Signed-in accounts (emails), oldest first.
    var accounts: [String] { Keychain.accounts() }

    /// Signs in to a Google account and returns its email. Signing in again replaces its token.
    @discardableResult
    func signIn() async throws -> String {
        let verifier = Self.randomString(), state = Self.randomString()
        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: Data(SHA256.hash(data: Data(verifier.utf8))).base64URL),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account consent"), // consent → always a fresh refresh token
        ]
        defer { session = nil }
        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: c.url!, callback: .customScheme(Self.callbackScheme)) { url, error in
                if let url { return cont.resume(returning: url) }
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                cont.resume(throwing: cancelled ? AuthError.cancelled : error ?? AuthError.cancelled)
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() { cont.resume(throwing: AppError("Couldn't open the Google sign-in page.")) }
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == state, let code = value("code") else {
            throw AppError("Google sign-in failed (\(value("error") ?? "no code")).")
        }
        let token = try await requestToken(["client_id": Self.clientID, "code": code, "code_verifier": verifier,
                                            "grant_type": "authorization_code", "redirect_uri": Self.redirectURI])
        guard let refresh = token.refresh_token, let access = token.access_token,
              let account = token.id_token.flatMap(Self.email(fromIDToken:)) else { throw Self.failure(token) }
        let granted = Set((token.scope ?? "").split(separator: " ").map(String.init))
        guard Self.calendarScopes.allSatisfy(granted.contains) else {
            Self.revoke(refresh)
            throw AuthError.noCalendarAccess(account)
        }
        Keychain.save(refresh, for: account)
        tokens[account] = (access, Date().addingTimeInterval(token.expires_in ?? 3600))
        return account
    }

    func accessToken(for account: String) async throws -> String {
        if let token = tokens[account], token.expiresAt > Date().addingTimeInterval(60) { return token.value }
        guard let refresh = Keychain.read(account) else { throw AuthError.signedOut(account) }
        let token = try await requestToken(["client_id": Self.clientID, "refresh_token": refresh, "grant_type": "refresh_token"])
        if token.error == "invalid_grant" { // revoked, or the password changed
            Keychain.delete(account)
            throw AuthError.signedOut(account)
        }
        guard let access = token.access_token else { throw Self.failure(token) }
        tokens[account] = (access, Date().addingTimeInterval(token.expires_in ?? 3600))
        return access
    }

    /// After a 401: the next call fetches a new access token.
    func dropAccessToken(for account: String) { tokens[account] = nil }

    func signOut(_ account: String) {
        if let refresh = Keychain.read(account) { Self.revoke(refresh) }
        Keychain.delete(account)
        tokens[account] = nil
    }

    /// Best effort: the token is forgotten locally either way.
    private static func revoke(_ token: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        request.httpMethod = "POST"
        request.httpBody = form(["token": token])
        googleSession.dataTask(with: request).resume()
    }

    /// The `email` claim of an ID token. No signature check needed: it came straight from Google over TLS.
    nonisolated static func email(fromIDToken jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return claims["email"] as? String
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    }

    private struct TokenResponse: Decodable {
        let access_token: String?, expires_in: Double?, refresh_token: String?, id_token: String?, scope: String?
        let error: String?, error_description: String?
    }

    private func requestToken(_ params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form(params)
        let (data, _) = try await googleSession.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func failure(_ token: TokenResponse) -> AppError {
        AppError("Google sign-in failed: \(token.error_description ?? token.error ?? "no token returned").")
    }

    private static func form(_ params: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(params.map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: allowed)!)" }
            .joined(separator: "&").utf8)
    }

    private static func randomString() -> String {
        Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64URL
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Google refresh tokens in the login keychain, one item per account email.
private enum Keychain {
    static let service: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                         kSecAttrService as String: "CalendarBar"]

    static func query(_ account: String) -> [String: Any] {
        service.merging([kSecAttrAccount as String: account]) { $1 }
    }

    /// Attributes only, so listing never prompts for keychain access.
    static func accounts() -> [String] {
        var q = service
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        q[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        func created(_ item: [String: Any]) -> Date { item[kSecAttrCreationDate as String] as? Date ?? .distantPast }
        return items.sorted { created($0) < created($1) }.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ value: String, for account: String) {
        delete(account)
        var q = query(account)
        q[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}
