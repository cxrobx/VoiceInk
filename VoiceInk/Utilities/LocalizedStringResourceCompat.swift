import SwiftUI

#if compiler(<6.1)
// Local-build SDK compatibility (Xcode 16.2 / macOS 15.2 SDK).
//
// Upstream passes `LocalizedStringResource` directly to `.help(...)` and
// `.accessibilityLabel(...)`. Those overloads were added in the macOS 15.4 SDK
// (Xcode 16.3+) and don't exist in the 15.2 SDK this fork builds against.
// These shims bridge through `String(localized:)` so upstream callsites
// compile unmodified. Delete this file once the toolchain moves past 16.2.
// `@_disfavoredOverload` keeps string literals resolving to SwiftUI's native
// `LocalizedStringKey` overloads — only values typed `LocalizedStringResource`
// (which no native overload accepts on this SDK) fall through to these shims.
extension View {
    @_disfavoredOverload
    func help(_ resource: LocalizedStringResource) -> some View {
        help(String(localized: resource))
    }

    @_disfavoredOverload
    func accessibilityLabel(_ resource: LocalizedStringResource) -> some View {
        accessibilityLabel(String(localized: resource))
    }
}
#endif
