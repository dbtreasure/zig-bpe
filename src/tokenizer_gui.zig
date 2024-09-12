const std = @import("std");
const rl = @import("raylib");

pub const TokenizerGui = struct {
    pub fn init() !void {
        const screenWidth = 800;
        const screenHeight = 600;

        rl.initWindow(screenWidth, screenHeight, "Text Input and Display");
        defer rl.closeWindow();

        rl.setTargetFPS(60);

        var inputText: [256:0]u8 = undefined;
        @memset(&inputText, 0);
        var inputTextLength: usize = 0;

        const inputBox = rl.Rectangle{
            .x = 20,
            .y = 50,
            .width = screenWidth / 2 - 40,
            .height = screenHeight - 100,
        };

        while (!rl.windowShouldClose()) {
            // Update
            if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                if (rl.checkCollisionPointRec(rl.getMousePosition(), inputBox)) {
                    rl.setMouseCursor(rl.MouseCursor.mouse_cursor_ibeam);
                } else {
                    rl.setMouseCursor(rl.MouseCursor.mouse_cursor_default);
                }
            }

            var key = rl.getCharPressed();
            while (key > 0) {
                if ((key >= 32) and (key <= 125) and (inputTextLength < 255)) {
                    if (key <= 255) {
                        inputText[inputTextLength] = @intCast(key);
                        inputTextLength += 1;
                        inputText[inputTextLength] = 0;
                    }
                }
                key = rl.getCharPressed();
            }

            if (rl.isKeyPressed(rl.KeyboardKey.key_backspace) and (inputTextLength > 0)) {
                inputTextLength -= 1;
                inputText[inputTextLength] = 0;
            }

            // Draw
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            // Draw input box
            rl.drawRectangleRec(inputBox, rl.Color.light_gray);
            rl.drawRectangleLinesEx(inputBox, 2, rl.Color.dark_gray);
            rl.drawText("Input Text:", 20, 20, 20, rl.Color.black);
            rl.drawText(&inputText, @as(c_int, @intFromFloat(inputBox.x + 5)), @as(c_int, @intFromFloat(inputBox.y + 5)), 20, rl.Color.black);

            // Draw display box
            const displayBox = rl.Rectangle{
                .x = screenWidth / 2 + 20,
                .y = 50,
                .width = screenWidth / 2 - 40,
                .height = screenHeight - 100,
            };
            rl.drawRectangleRec(displayBox, rl.Color.white);
            rl.drawRectangleLinesEx(displayBox, 2, rl.Color.dark_gray);
            rl.drawText("Display Text:", screenWidth / 2 + 20, 20, 20, rl.Color.black);
            rl.drawText(&inputText, @as(c_int, @intFromFloat(displayBox.x + 5)), @as(c_int, @intFromFloat(displayBox.y + 5)), 20, rl.Color.black);
        }
    }
};
