//  ASIC design: monochrome futuristic VGA digital clock
//       Copyright © 2026 Clément G. (Silkscreen Studio)
//       SPDX-License-Identifier: Apache-2.0

// Segment design inspired by Posy (Michiel de Boer) 'Seamless' design (https://www.michieldb.nl/other/segments/)
// Posy's original design itself isn't covered by the license above

`default_nettype none

module tt_um_silkscreen_studio_clock (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go HIGH when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - LOW to reset
);

// display sync parameters:
parameter H_DISPLAY = 640;
parameter H_FRONT = 16;
parameter H_SYNC = 96;
parameter H_BACK = 48;

parameter V_DISPLAY = 480;
parameter V_FRONT = 10;
parameter V_SYNC = 2;
parameter V_BACK = 33;

parameter H_SYNC_START = H_DISPLAY + H_FRONT;
parameter H_SYNC_END = H_DISPLAY + H_FRONT + H_SYNC - 1;
parameter H_MAX = H_DISPLAY + H_FRONT + H_SYNC + H_BACK - 1;
parameter V_SYNC_START = V_DISPLAY + V_FRONT;
parameter V_SYNC_END = V_DISPLAY + V_FRONT + V_SYNC - 1;
parameter V_MAX = V_DISPLAY + V_FRONT + V_SYNC + V_BACK - 1;

reg hsync;
reg vsync;
reg BW_out;
reg BW_out_faint;

reg [9:0] px_x;
reg [9:0] px_y;
wire video_active = px_x < H_DISPLAY && px_y < V_DISPLAY;
wire h_maxxed = px_x == H_MAX || ~rst_n;
wire v_maxxed = px_y == V_MAX || ~rst_n;

always @(posedge clk) begin
    hsync <= ~(px_x >= H_SYNC_START && px_x <= H_SYNC_END);
    if (h_maxxed) px_x <= 0;
    else px_x <= px_x + 1;
end

always @(posedge clk) begin
    vsync <= ~(px_y >= V_SYNC_START && px_y <= V_SYNC_END);
    if (h_maxxed) begin
        if (v_maxxed) px_y <= 0;
        else px_y <= px_y + 1;
    end
end

assign uo_out = {hsync, {3{BW_out_faint}}, vsync, {3{BW_out}}};        // to stay coherent with the VGA PMOD pinout

assign uio_out = 0;
assign uio_oe = 0;
wire _unused_ok = &{ena, uio_in [7:5]};

reg [24:0] counter_25M_to_1;
reg tick_1Hz_int;
reg tick_2Hz;
reg tick_1Hz_ext;

reg flipflop_1_clk;
reg flipflop_2_clk;

always @(posedge clk) begin
    flipflop_1_clk <= ui_in[0];  // connect 1 Hz external clock on in[0]
    flipflop_2_clk <= flipflop_1_clk;
end

wire ext_1Hz_clk = flipflop_2_clk; 

reg ext_1Hz_clk_previous;

always @(posedge clk) ext_1Hz_clk_previous <= ext_1Hz_clk;

always @(posedge clk) begin
    if (ext_1Hz_clk && ~ext_1Hz_clk_previous) tick_1Hz_ext <= 1'b1;
    else tick_1Hz_ext <= 1'b0;
end 

reg flipflop_1_clk_sel;
reg flipflop_2_clk_sel;

always @(posedge clk) begin
    flipflop_1_clk_sel <= ui_in[1];   // 1 to select the external 1Hz clock, 0 to select the 1Hz clock derived from the 25.175MHz clock.
    flipflop_2_clk_sel <= flipflop_1_clk_sel;
end

wire clk_select = flipflop_2_clk_sel; 

wire tick_1Hz = (clk_select) ? tick_1Hz_ext : tick_1Hz_int;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        counter_25M_to_1 <= 25'b0;
        tick_1Hz_int <= 1'b0;
        tick_2Hz <= 1'b0;
    end
    else if (counter_25M_to_1 >= 25175000) begin
        counter_25M_to_1 <= 25'd1;
        tick_1Hz_int <= 1'b1;
        tick_2Hz <= 1'b1;
    end
    else if (counter_25M_to_1 == 25175000/2) begin
        tick_2Hz <= 1'b1;
        counter_25M_to_1 <= counter_25M_to_1 + 25'b1;
        tick_1Hz_int <= 1'b0;
    end
    else begin
        counter_25M_to_1 <= counter_25M_to_1 + 25'b1;
        tick_1Hz_int <= 1'b0;
        tick_2Hz <= 1'b0;
    end
end

reg [3:0] sec_u;
reg [2:0] sec_d;
reg [3:0] min_u;
reg [2:0] min_d;
reg [3:0] hour_u;
reg [1:0] hour_d; 

wire increase_min = sec_d == 3'd5 && sec_u == 4'd9;
wire increase_hour = min_d == 3'd5 && min_u == 4'd9 && increase_min;

reg flipflop_1_btnS;
reg flipflop_2_btnS;

always @(posedge clk) begin
    flipflop_1_btnS <= ui_in [2];
    flipflop_2_btnS <= flipflop_1_btnS;
end

reg flipflop_1_btnM;
reg flipflop_2_btnM;

always @(posedge clk) begin
    flipflop_1_btnM <= ui_in [3];
    flipflop_2_btnM <= flipflop_1_btnM;
end

reg flipflop_1_btnH;
reg flipflop_2_btnH;

always @(posedge clk) begin
    flipflop_1_btnH <= ui_in [4];
    flipflop_2_btnH <= flipflop_1_btnH;
end

wire button_plus_sec = flipflop_2_btnS;
wire button_plus_min = flipflop_2_btnM;
wire button_plus_hour = flipflop_2_btnH;

always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    sec_d <= 3'd0;
    sec_u <= 4'd0;
  end
  else if (tick_1Hz || (button_plus_sec && tick_2Hz)) begin
    if (sec_d >= 3'd5 && sec_u >= 4'd9) begin
      sec_d <= 3'd0;
      sec_u <= 4'd0;
    end
    else if (sec_u >= 4'd9) begin
      sec_d <= sec_d + 3'd1;
      sec_u <= 4'd0;
    end
    else begin
      sec_u <= sec_u + 4'd1;
    end
  end
end

always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    min_d <= 3'd0;
    min_u <= 4'd0;
  end
  else if ((tick_1Hz && increase_min) || (button_plus_min && tick_2Hz)) begin
    if (min_d >= 3'd5 && min_u >= 4'd9) begin
      min_d <= 3'd0;
      min_u <= 4'd0;
    end
    else if (min_u >= 4'd9) begin
      min_d <= min_d + 3'd1;
      min_u <= 4'd0;
    end
    else begin
      min_u <= min_u + 4'd1;
    end
  end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
    hour_d <= 2'd0;
    hour_u <= 4'd0;
  end
    else if ((tick_1Hz && increase_hour) || (button_plus_hour && tick_2Hz)) begin
        if (hour_d >= 2'd2 && hour_u >= 4'd3) begin
            hour_d <= 2'd0;
            hour_u <= 4'd0;
        end
        else if (hour_u >= 4'd9) begin
            hour_d <= hour_d + 2'd1;
            hour_u <= 4'd0;
        end
        else begin
            hour_u <= hour_u + 4'd1;
        end
    end
end

reg dots_on;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) dots_on <= 1'b0;
    else dots_on <= (tick_1Hz) ? ~dots_on : dots_on;
end

reg [8:0] loc_px_y;
reg [6:0] loc_px_x;

reg flipflop_1_HH_MM_SS;
reg flipflop_2_HH_MM_SS;

always @(posedge clk) begin
    flipflop_1_HH_MM_SS <= ui_in [5];
    flipflop_2_HH_MM_SS <= flipflop_1_HH_MM_SS;
end

wire flip_vert_pin = uio_in [1];
reg flipflop_1_flip_vert;
reg flipflop_2_flip_vert;
always @(posedge clk) begin
    flipflop_1_flip_vert <= flip_vert_pin;
    flipflop_2_flip_vert <= flipflop_1_flip_vert;
end
wire flip_vert = flipflop_2_flip_vert;

wire flip_horiz_pin = uio_in [0];
reg flipflop_1_flip_horiz;
reg flipflop_2_flip_horiz;
always @(posedge clk) begin
  flipflop_1_flip_horiz <= flip_horiz_pin;
  flipflop_2_flip_horiz <= flipflop_1_flip_horiz;
end
wire flip_horiz = flipflop_2_flip_horiz;

wire [9:0] px_x_m = flip_horiz ? 639 - px_x : px_x + glitch_offset;
wire [9:0] px_y_m = flip_vert ? 479 - px_y : px_y + glitch_offset;

wire HH_MM_SS = flipflop_2_HH_MM_SS;
always @(posedge clk) begin
  if (HH_MM_SS) begin
    loc_px_y <= px_y_m <= 300 ? px_y_m - 100 : ((px_y_m - 318) << 1);
    loc_px_x <=  (px_y_m >= 318 && px_x_m >= 460 && px_x_m <= 524) ? ((px_x_m) << 1) + 103:        // second 1st digit
          (px_y_m >= 318 && px_x_m >= 540 && px_x_m <= 604) ? ((px_x_m) << 1) + 71:                      // second 2nd digit
          (px_y_m <= 300 && px_x_m >= 18 && px_x_m <= 144) ? px_x_m - 18 :                               // 1st digit
          (px_y_m <= 300 && px_x_m >= 162 && px_x_m <= 288) ? px_x_m - 162 :                             // 2nd digit
          (px_y_m <= 300 && px_x_m >= 306 && px_x_m <= 334) ? px_x_m - 306 :                             // dots ":"
          (px_y_m <= 300 && px_x_m >= 352 && px_x_m <= 478) ? px_x_m - 352 :                             // 3rd digit
          (px_y_m <= 300  && px_x_m >= 496 && px_x_m <= 622) ? px_x_m - 496 :                            // 4th digit
          7'd127;                                                                                // default state
  end
  else begin
    loc_px_y <= px_y_m - 140;
    loc_px_x <= (px_x_m >= 18 && px_x_m <= 144) ? px_x_m - 18 :                   // 1st digit
          (px_x_m >= 162 && px_x_m <= 288) ? px_x_m - 162 :                             // 2nd digit
          (px_x_m >= 306 && px_x_m <= 334) ? px_x_m - 306 :                             // dots ":"
          (px_x_m >= 352 && px_x_m <= 478) ? px_x_m - 352 :                             // 3rd digit
          (px_x_m >= 496 && px_x_m <= 622) ? px_x_m - 496 :                             // 4th digit
          7'd127;                                                                 // default state
  end
end

wire fix_seam_pin = uio_in [2];

reg flipflop_1_fix_seam;
reg flipflop_2_fix_seam;

always @(posedge clk) begin
    flipflop_1_fix_seam <= fix_seam_pin;
    flipflop_2_fix_seam <= flipflop_1_fix_seam;
end

wire fix_seam = flipflop_2_fix_seam;

wire seam_gap_pin = uio_in [3];

reg flipflop_1_seam_gap;
reg flipflop_2_seam_gap;

always @(posedge clk) begin
    flipflop_1_seam_gap <= seam_gap_pin;
    flipflop_2_seam_gap <= flipflop_1_seam_gap;
end

wire seam_gap = flipflop_2_seam_gap;

wire [7:0] slanted_line_63 = loc_px_x << 1;
wire [5:0] slanted_line_26 = loc_px_x >> 1;

wire in_seg_A = loc_px_y <= 10 + slanted_line_26 && loc_px_y + 2 * (126 - 18) >= slanted_line_63 && loc_px_y + 320 - 18 >= (640 / 2) - slanted_line_26 && loc_px_y <= 28; 
wire in_seg_B = loc_px_x >= 126 - 28 && loc_px_x <= 126 && loc_px_y >= 28 + 7 && loc_px_y <= 44 + slanted_line_26;
wire in_seg_C_top = loc_px_x >= 126 - 28 && loc_px_x <= 126 && loc_px_y >= 28 + 7 && loc_px_y >= 52 + slanted_line_26 
                            && loc_px_y + 320 - 180 <= (640 / 2) -  slanted_line_26;
wire in_seg_C_bottom = loc_px_x >= 126 - 28 && loc_px_x <= 126 && loc_px_y >= 28 + 7 && loc_px_y + 320 - 188 + (!seam_gap << 3) >= (640 / 2) -  slanted_line_26 
                            && loc_px_y + 320 - 247 <= (640 / 2) -  slanted_line_26;
wire in_seg_C = in_seg_C_bottom || in_seg_C_top;
//loc_px_x >= 126 - 28 && loc_px_x <= 126 && loc_px_y >= 28 + 7 && loc_px_y >= 52 + slanted_line_26 && loc_px_y + 320 - 247 <= (640 / 2) -  slanted_line_26;
wire in_seg_D = loc_px_y >= 200 - 28 && loc_px_y <= 200 && loc_px_x <= 91 && loc_px_y + 640 * 2 - 244 >= (640 * 2) - slanted_line_63;
wire in_seg_E = loc_px_x <= 28 && loc_px_y >= 91 + slanted_line_26 && loc_px_y  <= 164 + slanted_line_63 && loc_px_y + 640 * 2 - 244 + 15 <= (640 * 2) - slanted_line_63;
wire in_seg_F_top = loc_px_x <= 28 && loc_px_y + 320 - 82 + (seam_gap << 3) <= (640 / 2) - slanted_line_26  && loc_px_y >= 18 + slanted_line_26;
wire in_seg_F_bottom = loc_px_y + 320 - 82 >= (640 / 2) - slanted_line_26 && loc_px_x <= 28 && loc_px_y <= 83 + slanted_line_26;
wire in_seg_F = in_seg_F_bottom || in_seg_F_top;
//loc_px_x <= 28 && loc_px_y <= 83 + slanted_line_26 && loc_px_y >= 18 + slanted_line_26;
wire in_seg_G = loc_px_x >= 35 && loc_px_x <= 91 && loc_px_y <= 83 + slanted_line_26 && loc_px_y >= 52 + slanted_line_26;
wire in_dot = (loc_px_y >= slanted_line_26 + 58 && loc_px_y <= slanted_line_26 + 86) || (loc_px_y >= slanted_line_26 + 114 && loc_px_y <= slanted_line_26 + 142);

wire in_seg_2_fixed = fix_seam ? in_seg_C_top || in_seg_F_bottom : 1'b0;

reg [3:0] digit;
always @(posedge clk) begin
  if (HH_MM_SS) begin
    digit <= (px_y_m >= 318 && px_x_m >= 460 && px_x_m <= 524) ? sec_d:
        (px_y_m >= 318 && px_x_m >= 540 && px_x_m <= 604) ? sec_u:
        (px_y_m <= 300 && px_x_m >= 18 && px_x_m <= 144) ? hour_d :
        (px_y_m <= 300 && px_x_m >= 162 && px_x_m <= 288) ? hour_u :
        (px_y_m <= 300 && px_x_m >= 306 && px_x_m <= 334) ? 4'd10 :      // dots ":"
        (px_y_m <= 300 && px_x_m >= 352 && px_x_m <= 478) ? min_d :
        (px_y_m <= 300 && px_x_m >= 496 && px_x_m <= 622) ? min_u :
        4'd11;                                                                             // default state
  end
  else begin
    digit <= (px_x_m >= 18 && px_x_m <= 144) ? hour_d :
        (px_x_m >= 162 && px_x_m <= 288) ? hour_u :
        (px_x_m >= 306 && px_x_m <= 334) ? 4'd10 :      // dots ":"
        (px_x_m >= 352 && px_x_m <= 478) ? min_d :
        (px_x_m >= 496 && px_x_m <= 622) ? min_u :
        4'd11;                                                             // default state
  end
end

reg displayable_digit;
reg displayable_faint_digit;

always @(*) begin
    case (digit)
    4'd0 : displayable_digit = in_seg_A || in_seg_B || in_seg_C || in_seg_D || in_seg_E || in_seg_F;
    4'd1 : displayable_digit = in_seg_B || in_seg_C;
    4'd2 : displayable_digit = in_seg_2_fixed || in_seg_A || in_seg_B || in_seg_D || in_seg_E || in_seg_G;
    4'd3 : displayable_digit = in_seg_A || in_seg_B || in_seg_C || in_seg_D || in_seg_G;
    4'd4 : displayable_digit = in_seg_B || in_seg_C || in_seg_F || in_seg_G;
    4'd5 : displayable_digit = in_seg_A || in_seg_C || in_seg_D || in_seg_F || in_seg_G;
    4'd6 : displayable_digit = in_seg_A || in_seg_C || in_seg_D || in_seg_E || in_seg_F || in_seg_G;
    4'd7 : displayable_digit = in_seg_A || in_seg_B || in_seg_C;
    4'd8 : displayable_digit = in_seg_A || in_seg_B || in_seg_C || in_seg_D || in_seg_E || in_seg_F || in_seg_G;
    4'd9 : displayable_digit = in_seg_A || in_seg_B || in_seg_C || in_seg_D || in_seg_F || in_seg_G;
    4'd10 : displayable_digit = dots_on ? in_dot : 1'b0;
    default : displayable_digit = in_seg_G;
    endcase
end

always @(*) begin
  if (digit < 4'd10) begin
    displayable_faint_digit = in_seg_A || in_seg_B || in_seg_C || in_seg_D || in_seg_E || in_seg_F || in_seg_G;
  end
  else if (digit == 4'd10) displayable_faint_digit = in_dot;
  else displayable_faint_digit = 1'b0;
end

wire invert_pin = ui_in [6];
reg flipflop_1_invert;
reg flipflop_2_invert;
always @(posedge clk) begin
    flipflop_1_invert <= invert_pin;
    flipflop_2_invert <= flipflop_1_invert;
end
wire invert = flipflop_2_invert;

wire enable_shadow_pin = ui_in [7];
reg flipflop_1_enable_shadow;
reg flipflop_2_enable_shadow;
always @(posedge clk) begin
    flipflop_1_enable_shadow <= enable_shadow_pin;
    flipflop_2_enable_shadow <= flipflop_1_enable_shadow;
end
wire enable_shadow = flipflop_2_enable_shadow;

wire styling_mode_pin = uio_in [4];
reg flipflop_1_styling_mode;
reg flipflop_2_styling_mode;
always @(posedge clk) begin
    flipflop_1_styling_mode <= styling_mode_pin;
    flipflop_2_styling_mode <= flipflop_1_styling_mode;
end
wire styling_mode_btn = flipflop_2_styling_mode;

reg [3:0] mode_style;

always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    mode_style <= 4'd0;
  end
  else if (tick_1Hz && styling_mode_btn) mode_style <= mode_style + 1;
end

wire LED_grid_layer = mode_style [1] ? (loc_px_y [1]) && (loc_px_x [1]) : (loc_px_y [1] || loc_px_y [0]) && (loc_px_x [1] || loc_px_x [0]);

wire LED_grid_pattern =  mode_style [0] ? LED_grid_layer : 1'b1;

wire sweep_blackout = px_y [8] == counter_25M_to_1 [0];
wire [1:0] base_glitch_offset = (px_x [3:1] + counter_25M_to_1 [7]) + 2 * sweep_blackout + px_y [3] + counter_25M_to_1 [14] + (counter_25M_to_1 [13] == px_y [3]) + counter_25M_to_1 [6] + (px_y [1] == counter_25M_to_1 [10]) + (loc_px_y [5] == px_x [8]);

wire [1:0] glitch_offset =  mode_style [2] ? base_glitch_offset [0] :  
                            mode_style [3] ? base_glitch_offset [1:0] : 2'b00;

always @(posedge clk) begin
  BW_out <= ((video_active) && ((LED_grid_pattern && displayable_digit) ^ invert));
  BW_out_faint <= (enable_shadow) ? ((video_active) && ((LED_grid_pattern && displayable_faint_digit) ^ invert)) : ((video_active) && ((LED_grid_pattern && displayable_digit)) ^ invert);
end
endmodule
