import Foundation

struct HotlineServer: Identifiable, Hashable {
  let id = UUID()
  let address: String
  let port: UInt16
  let users: UInt16
  let name: String?
  let description: String?
  
  static func == (lhs: HotlineServer, rhs: HotlineServer) -> Bool {
    return lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

extension UInt32 {
  func decodeFromUInt32() -> String {
    let bytes = [
      UInt8((self >> 24) & 0xFF),
      UInt8((self >> 16) & 0xFF),
      UInt8((self >> 8) & 0xFF),
      UInt8(self & 0xFF)
    ]
    return String(bytes: bytes, encoding: .utf8) ?? ""
  }
}

struct HotlineNewsCategory: Identifiable, Hashable {
  let id = UUID()
  let type: UInt16
  let count: UInt16
  let name: String
  
  static func == (lhs: HotlineNewsCategory, rhs: HotlineNewsCategory) -> Bool {
    return lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
  
  init(type: UInt16, count: UInt16, name: String) {
    self.type = type
    self.count = count
    self.name = name
  }
  
  init(from data: Data) {
    self.type = data.readUInt16(at: 0)!
    
    if self.type == 2 {
      // Read bundle properties
      self.count = data.readUInt16(at: 2)!
      let (n, _) = data.readPString(at: 4)
      self.name = n!
    }
    else if self.type == 3 {
      // Read category properties
      self.count = data.readUInt16(at: 2)!
//      let guid = data.readUInt32(at: 4)!
//      print("CATEGORY GUID: \(guid)")
//      let addSN = data.readUInt32(at: 20)!
//      let removeSN = data.readUInt32(at: 24)!
      let (n, _) = data.readPString(at: 28)
      self.name = n!
    }
    else {
      self.count = 0
      self.name = ""
    }
  }
}


struct HotlineFile: Identifiable, Hashable {
  let id = UUID()
  let type: String
  let creator: String
  let fileSize: UInt32
  let name: String
  
  var isExpanded: Bool = false
  var files: [HotlineFile]? = nil
  
  let isFolder: Bool
  
  static func == (lhs: HotlineFile, rhs: HotlineFile) -> Bool {
    return lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
  
  init(type: String, creator: String, fileSize: UInt32, fileName: String) {
    self.type = type
    self.creator = creator
    self.fileSize = fileSize
    self.name = fileName
    
    self.isFolder = (self.type == "fldr")
  }
  
  init(from data: Data) {
    let typeRaw = data.readUInt32(at: 0)!
    let creatorRaw = data.readUInt32(at: 4)!
    
    self.type = typeRaw.decodeFromUInt32()
    self.creator = creatorRaw.decodeFromUInt32()
    self.fileSize = data.readUInt32(at: 8)!
    
    self.isFolder = (self.type == "fldr")
    
//    data.readUInt32(at: 12)! // reserved
//    let nameScript = data.readUInt16(at: 16)! // name script
    
    let nameLength = data.readUInt16(at: 18)!
    self.name = data.readString(at: 20, length: Int(nameLength))!
  }
}

struct HotlineUser: Identifiable, Hashable {
  let id: UInt16
  let iconID: UInt16
  let status: UInt16
  let name: String
  
  var isAdmin: Bool {
    return ((self.status & 0x0002) != 0)
  }
  
  var isIdle: Bool {
    return ((self.status & 0x0001) != 0)
  }
  
  static func == (lhs: HotlineUser, rhs: HotlineUser) -> Bool {
    return lhs.id == rhs.id
  }
  
  init(id: UInt16, iconID: UInt16, status: UInt16, name: String) {
    self.id = id
    self.iconID = iconID
    self.status = status
    self.name = name
  }
  
  init(from data: Data) {
    self.id = data.readUInt16(at: 0)!
    self.iconID = data.readUInt16(at: 2)!
    self.status = data.readUInt16(at: 4)!
    
    let userNameLength = Int(data.readUInt16(at: 6)!)
    self.name = data.readString(at: 8, length: userNameLength)!
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
  
  func encoded() -> Data {
    var data = Data()
    self.encode(to: &data)
    return data
  }
  
  func encode(to data: inout Data) {
    data.appendUInt16(self.id)
    data.appendUInt16(self.iconID)
    data.appendUInt16(self.status)
    
    let userNameData = name.data(using: .ascii, allowLossyConversion: true)!
    
    data.appendUInt16(UInt16(userNameData.count))
    data.append(userNameData)
  }
}

struct HotlineTransactionField {
  let type: HotlineTransactionFieldType
  let dataSize: UInt16
  let data: Data
  
  init(type: HotlineTransactionFieldType, dataSize: UInt16, data: Data) {
    self.type = type
    self.dataSize = dataSize
    self.data = data
  }
  
  init(type: HotlineTransactionFieldType, val: UInt8) {
    self.init(type: type, dataSize: UInt16(MemoryLayout<UInt8>.size), data: Data(val))
  }
  
  init(type: HotlineTransactionFieldType, val: UInt16) {
    self.init(type: type, dataSize: UInt16(MemoryLayout<UInt16>.size), data: Data(val))
  }
  
  init(type: HotlineTransactionFieldType, val: UInt32) {
    self.init(type: type, dataSize: UInt16(MemoryLayout<UInt32>.size), data: Data(val))
  }
  
  init(type: HotlineTransactionFieldType, string: String, encoding: String.Encoding = .ascii, encrypt: Bool = false) {
    var stringInput = string
    
    if encrypt {
      stringInput = String(string.utf8.map { char in
        Character(UnicodeScalar(0xFF - char))
      })
    }
    
    var stringData: Data?
    stringData = stringInput.data(using: encoding, allowLossyConversion: true)
    if stringData == nil {
      stringData = Data()
    }
    
    self.init(type: type, dataSize: UInt16(stringData!.count), data: stringData!)
  }
  
  init(type: HotlineTransactionFieldType, string: String, encrypt: Bool) {
    self.init(type: type, string: string, encoding: .ascii, encrypt: encrypt)
  }
  
  init(type: HotlineTransactionFieldType, path: String) {
    var components: [String] = []
    
    for component in path.components(separatedBy: "/") {
      if !component.isEmpty {
        components.append(component)
      }
    }
    
    self.init(type: type, pathComponents: components)
  }
  
  init(type: HotlineTransactionFieldType, pathComponents: [String]) {
    var pathData = Data()
    
    pathData.appendUInt16(UInt16(pathComponents.count))
    for name in pathComponents {
      pathData.appendUInt16(0)
      
      var nameData = name.data(using: .ascii, allowLossyConversion: true)
      if nameData == nil {
        nameData = Data()
      }
      
      pathData.appendUInt8(UInt8(nameData!.count))
      pathData.append(nameData!)
    }
    
    self.init(type: type, dataSize: UInt16(pathData.count), data: pathData)
  }

  func getUInt8() -> UInt8? {
    return self.data.readUInt8(at: 0)
  }
  
  func getUInt16() -> UInt16? {
    return self.data.readUInt16(at: 0)
  }
  
  func getUInt32() -> UInt32? {
    return self.data.readUInt32(at: 0)
  }
  
  func getInteger() -> Int? {
    switch(self.data.count) {
    case 1:
      if let val = self.getUInt8() {
        return Int(val)
      }
    case 2:
      if let val = self.getUInt16() {
        return Int(val)
      }
    case 4:
      if let val = self.getUInt32() {
        return Int(val)
      }
    default:
      break
    }
    
    return nil
  }
  
  func getString() -> String? {
    return String(data: self.data, encoding: .utf8) ?? String(data: self.data, encoding: .ascii)
  }
  
  func getUser() -> HotlineUser {
    return HotlineUser(from: self.data)
  }
  
  func getFile() -> HotlineFile {
    return HotlineFile(from: self.data)
  }
  
  func getNewsCategory() -> HotlineNewsCategory {
    return HotlineNewsCategory(from: self.data)
  }
}

struct HotlineTransaction {
  static let headerSize = 20
  static var sequenceID: UInt32 = 1
  
  static func nextID() -> UInt32 {
    HotlineTransaction.sequenceID += 1
    return HotlineTransaction.sequenceID
  }
  
  var flags: UInt8 = 0
  var isReply: UInt8 = 0
  var type: HotlineTransactionType
  var id: UInt32 = HotlineTransaction.nextID()
  var errorCode: UInt32 = 0
  var totalSize: UInt32 = UInt32(HotlineTransaction.headerSize)
  var dataSize: UInt32 = 0
  
  var fields: [HotlineTransactionField] = []
  
  init(type: HotlineTransactionType) {
    self.type = type
  }
  
  init(type: HotlineTransactionType, flags: UInt8, isReply: UInt8, id: UInt32, errorCode: UInt32, totalSize: UInt32, dataSize: UInt32) {
    self.type = type
    self.flags = flags
    self.isReply = isReply
    self.id = id
    self.errorCode = errorCode
    self.totalSize = totalSize
    self.dataSize = dataSize
  }
  
  mutating func setFieldUInt8(type: HotlineTransactionFieldType, val: UInt8) {
    self.fields.append(HotlineTransactionField(type: type, val: val))
  }
  
  mutating func setFieldUInt16(type: HotlineTransactionFieldType, val: UInt16) {
    self.fields.append(HotlineTransactionField(type: type, val: val))
  }
  
  mutating func setFieldUInt32(type: HotlineTransactionFieldType, val: UInt32) {
    self.fields.append(HotlineTransactionField(type: type, val: val))
  }
  
  mutating func setFieldEncodedString(type: HotlineTransactionFieldType, val: String) {
    self.fields.append(HotlineTransactionField(type: type, string: val, encrypt: true))
  }
  
  mutating func setFieldString(type: HotlineTransactionFieldType, val: String) {
    self.fields.append(HotlineTransactionField(type: type, string: val))
  }
  
  mutating func setFieldPath(type: HotlineTransactionFieldType, val: [String]) {
    self.fields.append(HotlineTransactionField(type: type, pathComponents: val))
  }
  
  func getField(type: HotlineTransactionFieldType) -> HotlineTransactionField? {
    return self.fields.first { p in
      p.type == type
    }
  }
  
  func getFieldList(type: HotlineTransactionFieldType) -> [HotlineTransactionField] {
    return self.fields.filter { p in
      p.type == type
    }
  }
  
  func encoded() -> Data {
    var data = Data()
    self.encode(to: &data)
    return data
  }
  
  func encode(to data: inout Data) {
    data.appendUInt8(self.flags)
    data.appendUInt8(self.isReply)
    data.appendUInt16(self.type.rawValue)
    data.appendUInt32(self.id)
    data.appendUInt32(self.errorCode)
    
    if self.fields.count > 0 {
      var fieldData = Data()
      fieldData.appendUInt16(UInt16(self.fields.count))
      for f in self.fields {
        fieldData.appendUInt16(f.type.rawValue)
        fieldData.appendUInt16(f.dataSize)
        fieldData.append(f.data)
      }
      
      data.appendUInt32(UInt32(fieldData.count))
      data.appendUInt32(UInt32(fieldData.count))
      data.append(fieldData)
    }
    else {
      data.appendUInt32(2)
      data.appendUInt32(2)
      data.appendUInt16(0)
    }
  }
}

enum HotlineTransactionFieldType: UInt16 {
  case errorText = 100 // String
  case data = 101 // String
  case userName = 102 // String
  case userID = 103 // Integer
  case userIconID = 104 // Integer
  case userLogin = 105 // Encoded string
  case userPassword = 106 // Encoded string
  case referenceNumber = 107 // Integer
  case transferSize = 108 // Integer
  case chatOptions = 109 // Integer
  case userAccess = 110 // 64-bit integer?
  case userAlias = 111 // ???
  case userFlags = 112 // Integer
  case options = 113 // 32-bit integer?
  case chatID = 114 // Integer
  case chatSubject = 115 // String
  case waitingCount = 116 // Integer
  case serverAgreement = 150 // ???
  case serverBanner = 151 // Data?
  case serverBannerType = 152 // Integer
  case serverBannerURL = 153 // String
  case noServerAgreement = 154 // Integer
  case versionNumber = 160 // Integer
  case communityBannerID = 161 // Integer
  case serverName = 162 // String
  case fileNameWithInfo = 200 // Data { type: 4, creator: 4, file size: 4, reserved: 4, name script: 2, name size: 2, name data: size }
  // TODO: Add file field types
  case quotingMessage = 214 // String?
  case automaticResponse = 215 // String
  case folderItemCount = 220 // Integer
  case userNameWithInfo = 300 // Data { user id: 2, icon id: 2, user flags: 2, user name size: 2, user name: size }
  case newsCategoryGUID = 319 // Data?
  case newsCategoryListData = 320 // Data { type: 1 (1 = folder, 10 = category, 255 = other), category name: rest }
  case newsArticleListData = 321 // Data
  case newsCategoryName = 322 // String
  case newsCategoryListData15 = 323 // Data
  case newsPath = 325 // Data
  case newsArticleID = 326 // Integer
  case newsArticleDataFlavor = 327 // String
  case newsArticleTitle = 328 // String
  case newsArticlePoster = 329 // String
  case newsArticleDate = 330 // Data { year: 2, ms: 2, secs: 4 }
  case newsArticlePrevious = 331 // Integer
  case newsArticleNext = 332 // Integer
  case newsArticleData = 333 // Data
  case newsArticleFlags = 334 // Integer
  case newsArticleParentArticle = 335 // Integer
  case newsArticleFirstChildArticle = 336 // Integer
  case newsArticleRecursiveDelete = 337 // Integer
}

enum HotlineTransactionType: UInt16 {
  case reply = 0
  case error = 100
  case getMessages = 101
  case newMessage = 102  // Server
  case oldPostNews = 103
  case serverMessage = 104 // Server
  case sendChat = 105
  case chatMessage = 106 // Server
  case login = 107
  case sendInstantMessage = 108
  case showAgreement = 109  // Server
  case disconnectUser = 110
  case disconnectMessage = 111 // Server
  case inviteToNewChat = 112
  case inviteToChat = 113 // Server
  case rejectChatInvite = 114
  case joinChat = 115
  case leaveChat = 116
  case notifyChatOfUserChange = 117 // Server
  case notifyChatOfUserDelete = 118 // Server
  case notifyChatSubject = 119 // Server
  case setChatSubject = 120
  case agreed = 121
  case serverBanner = 122 // Server
  case getFileNameList = 200
  case downloadFile = 202
  case uploadFile = 203
  case deleteFile = 204
  case newFolder = 205
  case getFileInfo = 206
  case setFileInfo = 207
  case moveFile = 208
  case makeFileAlias = 209
  case downloadFolder = 210
  case downloadInfo = 211 // Server
  case downloadBanner = 212
  case uploadFolder = 213
  case getNewsFile = 294
  case postNews = 295
  case receiveNewsFile = 296 // Server
  case getUserNameList = 300
  case notifyOfUserChange = 301 // Server
  case notifyOfUserDelete = 302 // Server
  case getClientInfoText = 303
  case setClientUserInfo = 304
  case newUser = 350
  case deleteUser = 351
  case getUser = 352
  case setUser = 353
  case userAccess = 354 // Server
  case userBroadcast = 355 // Client & Server
  case getNewsCategoryNameList = 370
  case getNewsArticleNameList = 371
  case deleteNewsItem = 380
  case newNewsFolder = 381
  case newNewsCategory = 382
  case getNewsArticleData = 400
  case postNewsArticle = 410
  case deleteNewsArticle = 411
  case connectionKeepAlive = 500
}
