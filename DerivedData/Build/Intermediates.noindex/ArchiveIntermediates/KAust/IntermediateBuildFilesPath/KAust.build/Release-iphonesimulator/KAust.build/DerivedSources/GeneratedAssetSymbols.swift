import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AppBackground" asset catalog color resource.
    static let appBackground = DeveloperToolsSupport.ColorResource(name: "AppBackground", bundle: resourceBundle)

    /// The "LeftPanelAccent" asset catalog color resource.
    static let leftPanelAccent = DeveloperToolsSupport.ColorResource(name: "LeftPanelAccent", bundle: resourceBundle)

    /// The "LeftPanelBg" asset catalog color resource.
    static let leftPanelBg = DeveloperToolsSupport.ColorResource(name: "LeftPanelBg", bundle: resourceBundle)

    /// The "LeftPanelItemBg" asset catalog color resource.
    static let leftPanelItemBg = DeveloperToolsSupport.ColorResource(name: "LeftPanelItemBg", bundle: resourceBundle)

    /// The "LeftPanelListBg" asset catalog color resource.
    static let leftPanelListBg = DeveloperToolsSupport.ColorResource(name: "LeftPanelListBg", bundle: resourceBundle)

    /// The "LeftPanelTextPrimary" asset catalog color resource.
    static let leftPanelTextPrimary = DeveloperToolsSupport.ColorResource(name: "LeftPanelTextPrimary", bundle: resourceBundle)

    /// The "LeftPanelTextSecondary" asset catalog color resource.
    static let leftPanelTextSecondary = DeveloperToolsSupport.ColorResource(name: "LeftPanelTextSecondary", bundle: resourceBundle)

    /// The "RightPanelAccent" asset catalog color resource.
    static let rightPanelAccent = DeveloperToolsSupport.ColorResource(name: "RightPanelAccent", bundle: resourceBundle)

    /// The "RightPanelBg" asset catalog color resource.
    static let rightPanelBg = DeveloperToolsSupport.ColorResource(name: "RightPanelBg", bundle: resourceBundle)

    /// The "RightPanelItemBg" asset catalog color resource.
    static let rightPanelItemBg = DeveloperToolsSupport.ColorResource(name: "RightPanelItemBg", bundle: resourceBundle)

    /// The "RightPanelListBg" asset catalog color resource.
    static let rightPanelListBg = DeveloperToolsSupport.ColorResource(name: "RightPanelListBg", bundle: resourceBundle)

    /// The "RightPanelTextPrimary" asset catalog color resource.
    static let rightPanelTextPrimary = DeveloperToolsSupport.ColorResource(name: "RightPanelTextPrimary", bundle: resourceBundle)

    /// The "RightPanelTextSecondary" asset catalog color resource.
    static let rightPanelTextSecondary = DeveloperToolsSupport.ColorResource(name: "RightPanelTextSecondary", bundle: resourceBundle)

    /// The "SettingResetBlue" asset catalog color resource.
    static let settingResetBlue = DeveloperToolsSupport.ColorResource(name: "SettingResetBlue", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AppBackground" asset catalog color.
    static var appBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appBackground)
#else
        .init()
#endif
    }

    /// The "LeftPanelAccent" asset catalog color.
    static var leftPanelAccent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelAccent)
#else
        .init()
#endif
    }

    /// The "LeftPanelBg" asset catalog color.
    static var leftPanelBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelItemBg" asset catalog color.
    static var leftPanelItemBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelItemBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelListBg" asset catalog color.
    static var leftPanelListBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelListBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelTextPrimary" asset catalog color.
    static var leftPanelTextPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelTextPrimary)
#else
        .init()
#endif
    }

    /// The "LeftPanelTextSecondary" asset catalog color.
    static var leftPanelTextSecondary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leftPanelTextSecondary)
#else
        .init()
#endif
    }

    /// The "RightPanelAccent" asset catalog color.
    static var rightPanelAccent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelAccent)
#else
        .init()
#endif
    }

    /// The "RightPanelBg" asset catalog color.
    static var rightPanelBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelBg)
#else
        .init()
#endif
    }

    /// The "RightPanelItemBg" asset catalog color.
    static var rightPanelItemBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelItemBg)
#else
        .init()
#endif
    }

    /// The "RightPanelListBg" asset catalog color.
    static var rightPanelListBg: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelListBg)
#else
        .init()
#endif
    }

    /// The "RightPanelTextPrimary" asset catalog color.
    static var rightPanelTextPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelTextPrimary)
#else
        .init()
#endif
    }

    /// The "RightPanelTextSecondary" asset catalog color.
    static var rightPanelTextSecondary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .rightPanelTextSecondary)
#else
        .init()
#endif
    }

    /// The "SettingResetBlue" asset catalog color.
    static var settingResetBlue: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingResetBlue)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AppBackground" asset catalog color.
    static var appBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .appBackground)
#else
        .init()
#endif
    }

    /// The "LeftPanelAccent" asset catalog color.
    static var leftPanelAccent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelAccent)
#else
        .init()
#endif
    }

    /// The "LeftPanelBg" asset catalog color.
    static var leftPanelBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelItemBg" asset catalog color.
    static var leftPanelItemBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelItemBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelListBg" asset catalog color.
    static var leftPanelListBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelListBg)
#else
        .init()
#endif
    }

    /// The "LeftPanelTextPrimary" asset catalog color.
    static var leftPanelTextPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelTextPrimary)
#else
        .init()
#endif
    }

    /// The "LeftPanelTextSecondary" asset catalog color.
    static var leftPanelTextSecondary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .leftPanelTextSecondary)
#else
        .init()
#endif
    }

    /// The "RightPanelAccent" asset catalog color.
    static var rightPanelAccent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelAccent)
#else
        .init()
#endif
    }

    /// The "RightPanelBg" asset catalog color.
    static var rightPanelBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelBg)
#else
        .init()
#endif
    }

    /// The "RightPanelItemBg" asset catalog color.
    static var rightPanelItemBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelItemBg)
#else
        .init()
#endif
    }

    /// The "RightPanelListBg" asset catalog color.
    static var rightPanelListBg: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelListBg)
#else
        .init()
#endif
    }

    /// The "RightPanelTextPrimary" asset catalog color.
    static var rightPanelTextPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelTextPrimary)
#else
        .init()
#endif
    }

    /// The "RightPanelTextSecondary" asset catalog color.
    static var rightPanelTextSecondary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .rightPanelTextSecondary)
#else
        .init()
#endif
    }

    /// The "SettingResetBlue" asset catalog color.
    static var settingResetBlue: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .settingResetBlue)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AppBackground" asset catalog color.
    static var appBackground: SwiftUI.Color { .init(.appBackground) }

    /// The "LeftPanelAccent" asset catalog color.
    static var leftPanelAccent: SwiftUI.Color { .init(.leftPanelAccent) }

    /// The "LeftPanelBg" asset catalog color.
    static var leftPanelBg: SwiftUI.Color { .init(.leftPanelBg) }

    /// The "LeftPanelItemBg" asset catalog color.
    static var leftPanelItemBg: SwiftUI.Color { .init(.leftPanelItemBg) }

    /// The "LeftPanelListBg" asset catalog color.
    static var leftPanelListBg: SwiftUI.Color { .init(.leftPanelListBg) }

    /// The "LeftPanelTextPrimary" asset catalog color.
    static var leftPanelTextPrimary: SwiftUI.Color { .init(.leftPanelTextPrimary) }

    /// The "LeftPanelTextSecondary" asset catalog color.
    static var leftPanelTextSecondary: SwiftUI.Color { .init(.leftPanelTextSecondary) }

    /// The "RightPanelAccent" asset catalog color.
    static var rightPanelAccent: SwiftUI.Color { .init(.rightPanelAccent) }

    /// The "RightPanelBg" asset catalog color.
    static var rightPanelBg: SwiftUI.Color { .init(.rightPanelBg) }

    /// The "RightPanelItemBg" asset catalog color.
    static var rightPanelItemBg: SwiftUI.Color { .init(.rightPanelItemBg) }

    /// The "RightPanelListBg" asset catalog color.
    static var rightPanelListBg: SwiftUI.Color { .init(.rightPanelListBg) }

    /// The "RightPanelTextPrimary" asset catalog color.
    static var rightPanelTextPrimary: SwiftUI.Color { .init(.rightPanelTextPrimary) }

    /// The "RightPanelTextSecondary" asset catalog color.
    static var rightPanelTextSecondary: SwiftUI.Color { .init(.rightPanelTextSecondary) }

    /// The "SettingResetBlue" asset catalog color.
    static var settingResetBlue: SwiftUI.Color { .init(.settingResetBlue) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AppBackground" asset catalog color.
    static var appBackground: SwiftUI.Color { .init(.appBackground) }

    /// The "LeftPanelAccent" asset catalog color.
    static var leftPanelAccent: SwiftUI.Color { .init(.leftPanelAccent) }

    /// The "LeftPanelBg" asset catalog color.
    static var leftPanelBg: SwiftUI.Color { .init(.leftPanelBg) }

    /// The "LeftPanelItemBg" asset catalog color.
    static var leftPanelItemBg: SwiftUI.Color { .init(.leftPanelItemBg) }

    /// The "LeftPanelListBg" asset catalog color.
    static var leftPanelListBg: SwiftUI.Color { .init(.leftPanelListBg) }

    /// The "LeftPanelTextPrimary" asset catalog color.
    static var leftPanelTextPrimary: SwiftUI.Color { .init(.leftPanelTextPrimary) }

    /// The "LeftPanelTextSecondary" asset catalog color.
    static var leftPanelTextSecondary: SwiftUI.Color { .init(.leftPanelTextSecondary) }

    /// The "RightPanelAccent" asset catalog color.
    static var rightPanelAccent: SwiftUI.Color { .init(.rightPanelAccent) }

    /// The "RightPanelBg" asset catalog color.
    static var rightPanelBg: SwiftUI.Color { .init(.rightPanelBg) }

    /// The "RightPanelItemBg" asset catalog color.
    static var rightPanelItemBg: SwiftUI.Color { .init(.rightPanelItemBg) }

    /// The "RightPanelListBg" asset catalog color.
    static var rightPanelListBg: SwiftUI.Color { .init(.rightPanelListBg) }

    /// The "RightPanelTextPrimary" asset catalog color.
    static var rightPanelTextPrimary: SwiftUI.Color { .init(.rightPanelTextPrimary) }

    /// The "RightPanelTextSecondary" asset catalog color.
    static var rightPanelTextSecondary: SwiftUI.Color { .init(.rightPanelTextSecondary) }

    /// The "SettingResetBlue" asset catalog color.
    static var settingResetBlue: SwiftUI.Color { .init(.settingResetBlue) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

