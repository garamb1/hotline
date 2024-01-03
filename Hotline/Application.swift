import SwiftUI
import SwiftData

@main
struct Application: App {
  #if os(iOS)
  private var model = Hotline(trackerClient: HotlineTrackerClient(), client: HotlineClient())
  #endif
  
  private var preferences = Prefs()
  
  var body: some Scene {
    #if os(iOS)
    WindowGroup {
      TrackerView()
        .environment(model)
    }
    #elseif os(macOS)
    Window("Servers", id: "servers") {
      TrackerView()
        .frame(minWidth: 250, minHeight: 250)
    }
    .defaultSize(width: 700, height: 550)
    .defaultPosition(.center)
    
    WindowGroup(id: "server", for: Server.self) { $server in
      if let s = server {
        ServerView(server: s)
          .frame(minWidth: 400, minHeight: 300)
          .environment(Hotline(trackerClient: HotlineTrackerClient(), client: HotlineClient()))
          .environment(preferences)
          .toolbar {
            ToolbarItem(placement: .navigation) {
              Image(systemName: "globe.americas.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 18)
            }
          }
      }
    }
    .defaultSize(width: 700, height: 800)
    .defaultPosition(.center)
//    .commandsRemoved()
//    .commands {
//      CommandGroup(before: CommandGroupPlacement.newItem) {
//        Button("before item") {
//          print("before item")
//        }
//      }
//    }
    
#if os(macOS)
    Settings {
      SettingsView()
        .environment(preferences)
    }
#endif

    #endif
  }
}
