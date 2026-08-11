import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var body: some View { Text(title).font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading) }
}
