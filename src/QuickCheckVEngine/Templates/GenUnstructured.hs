--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2025 Peter Rugg
-- All rights reserved.
--
-- This software was developed by SRI International and the University of
-- Cambridge Computer Laboratory (Department of Computer Science and
-- Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
-- DARPA SSITH research programme.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

module QuickCheckVEngine.Templates.GenUnstructured (
  gen_unstructured
) where

import QuickCheckVEngine.Template
import QuickCheckVEngine.Templates.Utils.General
import InstrCodec
import Data.Bits
import Test.QuickCheck (suchThat)

gen_unstructured :: Template
gen_unstructured = random $ do
  instBits <- bits 32 `suchThat` (\i -> not (accessesMissingSailCSR i
                                              || accessesMissingSailSCR i))
  return $ inst $ MkInstruction instBits

-- | CSpecialRW on special capability registers the Sail CHERI-RISC-V model
--   cannot handle:
--   * utidc, stidc, mtidc (3, 11, 27): QEMU implements the thread ID
--     capability registers, the Sail model treats these numbers as reserved
--     and raises an illegal instruction exception.
--   * 0x14-0x17: missing from the Sail model's scr_name_map, so the model
--     aborts ("Pattern match failure in scr_name_map_forwards") instead of
--     raising an exception, which ends the test run.
accessesMissingSailSCR :: Integer -> Bool
accessesMissingSailSCR i = opcode == 0x5b && funct3 == 0 && funct7 == 0x01
                           && (scr `elem` [3, 11, 27] || (scr >= 0x14 && scr <= 0x17))
  where opcode = i .&. 0x7f
        funct3 = (i `shiftR` 12) .&. 0x7
        funct7 = (i `shiftR` 25) .&. 0x7f
        scr    = (i `shiftR` 20) .&. 0x1f

-- | CSR instructions whose result only reflects how the reference model is
--   configured rather than the behaviour under test:
--   * mhpmevent3-31 (0x323-0x33f): the privileged spec requires these CSRs
--     (QEMU implements them), but the Sail CHERI-RISC-V model does not.
--   * misa (0x301): Sail always reports its full ISA (e.g. V and F/D), which
--     the architecture string cannot turn off.
--   * Counters (mcycle/minstret/mhpmcounter* 0xb00-0xb9f, cycle/time/instret/
--     hpmcounter* 0xc00-0xc9f): their values depend on timing and on how each
--     implementation counts, so they cannot be compared.
--   * Debug triggers (tselect/tdata*/tinfo/mcontext, 0x7a0-0x7af) and
--     mconfigptr (0xf15): QEMU implements them, the Sail model does not.
--   * seed (0x015): the Zkr entropy source returns random bits by design.
--   * mip (0x344): mip.MTIP (bit 7) reflects each implementation's timer.
--     Sail advances mtime once every 100 instructions with mtimecmp left at
--     0, so MTIP goes pending at the 100th instruction of a test; QEMU's
--     mtime follows host time and its RVFI-DII mode never lets the timer
--     fire. Masking MTIP in the comparison is not enough: the value read
--     lands in a register and diverges in later instructions. So bit 7 is
--     never compared, and the other mip bits are not compared here either
--     (regression trace 22 still checks mip after reset). A test that
--     actually takes the timer interrupt (mie.MTIE and mstatus.MIE set)
--     would still diverge; this does not cover it.
accessesMissingSailCSR :: Integer -> Bool
accessesMissingSailCSR i = opcode == 0x73 && funct3 /= 0 && funct3 /= 4
                           && (csr == 0x015 || csr == 0x301 || csr == 0x344
                               || (csr >= 0x323 && csr <= 0x33f)
                               || (csr >= 0x7a0 && csr <= 0x7af)
                               || (csr >= 0xb00 && csr <= 0xb9f)
                               || (csr >= 0xc00 && csr <= 0xc9f)
                               || csr == 0xf15)
  where opcode = i .&. 0x7f
        funct3 = (i `shiftR` 12) .&. 0x7
        csr    = (i `shiftR` 20) .&. 0xfff
