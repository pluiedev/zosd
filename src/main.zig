const std = @import("std");
const ZosdApplication = @import("app.zig").ZosdApplication;

pub fn main() !void {
    const app = ZosdApplication.new();
    app.run();
}
