const std = @import("std");
const EventBus = @import("event_bus.zig").EventBus;

/// Message represents a communication payload across any channel.
pub const Message = struct {
    id: u64,
    channel_name: []const u8,
    sender: []const u8,
    recipient: []const u8,
    body: []const u8,
    timestamp: i64,
    metadata: ?[]const u8,
};

/// ChannelError covers all channel operation failures.
pub const ChannelError = error{
    ConnectionFailed,
    AuthenticationFailed,
    SendFailed,
    ReceiveFailed,
    ChannelDisabled,
    Timeout,
    RateLimited,
    InvalidPayload,
};

/// Channel is the vtable-based polymorphic interface for all 18+ communication channels.
/// Each concrete channel implementation provides its own VTable with function pointers.
pub const Channel = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Send a message through this channel.
        send: *const fn (ctx: *anyopaque, recipient: []const u8, body: []const u8) ChannelError!void,
        /// Attempt to receive the next pending message, or null if none.
        receive: *const fn (ctx: *anyopaque) ChannelError!?Message,
        /// Establish a connection to the channel's backend.
        connect: *const fn (ctx: *anyopaque) ChannelError!void,
        /// Disconnect from the channel's backend.
        disconnect: *const fn (ctx: *anyopaque) void,
        /// Return the human-readable channel name.
        name: *const fn (ctx: *anyopaque) []const u8,
        /// Perform a health check on the channel.
        health_check: *const fn (ctx: *anyopaque) ChannelError!bool,
    };

    pub fn send(self: Channel, recipient: []const u8, body: []const u8) ChannelError!void {
        return self.vtable.send(self.ptr, recipient, body);
    }

    pub fn receive(self: Channel) ChannelError!?Message {
        return self.vtable.receive(self.ptr);
    }

    pub fn connect(self: Channel) ChannelError!void {
        return self.vtable.connect(self.ptr);
    }

    pub fn disconnect(self: Channel) void {
        return self.vtable.disconnect(self.ptr);
    }

    pub fn name(self: Channel) []const u8 {
        return self.vtable.name(self.ptr);
    }

    pub fn healthCheck(self: Channel) ChannelError!bool {
        return self.vtable.health_check(self.ptr);
    }
};

/// GenericChannel provides a concrete channel implementation that can be
/// parameterized for any of the 18+ supported communication backends.
pub const GenericChannel = struct {
    channel_name: []const u8,
    endpoint: ?[]const u8,
    auth_token_key: ?[]const u8,
    connected: bool,
    enabled: bool,
    event_bus: ?*EventBus,
    message_counter: u64,

    const vtable = Channel.VTable{
        .send = genericSend,
        .receive = genericReceive,
        .connect = genericConnect,
        .disconnect = genericDisconnect,
        .name = genericName,
        .health_check = genericHealthCheck,
    };

    pub fn init(
        channel_name: []const u8,
        endpoint: ?[]const u8,
        auth_token_key: ?[]const u8,
        enabled: bool,
        event_bus: ?*EventBus,
    ) GenericChannel {
        return .{
            .channel_name = channel_name,
            .endpoint = endpoint,
            .auth_token_key = auth_token_key,
            .connected = false,
            .enabled = enabled,
            .event_bus = event_bus,
            .message_counter = 0,
        };
    }

    pub fn channel(self: *GenericChannel) Channel {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    fn genericSend(ctx: *anyopaque, recipient: []const u8, body: []const u8) ChannelError!void {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        if (!self.enabled) return ChannelError.ChannelDisabled;
        if (!self.connected) return ChannelError.ConnectionFailed;

        _ = recipient;
        _ = body;

        self.message_counter += 1;

        // Publish tool_call event to the event bus
        if (self.event_bus) |bus| {
            bus.publishToolCall(self.channel_name, self.channel_name);
        }
    }

    fn genericReceive(ctx: *anyopaque) ChannelError!?Message {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        if (!self.enabled) return ChannelError.ChannelDisabled;
        if (!self.connected) return ChannelError.ConnectionFailed;
        // In a real implementation, this would poll the channel's message queue.
        return null;
    }

    fn genericConnect(ctx: *anyopaque) ChannelError!void {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        if (!self.enabled) return ChannelError.ChannelDisabled;
        // In production, this would establish the actual connection
        // (e.g., WebSocket handshake, SMTP EHLO, API auth, etc.)
        self.connected = true;
    }

    fn genericDisconnect(ctx: *anyopaque) void {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        self.connected = false;
    }

    fn genericName(ctx: *anyopaque) []const u8 {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        return self.channel_name;
    }

    fn genericHealthCheck(ctx: *anyopaque) ChannelError!bool {
        const self: *GenericChannel = @ptrCast(@alignCast(ctx));
        if (!self.enabled) return false;
        // Check endpoint reachability in a real implementation
        return self.connected;
    }
};

/// ChannelRegistry manages all registered communication channels.
pub const ChannelRegistry = struct {
    channels: std.ArrayList(Channel),
    generic_channels: std.ArrayList(GenericChannel),

    pub fn init(allocator: std.mem.Allocator) ChannelRegistry {
        return .{
            .channels = std.ArrayList(Channel).init(allocator),
            .generic_channels = std.ArrayList(GenericChannel).init(allocator),
        };
    }

    pub fn deinit(self: *ChannelRegistry) void {
        self.channels.deinit();
        self.generic_channels.deinit();
    }

    /// Register a new generic channel (does not build vtable handles yet).
    pub fn registerGeneric(
        self: *ChannelRegistry,
        channel_name: []const u8,
        endpoint: ?[]const u8,
        auth_token_key: ?[]const u8,
        enabled: bool,
        event_bus: ?*EventBus,
    ) !void {
        try self.generic_channels.append(GenericChannel.init(
            channel_name,
            endpoint,
            auth_token_key,
            enabled,
            event_bus,
        ));
    }

    /// Build Channel vtable handles from all registered GenericChannels.
    /// Must be called after all registerGeneric calls and before connectAll.
    fn buildChannelHandles(self: *ChannelRegistry) !void {
        self.channels.clearRetainingCapacity();
        for (self.generic_channels.items, 0..) |_, i| {
            try self.channels.append(self.generic_channels.items[i].channel());
        }
    }

    /// Connect all enabled channels.
    pub fn connectAll(self: *ChannelRegistry) !void {
        try self.buildChannelHandles();
        for (self.channels.items) |ch| {
            ch.connect() catch |err| {
                if (err != ChannelError.ChannelDisabled) return err;
            };
        }
    }

    /// Disconnect all channels.
    pub fn disconnectAll(self: *ChannelRegistry) void {
        for (self.channels.items) |ch| {
            ch.disconnect();
        }
    }

    /// Run health checks on all channels, returning a summary.
    pub fn healthCheckAll(self: *ChannelRegistry, allocator: std.mem.Allocator) ![]const HealthResult {
        var results = std.ArrayList(HealthResult).init(allocator);
        errdefer results.deinit();

        for (self.channels.items) |ch| {
            const healthy = ch.healthCheck() catch false;
            try results.append(.{
                .name = ch.name(),
                .healthy = healthy,
            });
        }

        return results.toOwnedSlice();
    }

    pub const HealthResult = struct {
        name: []const u8,
        healthy: bool,
    };
};
