const std = @import("std");
const Config = @import("config.zig").Config;
const EventBus = @import("event_bus.zig").EventBus;
const ChannelRegistry = @import("channels.zig").ChannelRegistry;
const SecretStore = @import("secret_store.zig").SecretStore;
const Sandbox = @import("sandbox.zig").Sandbox;
const Gateway = @import("gateway.zig").Gateway;
const Doctor = @import("doctor.zig").Doctor;

const version = "0.1.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    // Collect args into a slice
    var args_list = std.ArrayList([]const u8).init(allocator);
    defer args_list.deinit();
    while (args_iter.next()) |arg| {
        try args_list.append(arg);
    }
    const args = args_list.items;

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "serve")) {
        try runServe(allocator, args);
    } else if (std.mem.eql(u8, command, "doctor")) {
        try runDoctor(allocator, args);
    } else if (std.mem.eql(u8, command, "version")) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("nullclaw {s}\n", .{version});
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Unknown command: {s}\n\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(
        \\NullClaw Nexus - Hyper-Optimized AI Agent Gateway
        \\
        \\Usage: nullclaw <command> [options]
        \\
        \\Commands:
        \\  serve     Start the NullClaw gateway server
        \\  doctor    Run system diagnostics and connectivity checks
        \\  version   Print version information
        \\  help      Show this help message
        \\
        \\Options:
        \\  --config <path>   Path to config.json (default: ./config.json)
        \\
        \\Examples:
        \\  nullclaw serve
        \\  nullclaw serve --config /etc/nullclaw/config.json
        \\  nullclaw doctor
        \\
    );
}

fn parseConfigPath(args: []const []const u8) []const u8 {
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--config") and i + 1 < args.len) {
            return args[i + 1];
        }
    }
    return "config.json";
}

fn runServe(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const config_path = parseConfigPath(args);
    const config = try Config.loadFromFile(allocator, config_path);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Loading config from: {s}\n", .{config_path});

    // Initialize event bus
    var event_bus = EventBus.init(allocator);
    defer event_bus.deinit();

    // Initialize channel registry
    var registry = ChannelRegistry.init(allocator);
    defer registry.deinit();

    for (config.channels) |ch_cfg| {
        try registry.registerGeneric(
            ch_cfg.name,
            ch_cfg.endpoint,
            ch_cfg.auth_token_key,
            ch_cfg.enabled,
            &event_bus,
        );
    }

    // Connect all channels
    try registry.connectAll();
    try stdout.print("Registered {d} communication channels\n", .{config.channels.len});

    // Initialize secret store
    var secret_store = SecretStore.init(allocator, config.secret_store_path, "nullclaw-master");
    defer secret_store.deinit();
    secret_store.load() catch {
        try stdout.writeAll("No existing secret store found, starting fresh\n");
    };

    // Initialize sandbox
    var sandbox = Sandbox.init(allocator, config.sandbox_enabled);
    defer sandbox.deinit();
    try sandbox.allowRead("/usr");
    try sandbox.allowRead("/etc");
    try sandbox.allowRead("/tmp");
    try sandbox.allowWrite("/tmp");

    const sandbox_status = sandbox.status();
    if (sandbox_status.landlock_available) {
        try stdout.writeAll("Landlock sandbox: available\n");
    } else {
        try stdout.writeAll("Landlock sandbox: not available (running without sandbox)\n");
    }

    // Start the gateway
    var gateway = Gateway.init(allocator, config, &event_bus);
    defer gateway.deinit();

    try gateway.start();
}

fn runDoctor(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const config_path = parseConfigPath(args);
    const config = try Config.loadFromFile(allocator, config_path);

    var doctor = Doctor.init(allocator, config);
    const all_passed = try doctor.run();

    if (!all_passed) {
        std.process.exit(1);
    }
}
