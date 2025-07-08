import Foundation

struct UserData {
    let fullName: String
    let username: String
    let email: String
    let profileImageUrl: String?
    
    init(fullName: String, username: String, email: String, profileImageUrl: String? = nil) {
        self.fullName = fullName
        self.username = username
        self.email = email
        self.profileImageUrl = profileImageUrl
    }
} 