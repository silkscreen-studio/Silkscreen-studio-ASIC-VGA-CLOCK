# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Check name: [ Check description / signal / parameter / result: failed / result: passed ]
checks = {
    "HSW": ["Hsync width", 7, 96, 0, 0],
    "VSW": ["Vsync width", 3, 1600, 0, 0],
    "LW": ["Line width (frame width)", 7, 800, 0, 0],
    "FH": ["Frame height", 3, 800*525, 0, 0],
    "/VA": ["Video not Active (when not in 640x480 frame)", "N/A", "N/A", 0, 0],
    "IBS": ["Border screen all white (when inverted)", "N/A", "N/A", 0, 0],
    "CLK": ["Clock simulation", "N/A", "N/A", 0, 0],
    "CLK_DO": ["Clock simulation, digit overflow", "N/A", "N/A", 0, 0],
}

hsync, px_out_6, px_out_5, px_out_4, vsync, px_out_3, px_out_2, px_out_1 = 7, 6, 5, 4, 3, 2, 1, 0

def get_uo_out (dut, signal) :
    return (int(dut.uo_out.value) >> signal) & 1

async def low_pulse_width_check (dut, CMD) :
    count = 0
    cycle = 1
    check, signal, parameter = checks [CMD][0:3]
    while True :
        await RisingEdge (dut.clk)
        cycle += 1
        low_pulse = get_uo_out (dut, signal)
        if low_pulse == 0 :
            count += 1
        elif count != 0 :
            if count != parameter :
                checks [CMD][3] += 1
                dut._log.error (f"FAILED | check: {check} | simulated: {count}, expected: {parameter } | cycle: {cycle}")
            else :
                checks [CMD][4] += 1
            count = 0

async def falling_edge_interval (dut, CMD) : 
    count = 1
    cycle = 0
    prev_state = 0
    check, signal, parameter = checks [CMD][0:3]
    
    while True :
        await RisingEdge (dut.clk)
        if prev_state == 1 and get_uo_out (dut, signal) == 0 :   # Falling edge
            if cycle != 0 : # ignore if it's the first cycle, that can be incomplete              
                if count != parameter :
                    checks [CMD][3] += 1
                    dut._log.error (f"FAILED | check: {check} | simulated: {count}, expected: {parameter} | cycle: {cycle}")
                else :
                    checks [CMD][4] += 1
            cycle += 1
            count = 1
        else :
            count += 1
        prev_state = get_uo_out (dut, signal)

def px_out_off (dut):
    return (int(dut.uo_out.value) & 0b01110111) == 0b00000000

async def px_out_inactive (dut) :
    prev_hsync_state = 0
    prev_vsync_state = 0
    h_count = 0
    v_count = 0
    while True :
        await RisingEdge (dut.clk)
        if prev_hsync_state == 0 and get_uo_out (dut, hsync) == 1 :   # Hsync rising edge
            h_count = 0
        else :
            h_count += 1
        if prev_vsync_state == 0 and get_uo_out (dut, vsync) == 1 :   # Vsync rising edge
            v_count = 0
        else :
            v_count += 1
        if (h_count < 48 or h_count >= 48 + 640 or v_count < 33 * 800 or v_count >= (33 + 480)* 800) :
            if not px_out_off (dut) :
                checks ["/VA"][3] += 1
                dut._log.error (f"FAILED | check: {checks ['/VA'][0]} | hsync count: {h_count} | vsync count: {v_count}")
            else:
                checks ["/VA"][4] += 1
        prev_hsync_state = get_uo_out (dut, hsync)
        prev_vsync_state = get_uo_out (dut, vsync)

def px_out_on (dut):
    return (int(dut.uo_out.value) & 0b01110111) == 0b01110111

async def invert_border_screen (dut) :
    prev_hsync_state = 1
    prev_vsync_state = 1
    h_count = 0
    v_count = 0
    aligned = False
    while True :
        await RisingEdge (dut.clk)
        if prev_hsync_state == 0 and get_uo_out (dut, hsync) == 1 :   # Hsync rising edge
            h_count = 0
        else :
            h_count += 1
        if prev_vsync_state == 0 and get_uo_out (dut, vsync) == 1 :   # Vsync rising edge
            v_count = 0
            aligned = True
        else :
            v_count += 1
        if aligned and not (h_count < 48 or h_count >= 48 + 640 or v_count < 33 * 800 or v_count >= (33 + 480)* 800) and (h_count == 48 or h_count == 48 + 640 - 1 or (v_count >= 33 * 800 and v_count < 34 * 800) or (v_count >= (33 + 480 - 1)* 800 and v_count < (34 + 480 - 1)* 800)) :  # in frame and on the border
            if not px_out_on (dut) :
                checks ["IBS"][3] += 1
                dut._log.error (f"FAILED | check: {checks ['IBS'][0]} | hsync count: {h_count} | vsync count: {v_count}")
            else:
                checks ["IBS"][4] += 1
        prev_hsync_state = get_uo_out (dut, hsync)
        prev_vsync_state = get_uo_out (dut, vsync)

async def clock_simulation (dut) :
    estimated_time = 0
    for t in range (2880) :         # running for 2 days
        for s in range (60) :           # increments by 60 seconds
            dut.ui_in [0].value = 1
            await ClockCycles (dut.clk, 5)
            dut.ui_in [0].value = 0
            await ClockCycles (dut.clk, 5)
        sim_min = int(dut.user_project.min_d.value) * 10 + int(dut.user_project.min_u.value)
        sim_hour = int(dut.user_project.hour_d.value) * 10 + int(dut.user_project.hour_u.value)
        simulated_time = sim_hour * 60 + sim_min
        if estimated_time == 1439 :
            estimated_time = 0
        else :
            estimated_time += 1
        if simulated_time != estimated_time :
            dut._log.error (f"CLOCK SIM FAILED | simulated time : {simulated_time:02d} min ({sim_hour:02d}:{sim_min:02d}) against estimated time : {estimated_time:02d} min ({(estimated_time // 60):02d}:{(estimated_time % 60):02d})")
            checks ["CLK"][3] += 1
        else :
            checks ["CLK"][4] += 1

        if int(dut.user_project.min_u.value) > 9:
            dut._log.error (f"CLOCK SIM FAILED | digit overflow: min_u = {int(dut.user_project.min_u.value)})")
            checks ["CLK_DO"][3] += 1
        else :
            checks ["CLK_DO"][4] += 1
        if int(dut.user_project.min_d.value) > 5:
            dut._log.error (f"CLOCK SIM FAILED | digit overflow: min_d = {int(dut.user_project.min_d.value)})")
            checks ["CLK_DO"][3] += 1
        else :
            checks ["CLK_DO"][4] += 1
        if int(dut.user_project.hour_u.value) > 9:
            dut._log.error (f"CLOCK SIM FAILED | digit overflow: hour_u = {int(dut.user_project.hour_u.value)})")
            checks ["CLK_DO"][3] += 1
        else :
            checks ["CLK_DO"][4] += 1
        if int(dut.user_project.hour_d.value) > 2:
            dut._log.error (f"CLOCK SIM FAILED | digit overflow: hour_d = {int(dut.user_project.hour_d.value)})")
            checks ["CLK_DO"][3] += 1
        else :
            checks ["CLK_DO"][4] += 1

async def log_loading_bar (dut):        # just for the fun of it
    for i in range (1, 101) :
        await ClockCycles (dut.clk, 42480)
        dut._log.info (f"  {i}%  [ {(10 - i // 10) * ' ' + i // 10 * '_'} ]")

@cocotb.test ()

async def test_vga_clock (dut):
    gl_test = False
    
    dut._log.info ("Start")

    clock = Clock (dut.clk, 40, unit="ns")
    cocotb.start_soon (clock.start ())

    dut._log.info ("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles (dut.clk, 10)
    dut.rst_n.value = 1

    cocotb.start_soon (log_loading_bar (dut))
    cocotb.start_soon (low_pulse_width_check (dut, "HSW"))
    cocotb.start_soon (low_pulse_width_check (dut, "VSW"))
    cocotb.start_soon (falling_edge_interval (dut, "LW"))
    cocotb.start_soon (falling_edge_interval (dut, "FH"))
    cocotb.start_soon (px_out_inactive (dut))
    
    await ClockCycles (dut.clk, 1260000)

    dut.ui_in [4].value = 1
    cocotb.start_soon (invert_border_screen (dut))
    await ClockCycles (dut.clk, 1260000)

    dut.ui_in [1].value = 1       # now the clock is externaly driven by ui_in [0]

    await ClockCycles (dut.clk, 50)
    if hasattr (dut.user_project, "min_u") :
        await clock_simulation (dut)
    else :
        dut._log.info ("Gate level test: skipping the clock simulation")
        gl_test = True

    if gl_test :
        dut._log.info ("GATE LEVEL TEST RESULTS:")
    else :
        dut._log.info ("PRE SYNTHESIS RESULTS:")
    for c in checks :
        dut._log.info (f"{checks[c][0]}: {checks[c][4]} passed, {checks[c][3]} failed")
        assert checks[c][3] == 0, f"FAILED: {checks[c][0]} check (some conditions failed)"
