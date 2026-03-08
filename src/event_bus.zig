const std = @import("std");

pub const EventType = enum {
    agent_thought,
    tool_call,
    agent_response,
};

pub const Event = struct {
    event_type: EventType,
    payload: []const u8,
    timestamp: i64,
    channel: ?[]const u8,

    pub fn toJson(self: Event, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        try writer.writeAll("{\"type\":\"");
        try writer.writeAll(@tagName(self.event_type));
        try writer.writeAll("\",\"payload\":");
        // If payload is valid JSON, write it directly; otherwise wrap as string
        if (std.json.validate(allocator, self.payload) catch false) {
            try writer.writeAll(self.payload);
        } else {
            try std.json.stringify(self.payload, .{}, writer);
        }
        try writer.writeAll(",\"timestamp\":");
        try std.fmt.format(writer, "{d}", .{self.timestamp});
        if (self.channel) |ch| {
            try writer.writeAll(",\"channel\":\"");
            try writer.writeAll(ch);
            try writer.writeAll("\"");
        }
        try writer.writeAll("}");

        return buf.toOwnedSlice();
    }
};

pub const Subscriber = struct {
    callback: *const fn (Event) void,
    filter: ?EventType,
};

pub const EventBus = struct {
    subscribers: std.ArrayList(Subscriber),
    event_log: std.ArrayList(Event),
    mutex: std.Thread.Mutex,
    max_log_size: usize,

    pub fn init(allocator: std.mem.Allocator) EventBus {
        return .{
            .subscribers = std.ArrayList(Subscriber).init(allocator),
            .event_log = std.ArrayList(Event).init(allocator),
            .mutex = .{},
            .max_log_size = 1024,
        };
    }

    pub fn deinit(self: *EventBus) void {
        self.subscribers.deinit();
        self.event_log.deinit();
    }

    pub fn subscribe(self: *EventBus, callback: *const fn (Event) void, filter: ?EventType) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.subscribers.append(.{
            .callback = callback,
            .filter = filter,
        });
    }

    pub fn publish(self: *EventBus, event: Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Store in event log (ring buffer behavior)
        if (self.event_log.items.len >= self.max_log_size) {
            _ = self.event_log.orderedRemove(0);
        }
        self.event_log.append(event) catch {};

        // Notify subscribers
        for (self.subscribers.items) |sub| {
            if (sub.filter) |f| {
                if (f != event.event_type) continue;
            }
            sub.callback(event);
        }
    }

    pub fn publishThought(self: *EventBus, payload: []const u8, channel: ?[]const u8) void {
        self.publish(.{
            .event_type = .agent_thought,
            .payload = payload,
            .timestamp = std.time.timestamp(),
            .channel = channel,
        });
    }

    pub fn publishToolCall(self: *EventBus, payload: []const u8, channel: ?[]const u8) void {
        self.publish(.{
            .event_type = .tool_call,
            .payload = payload,
            .timestamp = std.time.timestamp(),
            .channel = channel,
        });
    }

    pub fn publishResponse(self: *EventBus, payload: []const u8, channel: ?[]const u8) void {
        self.publish(.{
            .event_type = .agent_response,
            .payload = payload,
            .timestamp = std.time.timestamp(),
            .channel = channel,
        });
    }
};
