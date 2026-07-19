//
//  Bundle-Decodable.swift
//
//  Created by Filippo Cilia.
//

import SwiftUI

// EXTENSION ON BUNDLE
// load JSON from a BUNDLE; FIND > OPEN > DECODE > RETURN
extension Bundle {
    func decode<T: Decodable>(_ type: T.Type, from file: String, dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) -> T {

        guard let url = self.url(forResource: file, withExtension: nil) else {
            print("Error: Failed to locate \(file) in bundle.")
            // Return empty array/default value based on type
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to locate \(file) in bundle and unable to provide default value")
        }

        guard let data = try? Data(contentsOf: url) else {
            print("Error: Failed to load \(file) from bundle.")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to load \(file) from bundle and unable to provide default value")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy

        do {
            return try decoder.decode(T.self, from: data)

        } catch DecodingError.keyNotFound(let key, let context) {
            print("Error: Failed to decode \(file) from bundle due to missing key '\(key.stringValue)' - \(context.debugDescription)")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to decode \(file) and unable to provide default value")

        } catch DecodingError.typeMismatch(_, let context) {
            print("Error: Failed to decode \(file) from bundle due to type mismatch - \(context.debugDescription)")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to decode \(file) and unable to provide default value")

        } catch DecodingError.valueNotFound(let type, let context) {
            print("Error: Failed to decode \(file) from bundle due to missing \(type) value – \(context.debugDescription)")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to decode \(file) and unable to provide default value")

        }catch DecodingError.dataCorrupted(_) {
            print("Error: Failed to decode \(file) from bundle because it appears to be invalid JSON")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to decode \(file) and unable to provide default value")

        } catch {
            print("Error: Failed to decode \(file) from bundle: \(error.localizedDescription)")
            if let emptyArray = [Any]() as? T {
                return emptyArray
            }
            preconditionFailure("Failed to decode \(file) and unable to provide default value")
        }
    }
}
