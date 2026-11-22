import Foundation

enum ExploitSupportPolicy {
    // offsets.m contains kernel-offset blocks for iOS 17.0-17.7.x,
    // 18.0-18.7.x and 26.0-26.0.x. The 26.x policy below remains unchanged.
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.x"
    static let verifiedIOS26Range = "26.0–26.6.1"

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // iOS 16 is installable (the app deployment target is 16.0) but the
        // kexploit in this repository starts at iOS 17.0. Do not enable iOS 16
        // here without a 16.x offset table and on-device testing.
        //
        // iOS 17/18 offsets are already present in kexploit/offsets.m.
        // They are enabled at source level; verify on real devices before
        // distributing a signed build.
        if major == 17 || major == 18 {
            guard minor >= 0, minor <= 7, patch >= 0 else { return false }
            return true
        }

        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }
}
