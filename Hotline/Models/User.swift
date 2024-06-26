import SwiftUI

struct UserStatus: OptionSet {
  let rawValue: UInt

  static let idle = UserStatus(rawValue: 1 << 0)
  static let admin = UserStatus(rawValue: 1 << 1)
}

struct User: Identifiable {
  var id: UInt16
  var name: String
  var iconID: UInt
  var status: UserStatus
  
  var isAdmin: Bool { self.status.contains(.admin) }
  var isIdle: Bool { self.status.contains(.idle) }
  
  init(hotlineUser: HotlineUser) {
    var status: UserStatus = UserStatus()
    if hotlineUser.isIdle { status.update(with: .idle) }
    if hotlineUser.isAdmin { status.update(with: .admin) }
    
    self.id = hotlineUser.id
    self.name = hotlineUser.name
    self.iconID = UInt(hotlineUser.iconID)
    self.status = status
  }
  
  init(id: UInt16, name: String, iconID: UInt, status: UserStatus) {
    self.id = id
    self.name = name
    self.iconID = iconID
    self.status = status
  }
}
