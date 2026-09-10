package dev.kartpad.android;

/** AST 2026-09-07. Remaining overlap after the window manager has fitted content. */
public final class SafeAreaMath {
    private SafeAreaMath() {}

    public static int[] remaining(int rootWidth, int rootHeight,
                                  int contentX, int contentY, int width, int height,
                                  int left, int top, int right, int bottom) {
        return new int[] {
            Math.min(width, Math.max(0, left - contentX)),
            Math.min(height, Math.max(0, top - contentY)),
            Math.min(width, Math.max(0, contentX + width - (rootWidth - right))),
            Math.min(height, Math.max(0, contentY + height - (rootHeight - bottom)))
        };
    }
}
