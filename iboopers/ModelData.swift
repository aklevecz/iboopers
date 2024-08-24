//
//  ModelData.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/4/24.
//

import Foundation


enum EggError: Error {
    case alreadyExists
}

@Observable
class ModelData {
    var collection: [Egg] = load("eggs")
    var eggMap: [String: Egg] = [:]
    
    init() {
        updateEggMap()
    }
        
    func updateEggMap() {
        // eggMap = Dictionary(uniqueKeysWithValues: collection.map { ($0.id, $0) })
        // eggMap = ["egglin": Egg(id: "egglin", name: "Egglin", description: "Egglin is absolutely the best", isFound: true)]
    }
    
    func save() async throws {
        let task = Task {
            let data = try JSONEncoder().encode(collection)
            let file = try FileManager.default
                        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent("eggs.json")
            try data.write(to: file)
        }
        _ = try await task.value
    }
    
    func addEgg(egg: Egg) throws {
        if !collection.contains(where: { $0.id == egg.id }) {
            collection.append(egg)
        } else {
            throw EggError.alreadyExists
        }
    }
    
    func getEgg(by id: String) -> Egg? {
        return eggMap[id]
    }

}


func load<T: Decodable>(_ filename: String) -> T {
    print("Loading data")
    // resetData("eggs")
    let data: Data
    
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let fileURL = documentDirectory.appendingPathComponent("\(filename).json")
    
    if !FileManager.default.fileExists(atPath: fileURL.path) {
        // File doesn't exist in Documents directory, copy from bundle
        guard let bundleURL = Bundle.main.url(forResource: filename, withExtension: "json") else {
            fatalError("Couldn't find \(filename) in main bundle.")
        }
        
        do {
            try FileManager.default.copyItem(at: bundleURL, to: fileURL)
        } catch {
            fatalError("Couldn't copy \(filename) to Documents directory: \(error)")
        }
    }
    
    do {
        data = try Data(contentsOf: fileURL)
    } catch {
        fatalError("Couldn't load \(filename) from Documents directory: \(error)")
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self): \(error)")
    }
}

func resetData(_ filename: String) {
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let fileURL = documentDirectory.appendingPathComponent("\(filename).json")
    
    // Load default data from your app bundle
    guard let defaultDataURL = Bundle.main.url(forResource: filename, withExtension: "json"),
          let defaultData = try? Data(contentsOf: defaultDataURL) else {
        print("Error: Default data not found")
        return
    }
    
    do {
        try defaultData.write(to: fileURL)
        print("Data reset successfully")
    } catch {
        print("Error resetting data: \(error)")
    }
}
