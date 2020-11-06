//
//  Parser.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

final class Parser {
    enum ParserError: Error {
        case characterMismatch(expected: Character, found: Character)
        case tokenMismatch(expected: String, found: String)
        case invalid
    }

    let string: String
    private var position = 0

    private let whitespace = " "
    private let identifier = "abcdefghijklmnopqrstuvwxyz_"
    private let integer = "-0123456789"
    private let number = "-0123456789."

    init(string: String) {
        self.string = string
    }

    private var lookupChar: Character {
        guard position < string.count else {
            return "\0"
        }
        return string[string.index(string.startIndex, offsetBy: position)]
    }

    private func nextChar() -> Character {
        let char = lookupChar
        position += 1
        return char
    }

    private func skipWhite() {
        while whitespace.contains(lookupChar) { _ = nextChar() }
    }

    private func match(_ character: Character) throws {
        guard character == lookupChar else {
            throw ParserError.characterMismatch(expected: character, found: lookupChar)
        }
        _ = nextChar()
    }

    private func skipWhiteAndMatch(_ character: Character) throws {
        skipWhite()
        try match(character)
        skipWhite()
    }

    func parseToken() -> String {
         var token = ""
         while identifier.contains(lookupChar) {
             token += String(nextChar())
         }
         skipWhite()

         return token
    }

    func match(token: String) throws {
        let parsedToken = parseToken()
        guard parsedToken == token else {
            throw ParserError.tokenMismatch(expected: token, found: parsedToken)
        }
    }

    func parseIntegerString() -> String {
        var token = ""
        while integer.contains(lookupChar) {
            token += String(nextChar())
        }
        skipWhite()
        return token
    }

    func parseInteger() throws -> Int {
        let integerString = parseIntegerString()
        guard let value = Int(integerString) else {
            throw ParserError.invalid
        }
        return value
    }

    func parseBool() throws -> Bool {
        try parseInteger() == 1
    }

    func parseNumberString() -> String {
        var token = ""
        while number.contains(lookupChar) {
            token += String(nextChar())
        }
        skipWhite()
        return token
    }

    func parseDouble() throws -> Double {
        let numberString = parseNumberString()
        guard let value = Double(numberString) else {
            throw ParserError.invalid
        }
        return value
    }

    func parseVector3() throws -> Vector3 {
        let x = try parseDouble()
        try skipWhiteAndMatch(",")
        let y = try parseDouble()
        try skipWhiteAndMatch(",")
        let z = try parseDouble()
        return Vector3(x: x, y: y, z: z)
    }

    func parseQuaternion() throws -> Quaternion {
        let x = try parseDouble()
        try skipWhiteAndMatch(",")
        let y = try parseDouble()
        try skipWhiteAndMatch(",")
        let z = try parseDouble()
        try skipWhiteAndMatch(",")
        let w = try parseDouble()
        return Quaternion(x: x, y: y, z: z, w: w)
    }
}
