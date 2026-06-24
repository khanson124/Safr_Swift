//
//  PasswordValidator.swift
//  Safr
//

import Foundation

enum PasswordValidator {
    static func validationMessage(for password: String) -> String? {
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        if password.range(of: "[A-Za-z]", options: .regularExpression) == nil {
            return "Password must contain at least one letter."
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            return "Password must contain at least one number."
        }
        return nil
    }

    static func passwordsMatch(_ password: String, _ confirmation: String) -> Bool {
        password == confirmation
    }
}
