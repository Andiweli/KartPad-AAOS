package dev.kartpad.android;

/** Select a retained game without showing the first-run chooser again. */
public final class LaunchPolicy {
    private LaunchPolicy() {}

    public static String select(boolean dataReady, String requested, String remembered,
                                boolean retroReady, boolean automaticAttempted) {
        if (!dataReady) return null;
        if (valid(requested)) return requested;
        if (automaticAttempted) return null;
        String profile = valid(remembered) ? remembered : "base";
        // A missing optional install must not repeatedly reopen its installer.
        if ("retro_rewind".equals(profile) && !retroReady) return null;
        return profile;
    }

    private static boolean valid(String profile) {
        return "base".equals(profile) || "retro_rewind".equals(profile);
    }
}
