

import Foundation

public enum WebError<CustomError>: Error {
    case noInternetConnection
    case custom(CustomError)
    case unauthorized
    case other
    
    func getMessage() -> String {
        switch self {
        case .custom(let errort):
            return "Something went wrong!"
        case .noInternetConnection:
            return "No internet Connection!"
        case .unauthorized:
            return "Not authorized to access!"
        case .other:
            return "Something went wrong!"
        }
    }
}
