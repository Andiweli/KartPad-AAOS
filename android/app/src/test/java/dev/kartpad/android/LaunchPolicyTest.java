package dev.kartpad.android;

import org.junit.Test;
import static org.junit.Assert.*;

public class LaunchPolicyTest {
    @Test public void firstStartWithoutDataShowsChooser() {
        assertNull(LaunchPolicy.select(false, null, null, false, false));
    }
    @Test public void existingImportFromOlderBuildStartsOriginal() {
        assertEquals("base", LaunchPolicy.select(true, null, null, false, false));
    }
    @Test public void retainedOriginalStartsWithoutChoosing() {
        assertEquals("base", LaunchPolicy.select(true, null, "base", true, false));
    }
    @Test public void retainedRetroStartsWhenInstalled() {
        assertEquals("retro_rewind", LaunchPolicy.select(true, null, "retro_rewind", true, false));
    }
    @Test public void explicitSwitchOverridesRememberedGame() {
        assertEquals("base", LaunchPolicy.select(true, "base", "retro_rewind", true, false));
    }
    @Test public void requestedRetroMayOpenInstallerOnce() {
        assertEquals("retro_rewind", LaunchPolicy.select(true, "retro_rewind", "base", false, false));
        assertNull(LaunchPolicy.select(true, null, "base", false, true));
    }
    @Test public void removedOptionalContentDoesNotLoopInstaller() {
        assertNull(LaunchPolicy.select(true, null, "retro_rewind", false, false));
    }
    @Test public void invalidDataNeverBootsEvenWithPreference() {
        assertNull(LaunchPolicy.select(false, "base", "base", true, false));
    }
    @Test public void unknownPreferenceDefaultsToOriginal() {
        assertEquals("base", LaunchPolicy.select(true, null, "invalid", false, false));
    }
}
