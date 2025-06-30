//
//  EggManager.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/12/24.
//

import Foundation

@Observable
class EggManager {
    static let shared = EggManager()
    public var boops: [BoopD1] = []
    public var computedEggPoints = 0
    private var boopsCache: [BoopD1] = []
    private let cacheKey = "cachedBoops"
    private let cacheExpirationInterval: TimeInterval = 5 * 60 // 5 minutes
    private var lastFetchTime: Date?
    
    private init() {
        loadCacheFromUserDefaults()
    }
    
    private func loadCacheFromUserDefaults() {
        if let cachedBoops = loadFromLocalStorage() {
            boopsCache = cachedBoops
            computedEggPoints = calculateEggPoints(from: boopsCache)
            lastFetchTime = Date() // Assume it was just fetched when loading from cache
        } else {
            computedEggPoints = 0
        }
    }

    // is EggCollectedResponse and CollectedEggInfo response redundant?
    func collectEgg(message:String, signature:String) async throws -> CollectedEggInfo {
            // Maybe this is not actually authenticated? but might as well during a closed-ish beta
            guard let token = AuthenticationManager.shared.getToken() else {
//                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])
                throw AuthErrors.notAuthed
            }
            let domain = "boopers.yaytso.art"
            let url = URL(string: "https://\(domain)/egg/collect")!
            var request = URLRequest(url:url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = [
                "message":message,
                "signature":signature
            ]
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain:"ServerError", code:2, userInfo: [NSLocalizedDescriptionKey: "Failed to collect egg"])
            }
            let json = try JSONDecoder().decode(EggCollectResponse.self, from: data)
            print("Response:")
            print("  Is Verified: \(json.isVerified)")
            print("  Egg: \(json.egg)")
            print("  Message: \(json.message)")
            if !json.isVerified {
                print("THROWING INVALID EGG")
                throw EggErrors.invalidEgg
            }
        
            DispatchQueue.main.async {
                self.invalidateCache()
            }
        
            return CollectedEggInfo(egg: json.egg, message: json.message)
    }
    
    func getBoops() async throws -> BoopsResponse {
        print("Calling all boops")
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheExpirationInterval {
            return BoopsResponse(boops: boopsCache)
        }
        guard let token = AuthenticationManager.shared.getToken() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])
        }
        
        var request = URLRequest(url: URL(string:"https://boopers.yaytso.art/boops")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"])
        }
        let json = try JSONDecoder().decode(BoopsResponse.self, from: data)

        boopsCache = json.boops
        lastFetchTime = Date()
        saveToLocalStorage(boops: json.boops)
        
        computedEggPoints = calculateEggPoints(from: json.boops)
        print("points : \(computedEggPoints)")
        
        return BoopsResponse(boops: json.boops)
    }

    func invalidateCache() {
        boopsCache.removeAll()
        lastFetchTime = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func saveToLocalStorage(boops: [BoopD1]) {
        do {
            let data = try JSONEncoder().encode(boops)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to save boops to local storage: \(error)")
        }
    }
    
    private func loadFromLocalStorage() -> [BoopD1]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        do {
            return try JSONDecoder().decode([BoopD1].self, from: data)
        } catch {
            print("Failed to load boops from local storage: \(error)")
            return nil
        }
    }
    
    func calculateEggPoints(from boops: [BoopD1]) -> Int {
        var totalPoints = 0
        for boop in boops {
            let color = String(boop.id.split(separator: "-")[0])
            if let points = colorPoints[color] {
                totalPoints += points
            }
        }
        return totalPoints
    }
}


struct CollectedEggInfo {
    let egg: String
    let message: String
}

enum AuthErrors: Error {
    case notAuthed
    var localizedDescription: String {
        switch self {
        case .notAuthed:
            return "Well, nice job finding this egg, unfortunately I don't know who the hell you are. You'll have to find a Booper card to create a Booper account"
        }
    }
}

enum EggErrors: Error {
    case invalidEgg
    case invalidResponse
    var localizedDescription: String {
        switch self {
        case .invalidEgg:
            return "The egg is invalid. Please try again."
        case .invalidResponse:
            return "The response from the server was invalid."
        }
    }
}

struct BoopD1: Identifiable, Codable {
    let id: String
    let booperId: String
    let category: String
    let createdAt: String
}

struct BoopsResponse: Codable {
    let boops: [BoopD1]
}

struct EggCollectResponse: Codable {
    let isVerified: Bool
    let egg: String
    let message: String
}
