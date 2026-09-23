import BeastCore
import Foundation

/// Keeps the settings in UserDefaults. This replaces [GETBEAST] and [SAVEBEAS], which kept a
/// 'BSet' resource in "Beast Game Settings" in the System Folder.
enum SettingsStore {
    private static let keys = (numBeasts: "numBeasts", delay: "delay", density: "density")

    static func load() -> BeastSettings {
        let d = UserDefaults.standard
        d.register(defaults: [keys.numBeasts: BeastSettings.defaults.numBeasts,
                              keys.delay: BeastSettings.defaults.delay,
                              keys.density: BeastSettings.defaults.density])
        // The original trusted the file. Clamping here keeps a hand-edited value such as
        // density 0 from dividing by zero.
        return BeastSettings(numBeasts: d.integer(forKey: keys.numBeasts),
                             delay: d.integer(forKey: keys.delay),
                             density: d.integer(forKey: keys.density)).verified()
    }

    /// Game window zoom (View menu): 1 or 2. New in the port. Defaults to 2, because the
    /// original 506 x 297 window is tiny on modern screens.
    static var scale: Int {
        get { UserDefaults.standard.integer(forKey: "scale") == 1 ? 1 : 2 }
        set { UserDefaults.standard.set(newValue, forKey: "scale") }
    }

    static func save(_ s: BeastSettings) {
        let d = UserDefaults.standard
        d.set(s.numBeasts, forKey: keys.numBeasts)
        d.set(s.delay, forKey: keys.delay)
        d.set(s.density, forKey: keys.density)
    }
}
