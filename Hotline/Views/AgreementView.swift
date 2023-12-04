import SwiftUI

struct AgreementView: View {
  @Environment(HotlineState.self) private var appState
  
  let text: String
  
  var body: some View {
//    @Bindable var config = appState
    
    VStack(alignment: .leading) {
      ScrollView {
        VStack(alignment: .leading) {
          Text(text)
            .fontDesign(.monospaced)
            .padding()
            .dynamicTypeSize(.small)
            .textSelection(.enabled)
        }
      }
      Button("OK") {
        print("DONE")
        appState.dismissAgreement()
      }
      .bold()
      .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
      .frame(maxWidth: .infinity)
    }
    .presentationDetents([.fraction(0.6)])
    .presentationDragIndicator(.visible)
  }
}

#Preview {
  AgreementView(text: """
Welcome!

Take it on real one.
""")
}
