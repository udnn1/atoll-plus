/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit
import Combine
import CommonCrypto
import CryptoKit
import Defaults
import Foundation

struct ClaudeLimitUsage: Equatable {
    var five: Double?
    var fiveReset: String?
    var seven: Double?
    var sevenReset: String?
    var t: Double
}

@MainActor
final class ClaudeLimitService: ObservableObject {
    static let shared = ClaudeLimitService()

    static let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let tokenURL = URL(string: "https://api.anthropic.com/v1/oauth/token")!
    static let userAgent = "claude-cli/2.1.148 (external, cli)"
    static let betaHeader = "oauth-2025-04-20"
    static let intervalStart: Double = 120
    static let intervalMin: Double = 60
    static let intervalMax: Double = 900
    static let decreaseAfter = 5
    static let decreaseFactor = 0.85
    static let increaseFactor = 1.5
    static let pollIdle: Double = 900
    static let idleAfter: Double = 300
    static let rlMin: Double = 300
    static let rlMax: Double = 3600
    static let failBackoff: Double = 120
    static let manualGap: Double = 30
    static let staleAfter: Double = 1200
    static let wakeCheck: Double = 15
    static let bootWindow: Double = 90
    static let bootRetry: Double = 5

    @Published private(set) var usage: ClaudeLimitUsage?
    @Published private(set) var lastGood: ClaudeLimitUsage?
    @Published private(set) var nextAt: Date = Date()
    @Published private(set) var isRunning = false

    private var interval: Double = intervalStart
    private var lastRequest: Double = 0
    private var streak = 0
    private var fails = 0
    private var bootAt = Date()
    private var bootedOK = false
    private var loopTask: Task<Void, Never>?
    private var manualRequested = false
    private var cancellables = Set<AnyCancellable>()

    private let store = ClaudeLimitStore()

    private init() {
        Defaults.publisher(.enableLLMUsageFeature).sink { [weak self] change in
            Task { @MainActor in
                if change.newValue { self?.start() } else { self?.stop() }
            }
        }.store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
    }

    func start() {
        guard loopTask == nil else { return }
        let state = store.loadState()
        interval = min(max(state.interval, Self.intervalMin), Self.intervalMax)
        lastRequest = state.lastRequest
        streak = state.streak
        lastGood = state.lastGood
        fails = 0
        bootAt = Date()
        bootedOK = false
        nextAt = Date(timeIntervalSince1970: max(Date().timeIntervalSince1970, lastRequest + interval))
        isRunning = true
        render()
        loopTask = Task { [weak self] in await self?.loop() }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
        usage = nil
    }

    func refreshNow() {
        manualRequested = true
    }

    var ageMinutes: Int? {
        guard let lastGood else { return nil }
        let age = Date().timeIntervalSince1970 - lastGood.t
        return age >= 60 ? Int(age / 60) : nil
    }

    private func render() {
        if let lastGood, Date().timeIntervalSince1970 - lastGood.t < Self.staleAfter {
            usage = lastGood
        } else {
            usage = nil
        }
    }

    private func loop() async {
        while !Task.isCancelled {
            let wait = nextAt.timeIntervalSinceNow
            if wait > 0 {
                let step = min(wait, Self.wakeCheck)
                let slept = await sleepOrManual(seconds: step)
                render()
                if Task.isCancelled { return }
                if !slept { continue }
                if Date().timeIntervalSince1970 - lastRequest < Self.manualGap { continue }
            }
            await poll()
        }
    }

    private func sleepOrManual(seconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if Task.isCancelled { return false }
            if manualRequested {
                manualRequested = false
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    private func poll() async {
        lastRequest = Date().timeIntervalSince1970
        let (fetched, retry) = await ClaudeLimitAPI.fetchUsage(store: store)
        var iv = interval
        let wait: Double
        if var u = fetched {
            fails = 0
            bootedOK = true
            u.t = Date().timeIntervalSince1970
            lastGood = u
            streak += 1
            if streak >= Self.decreaseAfter {
                iv = max(Self.intervalMin, (iv * Self.decreaseFactor).rounded(.down))
                streak = 0
            }
            wait = Self.idleSeconds() >= Self.idleAfter ? max(iv, Self.pollIdle) : iv
        } else if let retry {
            iv = min(Self.intervalMax, (iv * Self.increaseFactor).rounded(.down))
            streak = 0
            wait = min(max(retry, Self.rlMin, iv), Self.rlMax)
        } else {
            fails += 1
            if !bootedOK && Date().timeIntervalSince(bootAt) < Self.bootWindow {
                wait = Self.bootRetry
            } else {
                wait = min(Self.failBackoff * Double(fails), 600)
            }
        }
        interval = iv
        nextAt = Date().addingTimeInterval(wait)
        store.saveState(.init(interval: interval, lastRequest: lastRequest, lastGood: lastGood, streak: streak))
        render()
    }

    private static func idleSeconds() -> Double {
        let types: [CGEventType] = [.keyDown, .flagsChanged, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .leftMouseDragged]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "?" }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }

    static func resetText(_ iso: String?) -> String {
        guard let iso, let date = parseISO(iso) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "dziś o " + formatter.string(from: date)
        }
        formatter.dateFormat = "dd.MM.yyyy 'o' HH:mm"
        return formatter.string(from: date)
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm:ss" : "dd.MM HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func parseISO(_ text: String) -> Date? {
        let normalized = text.replacingOccurrences(of: "Z", with: "+00:00")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: normalized) { return date }
        let trimmed = normalized.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }

    static func levelColor(_ pct: Double?) -> NSColor {
        guard let pct else { return NSColor(srgbRed: 150 / 255, green: 150 / 255, blue: 150 / 255, alpha: 1) }
        if pct >= 90 { return NSColor(srgbRed: 231 / 255, green: 72 / 255, blue: 77 / 255, alpha: 1) }
        if pct >= 75 { return NSColor(srgbRed: 229 / 255, green: 99 / 255, blue: 30 / 255, alpha: 1) }
        if pct >= 50 { return NSColor(srgbRed: 232 / 255, green: 163 / 255, blue: 61 / 255, alpha: 1) }
        return NSColor(srgbRed: 48 / 255, green: 164 / 255, blue: 108 / 255, alpha: 1)
    }
}

struct ClaudeLimitState {
    var interval: Double
    var lastRequest: Double
    var lastGood: ClaudeLimitUsage?
    var streak: Int
}

struct ClaudeLimitToken {
    var token: String
    var refreshToken: String?
    var expiresAt: Double

    var json: [String: Any] {
        var out: [String: Any] = ["token": token, "expiresAt": expiresAt]
        if let refreshToken { out["refreshToken"] = refreshToken }
        return out
    }

    init(token: String, refreshToken: String?, expiresAt: Double) {
        self.token = token
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    init?(_ obj: [String: Any]) {
        guard let token = obj["token"] as? String, !token.isEmpty else { return nil }
        self.token = token
        self.refreshToken = obj["refreshToken"] as? String
        self.expiresAt = (obj["expiresAt"] as? NSNumber)?.doubleValue ?? 0
    }
}

final class ClaudeLimitStore: @unchecked Sendable {
    private let fm = FileManager.default
    private var cachedKey: Data?

    private var cacheDir: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ClaudeLimitTray")
    }
    private var statePath: URL { cacheDir.appendingPathComponent("state.json") }
    private var tokenPath: URL { cacheDir.appendingPathComponent("token.bin") }
    private var configPath: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude/config.json")
    }

    func loadState() -> ClaudeLimitState {
        var state = ClaudeLimitState(interval: ClaudeLimitService.intervalStart, lastRequest: 0, lastGood: nil, streak: 0)
        guard let data = try? Data(contentsOf: statePath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return state }
        if let v = (obj["interval"] as? NSNumber)?.doubleValue { state.interval = v }
        if let v = (obj["last_request"] as? NSNumber)?.doubleValue { state.lastRequest = v }
        if let v = (obj["streak"] as? NSNumber)?.intValue { state.streak = v }
        if let g = obj["last_good"] as? [String: Any], let t = (g["t"] as? NSNumber)?.doubleValue {
            state.lastGood = ClaudeLimitUsage(
                five: (g["five"] as? NSNumber)?.doubleValue,
                fiveReset: g["five_reset"] as? String,
                seven: (g["seven"] as? NSNumber)?.doubleValue,
                sevenReset: g["seven_reset"] as? String,
                t: t
            )
        }
        return state
    }

    func saveState(_ state: ClaudeLimitState) {
        var obj: [String: Any] = ["interval": Int(state.interval), "last_request": state.lastRequest, "streak": state.streak]
        if let g = state.lastGood {
            var good: [String: Any] = ["source": "api", "t": g.t]
            good["five"] = g.five ?? NSNull()
            good["five_reset"] = g.fiveReset ?? NSNull()
            good["seven"] = g.seven ?? NSNull()
            good["seven_reset"] = g.sevenReset ?? NSNull()
            obj["last_good"] = good
        } else {
            obj["last_good"] = NSNull()
        }
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            try? data.write(to: statePath, options: .atomic)
        }
    }

    func oscryptKey() -> Data? {
        if let cachedKey { return cachedKey }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-w", "-s", "Claude Safe Storage", "-a", "Claude Key"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let password = Data((String(data: output, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard !password.isEmpty else { return nil }
        var key = Data(count: 16)
        let salt = Data("saltysalt".utf8)
        let status = key.withUnsafeMutableBytes { keyBytes in
            password.withUnsafeBytes { pwBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwBytes.bindMemory(to: Int8.self).baseAddress, password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003,
                        keyBytes.bindMemory(to: UInt8.self).baseAddress, 16
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        cachedKey = key
        return key
    }

    private func oscryptDecrypt(_ value: String, key: Data) -> Data? {
        guard let raw = Data(base64Encoded: value), raw.count > 3, raw.prefix(3) == Data("v10".utf8) else { return nil }
        let cipher = raw.dropFirst(3)
        let iv = Data(repeating: 0x20, count: 16)
        var out = Data(count: cipher.count + kCCBlockSizeAES128)
        var outLength = 0
        let outCapacity = out.count
        let status = out.withUnsafeMutableBytes { outBytes in
            cipher.withUnsafeBytes { cBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { kBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                            kBytes.baseAddress, key.count, ivBytes.baseAddress,
                            cBytes.baseAddress, cipher.count,
                            outBytes.baseAddress, outCapacity, &outLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return out.prefix(outLength)
    }

    func desktopTokens() -> [ClaudeLimitToken] {
        guard let key = oscryptKey(),
              let data = try? Data(contentsOf: configPath),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var tokens: [ClaudeLimitToken] = []
        for field in ["oauth:tokenCacheV2", "oauth:tokenCache"] {
            guard let value = cfg[field] as? String,
                  let plain = oscryptDecrypt(value, key: key),
                  let entries = try? JSONSerialization.jsonObject(with: plain) as? [String: Any] else { continue }
            for (k, v) in entries where k.contains(ClaudeLimitService.oauthClientID) && k.contains("user:inference") {
                if let obj = v as? [String: Any], let token = ClaudeLimitToken(obj) { tokens.append(token) }
            }
        }
        return tokens
    }

    func readCache() -> ClaudeLimitToken? {
        guard let key = oscryptKey(), let data = try? Data(contentsOf: tokenPath), data.count > 28 else { return nil }
        guard let box = try? AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: data.prefix(12)),
                ciphertext: data.dropFirst(12).dropLast(16),
                tag: data.suffix(16)),
              let plain = try? AES.GCM.open(box, using: SymmetricKey(data: key)),
              let obj = try? JSONSerialization.jsonObject(with: plain) as? [String: Any] else { return nil }
        return ClaudeLimitToken(obj)
    }

    func writeCache(_ entry: ClaudeLimitToken) {
        guard let key = oscryptKey(),
              let plain = try? JSONSerialization.data(withJSONObject: entry.json),
              let box = try? AES.GCM.seal(plain, using: SymmetricKey(data: key)) else { return }
        var out = Data(box.nonce)
        out.append(box.ciphertext)
        out.append(box.tag)
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try? out.write(to: tokenPath, options: .atomic)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenPath.path)
    }
}

enum ClaudeLimitAPI {
    static func fetchUsage(store: ClaudeLimitStore) async -> (ClaudeLimitUsage?, Double?) {
        guard let entry = await bestToken(store: store) else { return (nil, nil) }
        var token = entry.token
        for attempt in 1...2 {
            var request = URLRequest(url: ClaudeLimitService.usageURL, timeoutInterval: 30)
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue(ClaudeLimitService.betaHeader, forHTTPHeaderField: "anthropic-beta")
            request.setValue(ClaudeLimitService.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { return (nil, nil) }
            if http.statusCode == 429 {
                let retry = Double(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 0
                return (nil, retry)
            }
            if http.statusCode == 401 && attempt == 1, let refreshToken = entry.refreshToken {
                guard let refreshed = await refresh(refreshToken) else { return (nil, nil) }
                store.writeCache(refreshed)
                token = refreshed.token
                continue
            }
            guard http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (nil, nil) }
            return (parse(obj), nil)
        }
        return (nil, nil)
    }

    private static func parse(_ obj: [String: Any]) -> ClaudeLimitUsage {
        let fh = obj["five_hour"] as? [String: Any] ?? [:]
        let sd = obj["seven_day"] as? [String: Any] ?? [:]
        return ClaudeLimitUsage(
            five: number(fh["utilization"]),
            fiveReset: fh["resets_at"] as? String,
            seven: number(sd["utilization"]),
            sevenReset: sd["resets_at"] as? String,
            t: Date().timeIntervalSince1970
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func bestToken(store: ClaudeLimitStore) async -> ClaudeLimitToken? {
        let now = Date().timeIntervalSince1970 * 1000
        var candidates = store.desktopTokens()
        if let cached = store.readCache() { candidates.append(cached) }
        let valid = candidates.filter { $0.expiresAt > now + 60000 }.sorted { $0.expiresAt > $1.expiresAt }
        if let best = valid.first { return best }
        for candidate in candidates.sorted(by: { $0.expiresAt > $1.expiresAt }) {
            if let refreshToken = candidate.refreshToken, let refreshed = await refresh(refreshToken) {
                store.writeCache(refreshed)
                return refreshed
            }
        }
        return candidates.first
    }

    private static func refresh(_ refreshToken: String) async -> ClaudeLimitToken? {
        var request = URLRequest(url: ClaudeLimitService.tokenURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ClaudeLimitService.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(ClaudeLimitService.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": ClaudeLimitService.oauthClientID
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String else { return nil }
        let expiresIn = (obj["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return ClaudeLimitToken(
            token: access,
            refreshToken: obj["refresh_token"] as? String ?? refreshToken,
            expiresAt: Date().timeIntervalSince1970 * 1000 + expiresIn * 1000
        )
    }
}
