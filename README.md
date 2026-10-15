# QuickCheckVEngine

**QCVEngine** is a very basic QuickCheck-based random instruction generator
for RISC-V (currently supports most 32-bit and 64-bit RISC-V standard extentions as well as CHERI RISC-V extensions).
The main feature of the generator is a small library that makes it easy
to define instruction encoders and decoders.

Find out all of the extensions that are supported by looking at the file names in [this folder](https://github.com/CTSRD-CHERI/QuickCheckVEngine/tree/master/src/RISCV).

## This fork (WyattVO/QuickCheckVEngine, branch `cheri-qemu-gate`)

This branch is the verification engine for the
[CHERI-RISC-V QEMU 10.2 TestRIG gate](https://github.com/WyattVO/TestRIG-cheri-qemu/tree/testrig-cheri-qemu-10.2),
which compares QEMU with the Sail CHERI-RISC-V model. It changes how tests are
generated and compared so that a mismatch means a real difference in behaviour,
not a quirk of the reference model or the test harness (Wyatt Voigt):

- **Comparison**
  - `04029ad`: compare only the 16 instruction bits of a compressed
    instruction's `rvfi_insn`.
  - `216fdd9`: discard, rather than fail, a test whose first difference is a
    store-conditional that succeeded on one side and failed on the other. The
    ISA allows that.
- **Page tables**
  - `bb94cd1`: the `pte` template only generates PTEs the Sail model judges
    correctly. Sail never enforces CW and lacks CD/CRM/CRG, so the gate checks
    those with separate bare-metal tests.
- **The `unstructured` template** (random 32-bit words) no longer generates:
  - `e72b796`, `4353db1`, `81e4f25`, `408f55e`, `037ff3d`: CSR accesses to
    `mhpmevent3`-`31`, `misa`, the counters, the debug triggers, `mconfigptr`
    and `seed`. Their values depend on timing or on what the Sail model
    implements.
  - `72b0d79`: CSR accesses to `mip`. Bit 7 (MTIP) follows each
    implementation's timer: Sail advances `mtime` once every 100 instructions,
    while QEMU's TestRIG mode never fires the timer. So MTIP is never compared,
    and a test that actually takes a timer interrupt is not covered.
  - `2eabe67`: `cspecialrw` on SCRs 3, 11 and 27 (`utidc`/`stidc`/`mtidc`,
    which QEMU implements and Sail does not), or on 0x14-0x17 (missing from
    Sail's `scr_name_map`, which makes the model abort).

### Building this branch

`stack.yaml` pins an old snapshot that no longer resolves. Use cabal 3.4 or
newer with GHC 9.6 (tested with 9.6.7), both from
[GHCup](https://www.haskell.org/ghcup/):

```sh
cabal update
cabal build -w ghc-9.6.7
cabal list-bin -w ghc-9.6.7 QCVEngine   # path of the built binary
```

## Getting started

You should be able to build QCVEngine using cabal. Simply run
```sh
$ cabal configure
$ cabal build
$ cabal install
```
and the `QCVEngine` binary should be in your `~/.cabal/bin`.
