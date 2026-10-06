import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// No disk cache: calendar data and tokens never land on disk.
let httpSession = URLSession(configuration: .ephemeral)

/// Where an account signs in. Both use OAuth 2.0 with PKCE through a public client, so there is no
/// client secret to ship.
enum Provider: String, CaseIterable {
    case google, microsoft

    var name: String { self == .google ? "Google" : "Microsoft" }

    /// Google: an "iOS" type OAuth client in Kumpan's Google Cloud project. Microsoft: an Entra ID app
    /// registration for work, school and personal accounts. Neither ID is a secret; see README.
    var clientID: String {
        switch self {
        case .google: "285701156236-ircceb8m5glc8pnsd1pa3ej4ov0sunqs.apps.googleusercontent.com"
        case .microsoft: "ffee141c-ab36-4d76-bc7a-f42ee8d43645"
        }
    }

    var isConfigured: Bool { !clientID.hasPrefix("REPLACE_ME") }

    var callbackScheme: String {
        switch self {
        // "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        case .google: clientID.split(separator: ".").reversed().joined(separator: ".")
        case .microsoft: "msauth.se.kumpan.calendarbar"
        }
    }

    var redirectURI: String { self == .google ? "\(callbackScheme):/oauth2redirect" : "\(callbackScheme)://auth" }

    var authorizeURL: URL {
        URL(string: self == .google ? "https://accounts.google.com/o/oauth2/v2/auth"
                                    : "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
    }

    var tokenURL: URL {
        URL(string: self == .google ? "https://oauth2.googleapis.com/token"
                                    : "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
    }

    /// The narrowest read-only scopes for what the app reads: the calendar list and events.
    var calendarScopes: [String] {
        switch self {
        case .google: ["https://www.googleapis.com/auth/calendar.calendarlist.readonly",
                       "https://www.googleapis.com/auth/calendar.events.readonly"]
        case .microsoft: ["https://graph.microsoft.com/Calendars.Read"]
        }
    }

    /// Microsoft only issues a refresh token for offline_access.
    var scope: String {
        (["openid", "email"] + (self == .microsoft ? ["offline_access"] : []) + calendarScopes).joined(separator: " ")
    }

    /// Google's "consent" makes every sign-in return a fresh refresh token.
    var prompt: String { self == .google ? "select_account consent" : "select_account" }

    /// Whether a token response's `scope` covers the calendar scopes. Microsoft lists Graph scopes without
    /// the resource prefix ("Calendars.Read").
    func grantsCalendar(_ scope: String?) -> Bool {
        let granted = Set((scope ?? "").split(separator: " ").map { $0.lowercased() })
        return calendarScopes.allSatisfy { s in
            granted.contains(s.lowercased()) || granted.contains(s.split(separator: "/").last!.lowercased())
        }
    }
}

/// Accounts are keychain keys. Google ones are the plain email (all early versions had), Microsoft ones are
/// prefixed, so one address can be signed in with both.
enum AccountKey {
    static func make(_ provider: Provider, _ email: String) -> String { provider == .google ? email : "microsoft:\(email)" }
    static func provider(_ key: String) -> Provider { key.hasPrefix("microsoft:") ? .microsoft : .google }
    static func email(_ key: String) -> String { key.hasPrefix("microsoft:") ? String(key.dropFirst(10)) : key }
}

/// Sign-in for one or more Google and Microsoft accounts. Refresh tokens live in the login keychain;
/// access tokens only in memory.
@MainActor
final class Auth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = Auth()

    enum AuthError: LocalizedError {
        case signedOut(String), noCalendarAccess(String), cancelled
        var errorDescription: String? {
            switch self {
            case .signedOut(let account): "\(AccountKey.email(account)) was signed out. Add it again in Settings."
            // Google's consent screen has a checkbox per permission, unticked by default.
            case .noCalendarAccess(let account):
                "\(AccountKey.email(account)) didn't give CalendarBar access to its calendars. Add it again and allow calendar access."
            case .cancelled: "Sign-in cancelled."
            }
        }
    }

    private var tokens: [String: (value: String, expiresAt: Date)] = [:]
    private var session: ASWebAuthenticationSession?

    /// Signed-in accounts, oldest first.
    var accounts: [String] { Keychain.accounts() }

    /// Signs in and returns the account key. Signing in again replaces its token.
    @discardableResult
    func signIn(_ provider: Provider) async throws -> String {
        let verifier = Self.randomString(), state = Self.randomString()
        var c = URLComponents(url: provider.authorizeURL, resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "client_id", value: provider.clientID),
            .init(name: "redirect_uri", value: provider.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: provider.scope),
            .init(name: "code_challenge", value: Data(SHA256.hash(data: Data(verifier.utf8))).base64URL),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: provider.prompt),
        ]
        defer { session = nil }
        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: c.url!, callback: .customScheme(provider.callbackScheme)) { url, error in
                if let url { return cont.resume(returning: url) }
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                cont.resume(throwing: cancelled ? AuthError.cancelled : error ?? AuthError.cancelled)
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() { cont.resume(throwing: AppError("Couldn't open the \(provider.name) sign-in page.")) }
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == state, let code = value("code") else {
            throw AppError("\(provider.name) sign-in failed (\(value("error_description") ?? value("error") ?? "no code")).")
        }
        let token = try await requestToken(provider, ["client_id": provider.clientID, "code": code, "code_verifier": verifier,
                                                      "grant_type": "authorization_code", "redirect_uri": provider.redirectURI])
        guard let refresh = token.refresh_token, let access = token.access_token,
              let email = token.id_token.flatMap(Self.email(fromIDToken:)) else { throw Self.failure(provider, token) }
        let account = AccountKey.make(provider, email)
        guard provider.grantsCalendar(token.scope) else {
            if provider == .google { Self.revoke(refresh) }
            throw AuthError.noCalendarAccess(account)
        }
        Keychain.save(refresh, for: account)
        tokens[account] = (access, Date().addingTimeInterval(token.expires_in ?? 3600))
        return account
    }

    func accessToken(for account: String) async throws -> String {
        if let token = tokens[account], token.expiresAt > Date().addingTimeInterval(60) { return token.value }
        guard let refresh = Keychain.read(account) else { throw AuthError.signedOut(account) }
        let provider = AccountKey.provider(account)
        var params = ["client_id": provider.clientID, "refresh_token": refresh, "grant_type": "refresh_token"]
        if provider == .microsoft { params["scope"] = provider.scope }
        let token = try await requestToken(provider, params)
        // Revoked or password changed; Microsoft also asks for interaction when an admin or MFA policy changes.
        if ["invalid_grant", "interaction_required"].contains(token.error) {
            Keychain.delete(account)
            throw AuthError.signedOut(account)
        }
        guard let access = token.access_token else { throw Self.failure(provider, token) }
        // Microsoft rotates refresh tokens: keep the newest.
        if let newRefresh = token.refresh_token, newRefresh != refresh { Keychain.save(newRefresh, for: account) }
        tokens[account] = (access, Date().addingTimeInterval(token.expires_in ?? 3600))
        return access
    }

    /// After a 401: the next call fetches a new access token.
    func dropAccessToken(for account: String) { tokens[account] = nil }

    /// Google can revoke a refresh token; Microsoft has no endpoint for that, so its token is just forgotten.
    func signOut(_ account: String) {
        if AccountKey.provider(account) == .google, let refresh = Keychain.read(account) { Self.revoke(refresh) }
        Keychain.delete(account)
        tokens[account] = nil
    }

    /// Best effort: the token is forgotten locally either way.
    private static func revoke(_ token: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        request.httpMethod = "POST"
        request.httpBody = form(["token": token])
        httpSession.dataTask(with: request).resume()
    }

    /// The email in an ID token: `email`, or Microsoft's `preferred_username` when there is none. No signature
    /// check needed: it came straight from the provider over TLS.
    nonisolated static func email(fromIDToken jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return (claims["email"] ?? claims["preferred_username"]) as? String
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    }

    private struct TokenResponse: Decodable {
        let access_token: String?, expires_in: Double?, refresh_token: String?, id_token: String?, scope: String?
        let error: String?, error_description: String?
    }

    private func requestToken(_ provider: Provider, _ params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: provider.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form(params)
        let (data, _) = try await httpSession.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func failure(_ provider: Provider, _ token: TokenResponse) -> AppError {
        AppError("\(provider.name) sign-in failed: \(token.error_description ?? token.error ?? "no token returned").")
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

private struct APIFailure: Decodable {
    struct Body: Decodable { let message: String }
    let error: Body
}

/// GETs JSON as `account`. Google Calendar and Microsoft Graph report errors the same way.
func apiGet<T: Decodable>(_ type: T.Type, _ url: URL, account: String, headers: [String: String] = [:]) async throws -> T {
    let token = try await Auth.shared.accessToken(for: account)
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    let (data, response) = try await httpSession.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
        if status == 401 { await Auth.shared.dropAccessToken(for: account) }
        let message = (try? JSONDecoder().decode(APIFailure.self, from: data))?.error.message
            ?? "\(AccountKey.provider(account).name) calendar error \(status)."
        if message.contains("insufficient authentication scopes") { // Google: signed in without ticking calendar access
            await Auth.shared.signOut(account)
            throw Auth.AuthError.noCalendarAccess(account)
        }
        throw AppError(message)
    }
    return try JSONDecoder().decode(T.self, from: data)
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Refresh tokens in the login keychain, one item per account key.
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

    /// Updates in place when the item exists, so a rotated refresh token keeps the account's place in the list.
    static func save(_ value: String, for account: String) {
        let data = Data(value.utf8)
        if SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var q = query(account)
            q[kSecValueData as String] = data
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}
