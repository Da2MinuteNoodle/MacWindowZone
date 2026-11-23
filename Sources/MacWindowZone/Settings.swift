import Foundation
import AppKit

/// What the user must hold (or not hold) while dragging a window to trigger the snap overlay.
enum SnapModifier: String, CaseIterable {
    case none      // any window drag activates the overlay
    case shift
    case option
    case command
    case control
    case disabled  // never auto-snap on drag

    var displayName: String {
        switch self {
        case .none:     return "No modifier (always)"
        case .shift:    return "Shift (⇧)"
        case .option:   return "Option (⌥)"
        case .command:  return "Command (⌘)"
        case .control:  return "Control (⌃)"
        case .disabled: return "Disabled"
        }
    }

    func isSatisfied(by flags: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .none:     return true
        case .shift:    return flags.contains(.shift)
        case .option:   return flags.contains(.option)
        case .command:  return flags.contains(.command)
        case .control:  return flags.contains(.control)
        case .disabled: return false
        }
    }

    /// Extra modifier held during a drag-snap to accumulate multiple zones.
    /// Control by default; Option when Control is already the snap modifier
    /// so the two gestures don't collide.
    var multiSelectFlag: NSEvent.ModifierFlags {
        self == .control ? .option : .control
    }

    func isMultiSelectSatisfied(by flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(multiSelectFlag)
    }

    /// Status-menu hint for the multi-zone drag gesture. Empty when drag-snap is disabled.
    var multiSelectHint: String {
        switch self {
        case .disabled:
            return ""
        case .control:
            return "Hold ⌥ Option while dragging to select multiple zones"
        default:
            return "Hold ⌃ Control while dragging to select multiple zones"
        }
    }
}

/// How a taller-than-wide display treats Aero-style edge snaps.
enum PortraitEdgeBehavior: String, CaseIterable {
    /// Top edge fills the screen; left/right edges split top vs bottom half.
    case topFillsSidesSplit
    /// Every edge (including the top) splits top vs bottom half.
    case allEdgesSplit
    /// Identical to landscape: top fills, left/right are left/right halves.
    case landscape

    var displayName: String {
        switch self {
        case .topFillsSidesSplit: return "Top fills, sides split top/bottom"
        case .allEdgesSplit:      return "All edges split top/bottom"
        case .landscape:          return "Same as landscape (left/right halves)"
        }
    }

    var shortName: String {
        switch self {
        case .topFillsSidesSplit: return "Top fills screen"
        case .allEdgesSplit:      return "All edges split"
        case .landscape:          return "Same as landscape"
        }
    }
}

/// Colors and opacities of the drag-snap / edge-snap preview.
///
/// Default matches the original overlay: system blue highlight at 45%,
/// system teal zones at 18%, borders at 95%. "System" colors follow
/// light and dark mode; a picked color is stored as fixed sRGB.
struct OverlayPalette: Equatable {
    var highlightIsSystem: Bool
    var highlightRed: Double
    var highlightGreen: Double
    var highlightBlue: Double
    var zoneIsSystem: Bool
    var zoneRed: Double
    var zoneGreen: Double
    var zoneBlue: Double
    /// Fill opacity of the zone under the cursor, a multi-zone union, and edge-snap previews.
    var highlightOpacity: Double
    /// Fill opacity of the other zones shown while the drag modifier is held.
    var zoneOpacity: Double
    /// Stroke opacity for both highlight and idle zones.
    var borderOpacity: Double

    static let `default` = OverlayPalette(
        highlightIsSystem: true,
        highlightRed: 0, highlightGreen: 0, highlightBlue: 0,
        zoneIsSystem: true,
        zoneRed: 0, zoneGreen: 0, zoneBlue: 0,
        highlightOpacity: 0.45,
        zoneOpacity: 0.18,
        borderOpacity: 0.95
    )

    mutating func clamp() {
        highlightRed = Self.unit(highlightRed)
        highlightGreen = Self.unit(highlightGreen)
        highlightBlue = Self.unit(highlightBlue)
        zoneRed = Self.unit(zoneRed)
        zoneGreen = Self.unit(zoneGreen)
        zoneBlue = Self.unit(zoneBlue)
        highlightOpacity = Self.unit(highlightOpacity)
        zoneOpacity = Self.unit(zoneOpacity)
        borderOpacity = Self.unit(borderOpacity)
    }

    private static func unit(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0))
    }

    func opaqueColor(active: Bool) -> NSColor {
        if active {
            if highlightIsSystem { return .systemBlue }
            return NSColor(srgbRed: highlightRed, green: highlightGreen, blue: highlightBlue, alpha: 1)
        }
        if zoneIsSystem { return .systemTeal }
        return NSColor(srgbRed: zoneRed, green: zoneGreen, blue: zoneBlue, alpha: 1)
    }

    func fillColor(active: Bool) -> NSColor {
        let opacity = active ? highlightOpacity : zoneOpacity
        return opaqueColor(active: active).withAlphaComponent(opacity)
    }

    func strokeColor(active: Bool) -> NSColor {
        opaqueColor(active: active).withAlphaComponent(borderOpacity)
    }

    /// `scale` shrinks the inset, corner radius, and stroke for a small preview.
    /// The on-screen overlay uses the default of 1.
    func drawZone(in rect: NSRect, active: Bool, scale: CGFloat = 1) {
        let inset = rect.insetBy(dx: 6 * scale, dy: 6 * scale)
        guard inset.width > 2, inset.height > 2 else { return }
        let path = NSBezierPath(roundedRect: inset, xRadius: 12 * scale, yRadius: 12 * scale)
        fillColor(active: active).setFill()
        path.fill()
        strokeColor(active: active).setStroke()
        path.lineWidth = max(1, (active ? 3 : 1.5) * scale)
        path.stroke()
    }
}

extension OverlayPalette: Codable {
    private enum CodingKeys: String, CodingKey {
        case highlightIsSystem
        case highlightRed, highlightGreen, highlightBlue
        case zoneIsSystem
        case zoneRed, zoneGreen, zoneBlue
        case highlightOpacity, zoneOpacity, borderOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = OverlayPalette.default
        highlightIsSystem = try container.decodeIfPresent(Bool.self, forKey: .highlightIsSystem) ?? fallback.highlightIsSystem
        highlightRed = try container.decodeIfPresent(Double.self, forKey: .highlightRed) ?? fallback.highlightRed
        highlightGreen = try container.decodeIfPresent(Double.self, forKey: .highlightGreen) ?? fallback.highlightGreen
        highlightBlue = try container.decodeIfPresent(Double.self, forKey: .highlightBlue) ?? fallback.highlightBlue
        zoneIsSystem = try container.decodeIfPresent(Bool.self, forKey: .zoneIsSystem) ?? fallback.zoneIsSystem
        zoneRed = try container.decodeIfPresent(Double.self, forKey: .zoneRed) ?? fallback.zoneRed
        zoneGreen = try container.decodeIfPresent(Double.self, forKey: .zoneGreen) ?? fallback.zoneGreen
        zoneBlue = try container.decodeIfPresent(Double.self, forKey: .zoneBlue) ?? fallback.zoneBlue
        highlightOpacity = try container.decodeIfPresent(Double.self, forKey: .highlightOpacity) ?? fallback.highlightOpacity
        zoneOpacity = try container.decodeIfPresent(Double.self, forKey: .zoneOpacity) ?? fallback.zoneOpacity
        borderOpacity = try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? fallback.borderOpacity
        clamp()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(highlightIsSystem, forKey: .highlightIsSystem)
        try container.encode(highlightRed, forKey: .highlightRed)
        try container.encode(highlightGreen, forKey: .highlightGreen)
        try container.encode(highlightBlue, forKey: .highlightBlue)
        try container.encode(zoneIsSystem, forKey: .zoneIsSystem)
        try container.encode(zoneRed, forKey: .zoneRed)
        try container.encode(zoneGreen, forKey: .zoneGreen)
        try container.encode(zoneBlue, forKey: .zoneBlue)
        try container.encode(highlightOpacity, forKey: .highlightOpacity)
        try container.encode(zoneOpacity, forKey: .zoneOpacity)
        try container.encode(borderOpacity, forKey: .borderOpacity)
    }
}

/// User-tunable runtime settings. Persisted to UserDefaults.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let gap = "MWZ.gap"
        static let snapModifier = "MWZ.snapModifier"
        static let restoreIgnored = "MWZ.restoreIgnored"
        static let edgeSnapEnabled = "MWZ.edgeSnapEnabled"
        static let edgeSnapBuffer = "MWZ.edgeSnapBuffer"
        static let portraitEdgeBehavior = "MWZ.portraitEdgeBehavior"
        static let overlayPalette = "MWZ.overlayPalette"
    }

    /// Bundle IDs whose windows must NOT be auto-restored on launch.
    /// Browsers ship here by default because attaching AX observers and
    /// calling `setFrame` during their startup disrupts session/tab restoration.
    static let defaultIgnoredForRestore: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "com.thebrowser.Browser",      // Arc
        "company.thebrowser.Browser",  // Arc (older)
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi"
    ]

    /// Total gap (in points) between two adjacent windows snapped to neighbouring zones.
    /// Half of this is inset on each side of every snap target.
    /// Default: 4 points.
    var gap: CGFloat {
        didSet {
            defaults.set(Double(gap), forKey: Keys.gap)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Modifier required while dragging a window to activate the snap overlay.
    /// Default: `.none` (FancyZones-style — drag any window, overlay shows).
    var snapModifier: SnapModifier {
        didSet {
            defaults.set(snapModifier.rawValue, forKey: Keys.snapModifier)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// When true, dragging a window to a screen edge/corner shows an Aero-style
    /// snap preview (no zone modifier required).
    var edgeSnapEnabled: Bool {
        didSet {
            defaults.set(edgeSnapEnabled, forKey: Keys.edgeSnapEnabled)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Interior margin (points) that counts as "on the edge" of a display.
    /// Wider values make snaps at the seam between extended displays hittable,
    /// since macOS does not clamp the cursor there. Default: 24.
    var edgeSnapBuffer: CGFloat {
        didSet {
            defaults.set(Double(edgeSnapBuffer), forKey: Keys.edgeSnapBuffer)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Edge-snap layout used on portrait (taller-than-wide) displays.
    /// Default: top edge fills the screen; side edges split top/bottom.
    var portraitEdgeBehavior: PortraitEdgeBehavior {
        didSet {
            defaults.set(portraitEdgeBehavior.rawValue, forKey: Keys.portraitEdgeBehavior)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Look of the translucent overlay shown while edge-snapping or picking zones.
    var overlayPalette: OverlayPalette {
        didSet {
            var clamped = overlayPalette
            clamped.clamp()
            if clamped != overlayPalette {
                overlayPalette = clamped
                return
            }
            guard overlayPalette != oldValue else { return }
            if let data = try? JSONEncoder().encode(overlayPalette) {
                defaults.set(data, forKey: Keys.overlayPalette)
            }
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// Set of bundle IDs whose windows are NOT auto-restored on launch.
    var ignoredForRestore: Set<String> {
        didSet {
            defaults.set(Array(ignoredForRestore), forKey: Keys.restoreIgnored)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    func ignoresAutoRestore(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ignoredForRestore.contains(bundleID)
    }

    func toggleIgnored(bundleID: String) {
        if ignoredForRestore.contains(bundleID) {
            ignoredForRestore.remove(bundleID)
        } else {
            ignoredForRestore.insert(bundleID)
        }
    }

    private init() {
        if defaults.object(forKey: Keys.gap) != nil {
            self.gap = CGFloat(defaults.double(forKey: Keys.gap))
        } else {
            self.gap = 4
        }
        if let raw = defaults.string(forKey: Keys.snapModifier),
           let mod = SnapModifier(rawValue: raw) {
            self.snapModifier = mod
        } else {
            self.snapModifier = .shift
        }
        if let stored = defaults.array(forKey: Keys.restoreIgnored) as? [String] {
            self.ignoredForRestore = Set(stored)
        } else {
            self.ignoredForRestore = Settings.defaultIgnoredForRestore
        }
        if defaults.object(forKey: Keys.edgeSnapEnabled) != nil {
            self.edgeSnapEnabled = defaults.bool(forKey: Keys.edgeSnapEnabled)
        } else {
            self.edgeSnapEnabled = true
        }
        if defaults.object(forKey: Keys.edgeSnapBuffer) != nil {
            self.edgeSnapBuffer = CGFloat(defaults.double(forKey: Keys.edgeSnapBuffer))
        } else {
            self.edgeSnapBuffer = 24
        }
        if let raw = defaults.string(forKey: Keys.portraitEdgeBehavior),
           let behavior = PortraitEdgeBehavior(rawValue: raw) {
            self.portraitEdgeBehavior = behavior
        } else {
            self.portraitEdgeBehavior = .topFillsSidesSplit
        }
        if let data = defaults.data(forKey: Keys.overlayPalette),
           let stored = try? JSONDecoder().decode(OverlayPalette.self, from: data) {
            self.overlayPalette = stored
        } else {
            self.overlayPalette = .default
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("MWZ.settingsChanged")
}
