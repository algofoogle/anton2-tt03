import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

async def send_nibble(dut, value):
    dut.i_data.value = value
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)

async def get_byte(dut):
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    return dut.result.value

@cocotb.test()
async def test_reciprocals(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut._log.info("reset")
    dut.reset.value = 1
    await ClockCycles(dut.clk, 10)
    dut.reset.value = 0

    tests = [
        # Input, Approx'd reciprocal
        [ 1.000, 0b0_00001_0000000000],
        [ 2.000, 0b0_00000_1000000000],
        [ 4.000, 0b0_00000_0100000000],
        [ 5.000, 0b0_00000_0011001100],
        [ 6.000, 0b0_00000_0010101010],
        [ 7.000, 0b0_00000_0010010010],
        [-7.000, 0b1_11111_1101101110],
        [10.000, 0b0_00000_0001100110],
        [11.000, 0b0_00000_0001011101],
        [15.000, 0b0_00000_0001000100],
        [31.000, 0b0_00000_0000100001],
        [ 0.500, 0b0_00010_0000000000],
        [ 0.250, 0b0_00100_0000000000],
        [ 0.750, 0b0_00001_0101010000],
        [-0.875, 0b1_11110_1101101100],
        [ 0.003, 0b0_11111_1111111111],  # Saturated.
        [ 1.500, 0b0_00000_1010101000],
        [ 5.678, 0b0_00000_0010110100],
    ]

    await FallingEdge(dut.clk)

    for ioa in tests:
        i = ioa[0] # Input value (which will be converted to Q6.10 fixed-point).
        o = ioa[1] # Expected output value (reciprocal approximation also in Q6.10).
        fp = int(i*1024) & 65535 # Convert to fixed-point.
        fp3 = (fp & 0xF000) >> 12   # .
        fp2 = (fp & 0x0F00) >> 8    # ..
        fp1 = (fp & 0x00F0) >> 4    # ...
        fp0 = (fp & 0x000F) >> 0    # ...Get each of the 4 nibbles making up this fixed-point input.
        # Clock in the nibbles:
        await send_nibble(dut, fp3) # Highest nibble first
        await send_nibble(dut, fp2) # High
        await send_nibble(dut, fp1) # Low
        await send_nibble(dut, fp0) # Lowest nibble last
        # Clock out 2 bytes as the result:
        r1 = await get_byte(dut)
        r0 = await get_byte(dut)
        reciprocal_fixed = (r1 << 8) | r0
        reciprocal_float = 0
        if reciprocal_fixed & 32768:
            # Correct negative:
            reciprocal_float = -((reciprocal_fixed ^ 65535) + 1)/1024.0
        else:
            reciprocal_float = reciprocal_fixed/1024.0
        dut._log.info(
            "{mode} of {i:09f} ({fp:016b}) is ~ {ra:09f} ({rb:016b})".format(
                mode="Reciprocal",
                i=i,
                fp=fp,
                ra=reciprocal_float,
                rb=reciprocal_fixed
            )
        )
        assert o == reciprocal_fixed, \
            "Approx. {mode}recip. of {fp:016b}: expected {o:016b}, got {r:016b}"\
                .format(
                    mode="",
                    fp=fp,
                    o=o,
                    r=reciprocal_fixed
                )
