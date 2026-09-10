package dev.kartpad.android;

import org.junit.Test;
import static org.junit.Assert.assertArrayEquals;

public class SafeAreaMathTest {
    @Test public void fittedVehicleBarsAreNotCountedTwice() {
        assertArrayEquals(new int[]{0, 0, 0, 0}, SafeAreaMath.remaining(
            1920, 1080, 120, 60, 1800, 900, 120, 60, 0, 120));
    }
    @Test public void edgeToEdgeFallbackFitsAllSides() {
        assertArrayEquals(new int[]{120, 60, 80, 120}, SafeAreaMath.remaining(
            1920, 1080, 0, 0, 1920, 1080, 120, 60, 80, 120));
    }
    @Test public void additionalVehiclePanelOnlyAddsRemainingOverlap() {
        assertArrayEquals(new int[]{60, 0, 0, 0}, SafeAreaMath.remaining(
            1920, 1080, 120, 60, 1800, 900, 180, 60, 0, 120));
    }
    @Test public void resizeWithinSafeBoundsNeedsNoPadding() {
        assertArrayEquals(new int[]{0, 0, 0, 0}, SafeAreaMath.remaining(
            1920, 1080, 200, 100, 800, 500, 120, 60, 80, 120));
    }
    @Test public void portraitRightHandVehicleBar() {
        assertArrayEquals(new int[]{0, 0, 110, 0}, SafeAreaMath.remaining(
            1080, 1920, 0, 80, 1080, 1720, 0, 80, 110, 120));
    }
    @Test public void dismissedPanelRestoresWholeContentArea() {
        assertArrayEquals(new int[]{0, 0, 0, 0}, SafeAreaMath.remaining(
            1920, 1080, 0, 0, 1920, 1080, 0, 0, 0, 0));
    }
}
