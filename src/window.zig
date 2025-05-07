const std = @import("std");

const adw = @import("adw");
const gio = @import("gio");
const glib = @import("glib");
const gobject = @import("gobject");
const gtk = @import("gtk");
const layer_shell = @import("gtk4-layer-shell");

const ZosdApplication = @import("app.zig").ZosdApplication;

const log = std.log.scoped(.zosd_window);

pub const ZosdWindow = extern struct {
    parent: Parent,
    scale: *gtk.Scale,
    mute_toggle: *gtk.ToggleButton,
    timer: c_uint,

    pub fn new(app: *gtk.Application) *ZosdWindow {
        return gobject.ext.newInstance(ZosdWindow, .{
            .application = app,
        });
    }
    pub fn as(self: *ZosdWindow, comptime T: type) *T {
        return gobject.ext.as(T, self);
    }

    pub fn update(self: *ZosdWindow) callconv(.c) void {
        const app = self.getApplication() orelse return;
        const volume = app.getVolume();

        self.mute_toggle.as(gtk.Button).setIconName(icon: {
            if (app.is_muted) break :icon "audio-volume-muted-symbolic";
            if (volume <= 0.333) break :icon "audio-volume-low-symbolic";
            if (volume > 0.333 and volume <= 0.667) break :icon "audio-volume-medium-symbolic";
            if (volume > 0.667 and volume <= 1.000) break :icon "audio-volume-high-symbolic";
            break :icon "audio-volume-overamplified-symbolic";
        });
        self.mute_toggle.setActive(@intFromBool(app.is_muted));

        self.scale.as(gtk.Range).setValue(volume);
        self.scale.as(gtk.Widget).setSensitive(@intFromBool(!app.is_muted));

        self.as(gtk.Window).present();

        if (self.timer > 0) _ = glib.Source.remove(self.timer);
        self.timer = glib.timeoutAdd(1000, didTimeout, self);
    }

    fn init(self: *ZosdWindow, _: *Class) callconv(.c) void {
        self.as(gtk.Widget).initTemplate();
        const window = self.as(gtk.Window);

        layer_shell.initForWindow(window);
        layer_shell.setLayer(window, .overlay);
        layer_shell.setAnchor(window, .top, false);
        layer_shell.setAnchor(window, .bottom, false);
        layer_shell.setAnchor(window, .left, false);
        layer_shell.setAnchor(window, .right, false);

        self.scale.setFormatValueFunc(formatScaleValue, null, glib.free);

        _ = gtk.Range.signals.change_value.connect(
            self.scale,
            *ZosdWindow,
            didValueChange,
            self,
            .{},
        );
        _ = gtk.ToggleButton.signals.toggled.connect(
            self.mute_toggle,
            *ZosdWindow,
            didMuteToggle,
            self,
            .{},
        );
    }

    fn dispose(self: *ZosdWindow) callconv(.c) void {
        self.as(gtk.Widget).disposeTemplate(getGObjectType());
        gobject.Object.virtual_methods.dispose.call(Class.parent_class, self.as(Parent));
    }

    fn didTimeout(ud: ?*anyopaque) callconv(.c) c_int {
        const self: *ZosdWindow = @ptrCast(@alignCast(ud));
        self.as(gtk.Widget).hide();
        self.timer = 0;
        return @intFromBool(false);
    }

    fn didValueChange(_: *gtk.Scale, _: gtk.ScrollType, value: f64, self: *ZosdWindow) callconv(.c) c_int {
        if (self.getApplication()) |app| app.setVolume(value);
        return @intFromBool(false);
    }
    fn didMuteToggle(btn: *gtk.ToggleButton, self: *ZosdWindow) callconv(.c) void {
        if (self.getApplication()) |app| app.setMute(btn.getActive() != 0);
    }
    fn formatScaleValue(_: *gtk.Scale, value: f64, _: ?*anyopaque) callconv(.c) [*:0]u8 {
        return glib.strdupPrintf("%.0f%%", value * 100).?;
    }

    fn getApplication(self: *ZosdWindow) ?*ZosdApplication {
        return gobject.ext.cast(ZosdApplication, self.as(gtk.Window).getApplication() orelse return null).?;
    }

    pub const Parent = adw.ApplicationWindow;

    pub const getGObjectType = gobject.ext.defineClass(ZosdWindow, .{
        .instanceInit = init,
        .classInit = Class.init,
        .parent_class = &Class.parent_class,
    });

    pub const Class = extern struct {
        parent: Parent.Class,

        pub const Instance = ZosdWindow;
        var parent_class: *Parent.Class = undefined;

        fn init(class: *Class) callconv(.c) void {
            const widget_class = gobject.ext.as(gtk.WidgetClass, class);
            gtk.ext.WidgetClass.setTemplateFromSlice(widget_class, @embedFile("zosd-window.ui"));
            gobject.Object.virtual_methods.dispose.implement(class, dispose);

            gtk.ext.impl_helpers.bindTemplateChild(class, "scale", .{});
            gtk.ext.impl_helpers.bindTemplateChild(class, "mute_toggle", .{});
        }
    };
};
