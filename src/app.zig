const std = @import("std");

const adw = @import("adw");
const gio = @import("gio");
const glib = @import("glib");
const gobject = @import("gobject");
const gtk = @import("gtk");
const pa = @import("pulseaudio");

const ZosdWindow = @import("window.zig").ZosdWindow;

const log = std.log.scoped(.zosd_app);

pub const ZosdApplication = extern struct {
    parent: Parent,
    window: ?*ZosdWindow = null,
    pa_ctx: *pa.Context,
    pa_loop: *pa.GLibMainLoop,
    volume: pa.CVolume,
    sink_index: u32,
    is_muted: bool,

    pub fn new() *ZosdApplication {
        return gobject.ext.newInstance(ZosdApplication, .{
            .@"application-id" = "me.pluie.Zosd",
        });
    }
    pub fn as(self: *ZosdApplication, comptime T: type) *T {
        return gobject.ext.as(T, self);
    }

    pub fn run(self: *ZosdApplication) void {
        _ = self.as(gio.Application).run(0, null);
    }

    pub fn setMute(self: *ZosdApplication, mute: bool) void {
        self.is_muted = mute;
        _ = self.pa_ctx.setSinkMuteByIndex(
            self.sink_index,
            self.is_muted,
            ?*anyopaque,
            null,
            null,
        );
    }

    pub fn getVolume(self: *ZosdApplication) f64 {
        const vol: f64 = @floatFromInt(self.volume.avg());
        const max: f64 = @floatFromInt(pa.VOLUME_NORM);
        return vol / max;
    }

    pub fn setVolume(self: *ZosdApplication, value: f64) void {
        const norm: f64 = @floatFromInt(pa.VOLUME_NORM);

        if (!self.volume.isValid()) _ = self.volume.init();
        self.volume.channels = 2;

        _ = self.volume.set(self.volume.channels, @intFromFloat(value * norm));
        _ = self.pa_ctx.setSinkVolumeByIndex(
            self.sink_index,
            &self.volume,
            ?*anyopaque,
            null,
            null,
        );
    }

    fn init(self: *ZosdApplication, _: *Class) callconv(.c) void {
        self.pa_loop = pa.GLibMainLoop.new(null);
        self.pa_ctx = pa.Context.new(self.pa_loop.getApi(), "zosd");
        self.pa_ctx.setStateCallback(*ZosdApplication, didSetState, self);

        _ = gio.Application.signals.activate.connect(
            self,
            ?*anyopaque,
            didActivate,
            null,
            .{},
        );

        _ = gio.Application.signals.shutdown.connect(
            self,
            ?*anyopaque,
            didShutdown,
            null,
            .{},
        );
    }

    fn connect(self: *ZosdApplication) callconv(.c) void {
        if (self.pa_ctx.connect(null, .{}, null) < 0) {
            log.err("failed to connect to PulseAudio", .{});
            self.as(gio.Application).quit();
        }
    }

    fn didActivate(self: *ZosdApplication, _: ?*anyopaque) callconv(.c) void {
        self.connect();
        self.window = ZosdWindow.new(self.as(gtk.Application));
    }

    fn didShutdown(self: *ZosdApplication, _: ?*anyopaque) callconv(.c) void {
        self.pa_ctx.disconnect();
        self.pa_loop.free();
    }

    pub const Parent = adw.Application;

    pub const getGObjectType = gobject.ext.defineClass(ZosdApplication, .{
        .instanceInit = init,
    });

    pub const Class = extern struct {
        parent: Parent.Class,

        pub const Instance = ZosdApplication;
    };
};

fn didSetState(ctx: *pa.Context, self: *ZosdApplication) callconv(.c) void {
    switch (ctx.getState()) {
        .ready => {
            ctx.setSubscribeCallback(*ZosdApplication, didSubscribe, self);
            _ = ctx.subscribe(
                .{ .sink = true },
                ?*anyopaque,
                null,
                null,
            );
            // _ = ctx.getServerInfo(*ZosdApplication, didGetServerInfo, self);
        },

        // Connection failed or disconnected. Retry
        .failed => {
            ctx.disconnect();
            self.connect();
        },

        .terminated => {
            self.as(gio.Application).quit();
        },

        else => {},
    }
}

fn didSubscribe(ctx: *pa.Context, event: pa.SubscriptionEvent, idx: u32, self: *ZosdApplication) callconv(.c) void {
    if (event.getType() != .change) return;

    switch (event.getFacility()) {
        .sink => {
            _ = ctx.getSinkInfoByIndex(idx, *ZosdApplication, didGetSinkInfo, self);
        },
        else => {},
    }
}

fn didGetSinkInfo(_: *pa.Context, info_: ?*const pa.SinkInfo, _: c_int, self: *ZosdApplication) callconv(.c) void {
    const info = info_ orelse return;

    self.sink_index = info.v.index;
    self.volume = @bitCast(info.v.volume);
    self.is_muted = info.v.mute != 0;

    log.debug("volume: {d} is_muted: {}", .{ self.getVolume(), self.is_muted });

    if (self.window) |window| window.update();
}
