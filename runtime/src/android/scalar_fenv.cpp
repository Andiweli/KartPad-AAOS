// ARM64-only helper, enabled by Android's full-runtime build after differential
// validation. Keep this translation unit opaque to callers (no LTO/inlining).
#include <cfenv>
#include <cstdint>
#if !defined(__ANDROID__) || !defined(__aarch64__)
#error Android ARM64 is required
#endif
static_assert(FE_ALL_EXCEPT == 0x9f);
extern "C" __attribute__((noinline)) int KartPadAndroidCaptureScalarFlags() noexcept {
  std::uint64_t status;
  asm volatile("mrs %0, fpsr" : "=r"(status) :: "memory");
  const auto cleared = status & ~std::uint64_t(FE_ALL_EXCEPT);
  // Exact operations commonly leave every exception bit clear. Avoid a
  // redundant system-register write, while retaining QC and all other bits.
  if (cleared != status)
    asm volatile("msr fpsr, %0" :: "r"(cleared) : "memory");
  return status & (FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT);
}
