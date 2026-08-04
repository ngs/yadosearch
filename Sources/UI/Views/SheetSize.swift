import SwiftUI

extension View {
    /// The size a sheet opens at on the Mac.
    ///
    /// A sheet there is sized by its content, and a `List` has no height to
    /// offer — so every picker in this app opened as a title and a Done button
    /// with nothing between them. iOS sheets size themselves and ignore this.
    func sheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 620)
        #else
        self
        #endif
    }
}
