import SwiftUI

@Observable final class Hotline: HotlineClientDelegate {
  let trackerClient: HotlineTrackerClient
  let client: HotlineClient
  
  var status: HotlineClientStatus = .disconnected
  
  var server: Server? = nil
  var serverVersion: UInt16? = nil
  var serverName: String? = nil
  var username: String = "bolt"
  var iconID: UInt = 128
  
  var users: [User] = []
  var chat: [ChatMessage] = []
  var messageBoard: [String] = []
  var files: [FileInfo] = []
  var news: [NewsCategory] = []
  
  // MARK: -
  
  init(trackerClient: HotlineTrackerClient, client: HotlineClient) {
    self.trackerClient = trackerClient
    self.client = client
    self.client.delegate = self
  }
  
  // MARK: -
  
  @MainActor func getServers(address: String, port: Int = Tracker.defaultPort) async -> [Server] {
    let fetchedServers: [HotlineServer] = await self.trackerClient.fetchServers(address: address, port: port)
    
    var servers: [Server] = []
    
    for s in fetchedServers {
      if let serverName = s.name {
        servers.append(Server(name: serverName, description: s.description, address: s.address, port: Int(s.port), users: Int(s.users)))
      }
    }
    
    return servers
  }
  
  @MainActor func disconnectTracker() {
    self.trackerClient.disconnect()
  }
  
  @MainActor func login(server: Server, login: String, password: String, username: String, iconID: UInt) async -> Bool {
    self.server = server
    self.username = username
    self.iconID = iconID
    
    return await withCheckedContinuation { [weak self] continuation in
      let _ = self?.client.login(server.address, port: UInt16(server.port), login: login, password: password, username: username, iconID: UInt16(iconID)) { [weak self] err, serverName, serverVersion in
        self?.serverVersion = serverVersion
        if serverName != nil {
          self?.serverName = serverName
        }
        continuation.resume(returning: (err != nil))
      }
    }
  }
  
  @MainActor func disconnect() {
    self.client.disconnect()
  }
  
  @MainActor func sendChat(_ text: String) {
    self.client.sendChat(message: text, sent: nil)
  }
  
  @MainActor func getMessageBoard() async -> [String] {
    self.messageBoard = await withCheckedContinuation { [weak self] continuation in
      self?.client.sendGetMessageBoard() { err, messages in
        continuation.resume(returning: (err != nil ? [] : messages))
      }
    }
    
    return self.messageBoard
  }
  
  @MainActor func getFileList(path: [String] = []) async -> [FileInfo] {
    return await withCheckedContinuation { [weak self] continuation in
      self?.client.sendGetFileList(path: path, sent: { success in
        if !success {
          continuation.resume(returning: [])
          return
        }
      }, reply: { [weak self] files in
        let parentFile = self?.findFile(in: self?.files ?? [], at: path)
        
        var newFiles: [FileInfo] = []
        for f in files {
          newFiles.append(FileInfo(hotlineFile: f))
        }
        
        if let parent = parentFile {
          parent.children = newFiles
        }
        else if path.isEmpty {
          self?.files = newFiles
        }
        
        continuation.resume(returning: newFiles)
      })
    }
  }
  
  @MainActor func getNewsCategories() async -> [NewsCategory] {
    return await withCheckedContinuation { [weak self] continuation in
      self?.client.sendGetNewsCategories(sent: { success in
        if !success {
          continuation.resume(returning: [])
          return
        }
      }, reply: { [weak self] categories in
        var newCategories: [NewsCategory] = []
        for category in categories {
          newCategories.append(NewsCategory(hotlineNewsCategory: category))
        }
        self?.news = newCategories
        
        continuation.resume(returning: newCategories)
      })
    }
  }

  
//  @MainActor func updateUsers() async -> [User] {
//    let userList = await self.client.sendGetUserList()
//    var users = []
////    self.client.sendChat(message: text)
//    
//    return users
//  }
  
  // MARK: - Hotline Delegate
  
  func hotlineStatusChanged(status: HotlineClientStatus) {
    print("Hotline: Connection status changed to: \(status)")
    
    if status == .disconnected {
      self.serverVersion = nil
      self.serverName = nil
      self.users = []
      self.chat = []
      self.messageBoard = []
      self.files = []
      self.news = []
    }
    
    self.status = status
  }
  
  func hotlineGetUserInfo() -> (String, UInt16) {
    return (self.username, UInt16(self.iconID))
  }
  
  func hotlineReceivedAgreement(text: String) {
    self.chat.append(ChatMessage(text: text, type: .agreement, date: Date()))
  }
  
  func hotlineReceivedServerMessage(message: String) {
//    print("Hotline: received server message:\n\(message)")
//    self.chat.append(ChatMessage(text: message, type: .server, date: Date()))
  }
  
  func hotlineReceivedChatMessage(message: String) {
    self.chat.append(ChatMessage(text: message, type: .message, date: Date()))
  }
  
  func hotlineReceivedUserList(users: [HotlineUser]) {
    var existingUserIDs: [UInt] = []
    var userList: [User] = []
    
    print("GOT USER LIST", users)
    
    for u in users {
      if let i = self.users.firstIndex(where: { $0.id == u.id }) {
        // If a user is already in the user list we have to assume
        // they changed somehow before we received the user list
        // which means let's keep their existing info.
        existingUserIDs.append(UInt(u.id))
        userList.append(self.users[i])
      }
      else {
        userList.append(User(hotlineUser: u))
      }
    }
    
    if !existingUserIDs.isEmpty {
      self.users = self.users.filter { !existingUserIDs.contains($0.id) }
    }
    
    self.users = userList + self.users
  }
  
  func hotlineUserChanged(user: HotlineUser) {
    self.addOrUpdateHotlineUser(user)
  }
    
  func hotlineUserDisconnected(userID: UInt16) {
    if let existingUserIndex = self.users.firstIndex(where: { $0.id == UInt(userID) }) {
      let user = self.users.remove(at: existingUserIndex)
      self.chat.append(ChatMessage(text: "\(user.name) left", type: .status, date: Date()))
    }
  }
  
  func hotlineReceivedUserAccess(options: HotlineUserAccessOptions) {
    print("Hotline: got access options")
    print(options, options.contains(.canSendChat), options.contains(.canBroadcast))
  }
  
  func hotlineReceivedError(message: String) {
    
  }
  
  // MARK: - Utilities
  
  private func addOrUpdateHotlineUser(_ user: HotlineUser) {
    if let i = self.users.firstIndex(where: { $0.id == user.id }) {
      print("Hotline: updating user \(self.users[i].name)")
      self.users[i] = User(hotlineUser: user)
    }
    else {
      print("Hotline: added user: \(user.name)")
      self.users.append(User(hotlineUser: user))
      self.chat.append(ChatMessage(text: "\(user.name) joined", type: .status, date: Date()))
    }
  }
  
  private func findFile(in filesToSearch: [FileInfo], at path: [String]) -> FileInfo? {
    guard !path.isEmpty, !filesToSearch.isEmpty else { return nil }
    
    //    var stack: [([HotlineFile], [String])] = [(self.files!, path)]
    
    let currentName = path[0]
    
    for file in filesToSearch {
      if file.name == currentName {
        if path.count == 1 {
          return file
        }
        else if let subfiles = file.children {
          let remainingPath = Array(path[1...])
          return self.findFile(in: subfiles, at: remainingPath)
        }
      }
    }
    
    return nil
  }
}
