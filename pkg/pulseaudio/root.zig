//! Hand-written binds to libpulseaudio
const std = @import("std");

const c = @cImport({
    @cInclude("pulse/glib-mainloop.h");
    @cInclude("pulse/subscribe.h");
    @cInclude("pulse/introspect.h");
    @cInclude("pulse/volume.h");
});

const glib = @import("glib");

pub const VOLUME_NORM = c.PA_VOLUME_NORM;

pub const GLibMainLoop = opaque {
    pub fn new(ctx: ?*glib.MainContext) *GLibMainLoop {
        return @ptrCast(c.pa_glib_mainloop_new(@ptrCast(ctx)));
    }
    pub fn free(self: *GLibMainLoop) void {
        c.pa_glib_mainloop_free(@ptrCast(self));
    }
    pub fn getApi(self: *GLibMainLoop) *MainLoopApi {
        return @ptrCast(c.pa_glib_mainloop_get_api(@ptrCast(self)));
    }
};

pub const MainLoopApi = opaque {};
pub const Operation = opaque {};

pub const Context = opaque {
    pub fn new(mainloop: *MainLoopApi, name: [:0]const u8) *Context {
        return @ptrCast(c.pa_context_new(@ptrCast(@alignCast(mainloop)), name));
    }

    pub fn connect(
        self: *Context,
        server: ?[:0]const u8,
        flags: Flags,
        spawn_api: ?*c.pa_spawn_api,
    ) c_int {
        return c.pa_context_connect(
            @ptrCast(self),
            if (server) |server_| server_.ptr else null,
            @bitCast(flags),
            spawn_api,
        );
    }

    pub fn disconnect(self: *Context) void {
        c.pa_context_disconnect(@ptrCast(self));
    }

    pub fn getState(self: *Context) State {
        return @enumFromInt(c.pa_context_get_state(@ptrCast(self)));
    }

    pub fn setStateCallback(
        self: *Context,
        comptime T: type,
        cb: ?NotifyCallback(T),
        ud: T,
    ) void {
        c.pa_context_set_state_callback(
            @ptrCast(self),
            @ptrCast(cb),
            @ptrCast(ud),
        );
    }

    pub fn subscribe(
        self: *Context,
        mask: SubscriptionMask,
        comptime T: type,
        success_cb: ?SuccessCallback(T),
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_subscribe(
            @ptrCast(self),
            @bitCast(mask),
            @ptrCast(success_cb),
            @ptrCast(ud),
        ));
    }

    pub fn setSubscribeCallback(
        self: *Context,
        comptime T: type,
        cb: ?SubscribeCallback(T),
        ud: T,
    ) void {
        c.pa_context_set_subscribe_callback(
            @ptrCast(self),
            @ptrCast(cb),
            @ptrCast(ud),
        );
    }

    pub fn getServerInfo(
        self: *Context,
        comptime T: type,
        cb: ?*const fn (
            ctx: *Context,
            info: *const ServerInfo,
            ud: T,
        ) callconv(.c) void,
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_get_server_info(
            @ptrCast(self),
            @ptrCast(cb),
            @ptrCast(ud),
        ));
    }

    pub fn getSinkInfoByIndex(
        self: *Context,
        index: u32,
        comptime T: type,
        cb: ?SinkInfoCallback(T),
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_get_sink_info_by_index(
            @ptrCast(self),
            index,
            @ptrCast(cb),
            @ptrCast(ud),
        ));
    }

    pub fn getSinkInfoList(
        self: *Context,
        comptime T: type,
        cb: ?SinkInfoCallback(T),
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_get_sink_info_list(
            @ptrCast(self),
            @ptrCast(cb),
            @ptrCast(ud),
        ));
    }

    pub fn setSinkVolumeByIndex(
        self: *Context,
        index: u32,
        volume: *const CVolume,
        comptime T: type,
        cb: ?SuccessCallback(T),
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_set_sink_volume_by_index(
            @ptrCast(self),
            index,
            @ptrCast(volume),
            @ptrCast(cb),
            @ptrCast(ud),
        ));
    }

    pub fn setSinkMuteByIndex(
        self: *Context,
        index: u32,
        mute: bool,
        comptime T: type,
        cb: ?SuccessCallback(T),
        ud: T,
    ) ?*Operation {
        return @ptrCast(c.pa_context_set_sink_mute_by_index(
            @ptrCast(self),
            index,
            @intFromBool(mute),
            @ptrCast(cb),
            @ptrCast(ud),
        ));
    }

    pub const Flags = packed struct(c_uint) {
        no_autospawn: bool = false,
        no_fail: bool = false,
        _pad: std.meta.Int(.unsigned, @bitSizeOf(c_uint) - 2) = 0,
    };

    pub const State = enum(c_uint) {
        unconnected = 0,
        connecting,
        authorizing,
        setting_name,
        ready,
        failed,
        terminated,
        _,
    };

    pub fn NotifyCallback(comptime T: type) type {
        return *const fn (ctx: *Context, ud: T) callconv(.c) void;
    }
    pub fn SuccessCallback(comptime T: type) type {
        return *const fn (ctx: *Context, index: u32, ud: T) callconv(.c) void;
    }
    pub fn SubscribeCallback(comptime T: type) type {
        return *const fn (ctx: *Context, event: SubscriptionEvent, index: u32, ud: T) callconv(.c) void;
    }
    pub fn SinkInfoCallback(comptime T: type) type {
        return *const fn (
            ctx: *Context,
            info: ?*const SinkInfo,
            eol: c_int,
            ud: T,
        ) callconv(.c) void;
    }
};

pub const SubscriptionMask = packed struct(c_uint) {
    sink: bool = false,
    source: bool = false,
    sink_input: bool = false,
    source_output: bool = false,
    module: bool = false,
    client: bool = false,
    sample_cache: bool = false,
    server: bool = false,
    autoload: bool = false,
    card: bool = false,
    _pad: std.meta.Int(.unsigned, @bitSizeOf(c_uint) - 10) = 0,

    pub const all: SubscriptionMask = .{
        .sink = true,
        .source = true,
        .sink_input = true,
        .source_output = true,
        .module = true,
        .client = true,
        .sample_cache = true,
        .server = true,
        .autoload = true,
        .card = true,
    };
};

pub const Volume = c.pa_volume_t;

pub const CVolume = extern struct {
    channels: u8,
    values: [c.PA_CHANNELS_MAX]Volume,

    pub fn init(self: *CVolume) *CVolume {
        return @ptrCast(c.pa_cvolume_init(@ptrCast(self)));
    }
    pub fn avg(self: *const CVolume) Volume {
        return c.pa_cvolume_avg(@ptrCast(self));
    }
    pub fn set(self: *CVolume, channels: c_uint, value: Volume) *CVolume {
        return @ptrCast(c.pa_cvolume_set(@ptrCast(self), channels, value));
    }
    pub fn isValid(self: *const CVolume) bool {
        return c.pa_cvolume_valid(@ptrCast(self)) != 0;
    }
};

pub const ServerInfo = extern struct {
    v: c.pa_server_info,
};
pub const SinkInfo = extern struct {
    v: c.pa_sink_info,
};

pub const SubscriptionEvent = enum(c_uint) {
    // Use an unknowable inexhaustive enum to create a "new" type
    _,

    pub const Facility = enum(c_uint) {
        sink = 0,
        source,
        sink_input,
        sink_output,
        module,
        client,
        sample_cache,
        server,
        autoload,
        card,
        _,
    };
    pub const Type = enum(c_uint) {
        new = 0,
        change = 16,
        remove = 32,
        _,
    };

    pub fn getFacility(self: SubscriptionEvent) Facility {
        const value: c_uint = @intFromEnum(self);
        return @enumFromInt(value & c.PA_SUBSCRIPTION_EVENT_FACILITY_MASK);
    }

    pub fn getType(self: SubscriptionEvent) Type {
        const value: c_uint = @intFromEnum(self);
        return @enumFromInt(value & c.PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    }
};
