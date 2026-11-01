## How it works

A monochrome VGA digital clock, 640x480, with stylized segmented digits. The time is displayed in the `HH:MM` format, can be set using 2 buttons (hold to increment), and an invert pin inverts the display. It either works in standalone mode (time obtained from the `25.175 MHz` core frequency) or with an external `1 Hz` clock (to get more precision with an RTC)

![Segmented clock on a VGA monitor](render_monitor.jpg)

The `px_x` and `px_y` counters in the VGA timing generation for Hsync and Vsync are the screen coordinates the procedural segment construction uses to draw the segments pixel after pixel. Each digit is decided with the current `HH:MM` values, and the `1 Hz` tick that updates the time is either derived from the `25.175 MHz` clock or from an edge-detected external clock.

## How to test

After hooking up a VGA monitor and the few additional hardware, with the chip running at `25.175 MHz`, the monitor should show `00:00` upon reset. Holding the buttons `H++` (`ui_in[3]`) or `M++` (`ui_in[2]`) increments the hours or minutes every `500 ms`. Release to set the time. Toggling the invert pin (`ui_in[4]`) inverts the B&W image. To run in standalone mode (`1 Hz` tick derived from the `25.175 MHz` clock), the `clock select` pin needs to be set to `LOW` (`ui_in[1]`), and when using an external clock (`clock select` to `HIGH`), a `1 Hz` clock needs to be provided on `ui_in[0]`

## External hardware

Using here the same VGA pinout as the Tiny VGA PMOD for compatibility, only using here `Hsync`, `Vsync` with `BW_out` outputted on all color channels. 2 buttons and 2 switches for the clock configuration are required too, and a `1 Hz` external clock (from an RTC for example) is optional. 

