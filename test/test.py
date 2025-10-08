# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 31.25 us (16 MHz)
    clock = Clock(dut.clk, 31.25, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.uio_in.value = 1
    dut.rst_n.value = 0
    # await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # timeout_ns = 200_000
    # t = 0
    # while True:
    #     await RisingEdge(dut.clk)
    #     bits = dut.uo_out.value.binstr if hasattr(dut.uo_out.value, "binstr") else str(dut.uo_out.value)
    #     if 'x' in bits or 'z' in bits:
    #         continue
    #     if int(bits, 2) & 1:
    #         break
    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
