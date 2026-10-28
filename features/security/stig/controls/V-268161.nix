# V-268161 (CAT II) — NixOS must implement address space layout randomization to protect its
# memory from unauthorized code execution.
#
# Fix and check agree here, unlike V-268160: `kernel.randomize_va_space = 2`, full ASLR for
# the stack, mmap region, heap and VDSO.
#
# The check is again an equality test ("does not have a value of 2 [...] this is a finding"),
# but 2 is already the kernel's maximum, so there is nothing stricter to be tempted by.
{...}: {
  boot.kernel.sysctl."kernel.randomize_va_space" = 2;
}
