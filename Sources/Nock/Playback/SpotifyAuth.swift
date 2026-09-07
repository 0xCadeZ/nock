import AppKit
import CryptoKit
import Foundation
import Network

@MainActor
final class SpotifyAuth: ObservableObject {
    static let redirectURI = "http://127.0.0.1:53821/callback"
    static let scopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-library-modify",
        "user-library-read"
    ].joined(separator: " ")

    @Published var isAuthorized = false
    @Published var statusText = "Not connected"
    @Published var isBusy = false

    private var clientID: String
    private var accessToken: String?
    private var refreshToken: String?
    private var expiry: Date = .distantPast
    private var listener: NWListener?
    private var verifier: String?

    init(clientID: String) {
        self.clientID = clientID
        refreshToken = Keychain.get(account: "spotify.refresh")
        accessToken = Keychain.get(account: "spotify.access")
        if let exp = Keychain.get(account: "spotify.expiry"), let t = TimeInterval(exp) {
            expiry = Date(timeIntervalSince1970: t)
        }
        isAuthorized = refreshToken != nil || (accessToken != nil && expiry > Date())
        if isAuthorized { statusText = "Connected" }
    }

    func updateClientID(_ id: String) {
        clientID = id
    }

    func connect() {
        guard !clientID.isEmpty else {
            statusText = "Add a Spotify Client ID in Settings first"
            return
        }
        isBusy = true
        let verifier = Self.randomString(length: 64)
        self.verifier = verifier
        let challenge = Self.challenge(for: verifier)
        let state = Self.randomString(length: 16)
        startServer(expectedState: state)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        isAuthorized = false
        statusText = "Not connected"
        Keychain.delete(account: "spotify.refresh")
        Keychain.delete(account: "spotify.access")
        Keychain.delete(account: "spotify.expiry")
    }

    func validAccessToken() async throws -> String {
        if let accessToken, expiry > Date().addingTimeInterval(30) {
            return accessToken
        }
        try await refresh()
        guard let accessToken else { throw AuthError.notAuthorized }
        return accessToken
    }

    func isSaved(trackID: String) async throws -> Bool {
        let token = try await validAccessToken()
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/tracks/contains?ids=\(trackID)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let flags = try JSONDecoder().decode([Bool].self, from: data)
        return flags.first ?? false
    }

    func setSaved(trackID: String, saved: Bool) async throws {
        let token = try await validAccessToken()
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/tracks?ids=\(trackID)")!)
        request.httpMethod = saved ? "PUT" : "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.requestFailed
        }
    }

    private func startServer(expectedState: String) {
        listener?.cancel()
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: 53821)
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                guard let data, let raw = String(data: data, encoding: .utf8) else { return }
                let first = raw.components(separatedBy: "\r\n").first ?? ""
                let path = first.components(separatedBy: " ").dropFirst().first ?? ""
                let comps = URLComponents(string: "http://127.0.0.1\(path)")
                let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value
                let state = comps?.queryItems?.first(where: { $0.name == "state" })?.value
                let body = "<html><body style='font-family:system-ui;background:#111;color:#eee;padding:40px'>Nock is connected. You can close this window.</body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                Task { @MainActor in
                    guard state == expectedState, let code else {
                        self?.statusText = "Authorization failed"
                        self?.isBusy = false
                        return
                    }
                    await self?.exchange(code: code)
                }
            }
        }
        listener?.start(queue: .global())
    }

    private func exchange(code: String) async {
        defer { isBusy = false; listener?.cancel(); listener = nil }
        guard let verifier else { return }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "code_verifier": verifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            store(token)
        } catch {
            statusText = "Token exchange failed"
        }
    }

    private func refresh() async throws {
        guard let refreshToken else { throw AuthError.notAuthorized }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        await MainActor.run { store(token) }
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.access_token
        if let refresh = token.refresh_token {
            refreshToken = refresh
            Keychain.set(refresh, account: "spotify.refresh")
        }
        expiry = Date().addingTimeInterval(TimeInterval(token.expires_in))
        Keychain.set(token.access_token, account: "spotify.access")
        Keychain.set(String(expiry.timeIntervalSince1970), account: "spotify.expiry")
        isAuthorized = true
        statusText = "Connected"
    }

    private static func randomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func challenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    enum AuthError: Error {
        case notAuthorized
        case requestFailed
    }

    private struct TokenResponse: Decodable {
        var access_token: String
        var token_type: String?
        var expires_in: Int
        var refresh_token: String?
        var scope: String?
    }
}
