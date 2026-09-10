#include <cfenv>
#include <chrono>
#include <cstdint>
#include <cstdio>

extern "C" int KartPadAndroidCaptureScalarFlags() noexcept;
__attribute__((noinline)) int Baseline() noexcept {
  std::uint64_t value;
  asm volatile("mrs %0, fpsr" : "=r"(value) :: "memory");
  const auto cleared = value & ~std::uint64_t(FE_ALL_EXCEPT);
  asm volatile("msr fpsr, %0" :: "r"(cleared) : "memory");
  return value & (FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT);
}
int main() {
  fenv_t saved;
  std::fegetenv(&saved);
  // Exhaust every exception combination, with/without the unrelated QC bit.
  for (unsigned bits = 0; bits < 256; ++bits) {
    for (std::uint64_t qc : {0ULL, 1ULL << 27}) {
      const std::uint64_t before = (bits & FE_ALL_EXCEPT) | qc;
      asm volatile("msr fpsr, %0" :: "r"(before) : "memory");
      const int flags = KartPadAndroidCaptureScalarFlags();
      std::uint64_t after;
      asm volatile("mrs %0, fpsr" : "=r"(after) :: "memory");
      if (after != qc || flags != (before & (FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT))) {
        std::fesetenv(&saved);
        std::puts("FAIL FPSR exception/QC preservation");
        return 1;
      }
    }
  }
  std::puts("PASS 512 FPSR states including unrelated QC preservation");
  for (unsigned repeat = 0; repeat < 4; ++repeat) {
    for (auto capture : {Baseline, KartPadAndroidCaptureScalarFlags}) {
      std::feclearexcept(FE_ALL_EXCEPT);
      const auto start = std::chrono::steady_clock::now();
      unsigned result = 0;
      for (unsigned i = 0; i < 2000000; ++i) result += capture();
      const auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
          std::chrono::steady_clock::now() - start).count();
      std::printf("clear-state %s ns/call=%.2f checksum=%u\n",
          capture == Baseline ? "baseline" : "candidate", double(ns) / 2000000, result);
    }
  }
  std::fesetenv(&saved);
}
