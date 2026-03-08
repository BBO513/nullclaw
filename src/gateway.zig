const std = @import("std");
const EventBus = @import("event_bus.zig").EventBus;
const Event = @import("event_bus.zig").Event;
const Config = @import("config.zig").Config;

/// Gateway is the main HTTP + WebSocket server for NullClaw.
/// It binds to a single port and handles:
///   - WebSocket Control Plane at /ws (upgrade)
///   - OpenAI-compatible REST at /v1/chat/completions
///   - Health endpoint at /health
pub const Gateway = struct {
    allocator: std.mem.Allocator,
    config: Config,
    event_bus: *EventBus,
    server: ?std.net.Server,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, config: Config, event_bus: *EventBus) Gateway {
        return .{
            .allocator = allocator,
            .config = config,
            .event_bus = event_bus,
            .server = null,
            .running = false,
        };
    }

    pub fn deinit(self: *Gateway) void {
        if (self.server) |*s| {
            s.deinit();
        }
    }

    /// Start the gateway, listening on the configured host:port.
    pub fn start(self: *Gateway) !void {
        const address = try std.net.Address.parseIp4(self.config.http_host, self.config.http_port);
        self.server = try address.listen(.{
            .reuse_address = true,
        });
        self.running = true;

        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            \\NullClaw Nexus Gateway v0.1.0
            \\  HTTP endpoint:      http://{s}:{d}/v1/chat/completions
            \\  WebSocket endpoint:  ws://{s}:{d}/ws
            \\  Health check:        http://{s}:{d}/health
            \\
            \\Gateway is ready. Listening...
            \\
        , .{
            self.config.http_host,      self.config.http_port,
            self.config.websocket_host, self.config.websocket_port,
            self.config.http_host,      self.config.http_port,
        });

        self.acceptLoop();
    }

    fn acceptLoop(self: *Gateway) void {
        const server = &(self.server orelse return);
        while (self.running) {
            const connection = server.accept() catch |err| {
                std.log.err("Accept error: {}", .{err});
                continue;
            };
            // Handle each connection in a new thread to avoid blocking
            const thread = std.Thread.spawn(.{}, handleConnection, .{ self, connection }) catch {
                connection.stream.close();
                continue;
            };
            thread.detach();
        }
    }

    fn handleConnection(self: *Gateway, connection: std.net.Server.Connection) void {
        defer connection.stream.close();

        var read_buffer: [8192]u8 = undefined;
        var http_server = std.http.Server.init(connection, &read_buffer);

        while (true) {
            var request = http_server.receiveHead() catch break;
            self.handleRequest(&request) catch break;
        }
    }

    fn handleRequest(self: *Gateway, request: *std.http.Server.Request) !void {
        const target = request.head.target;

        // Route based on path
        if (std.mem.eql(u8, target, "/ws")) {
            try self.handleWebSocketUpgrade(request);
        } else if (std.mem.eql(u8, target, "/v1/chat/completions")) {
            try self.handleChatCompletions(request);
        } else if (std.mem.eql(u8, target, "/health")) {
            try self.handleHealth(request);
        } else {
            try request.respond(
                \\{"error":"not_found","message":"Unknown endpoint"}
            , .{
                .status = .not_found,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
        }
    }

    fn handleWebSocketUpgrade(self: *Gateway, request: *std.http.Server.Request) !void {
        var send_buffer: [4096]u8 = undefined;
        var recv_buffer: [4096]u8 align(4) = undefined;
        var ws: std.http.WebSocket = undefined;

        const is_upgrade = try ws.init(request, &send_buffer, &recv_buffer);
        if (!is_upgrade) {
            try request.respond(
                \\{"error":"upgrade_required","message":"WebSocket upgrade required on /ws"}
            , .{
                .status = .upgrade_required,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                },
            });
            return;
        }

        // WebSocket connection established - publish event
        self.event_bus.publishResponse(
            \\{"status":"websocket_connected"}
        , "websocket");

        // Read messages from the WebSocket client
        while (true) {
            const msg = ws.readSmallMessage() catch |err| {
                switch (err) {
                    error.ConnectionClose => break,
                    else => break,
                }
            };

            switch (msg.opcode) {
                .text => {
                    // Echo the event back and publish to event bus
                    self.event_bus.publishThought(msg.data, "websocket");
                    // Echo response
                    const response_json =
                        \\{"type":"agent_response","status":"acknowledged"}
                    ;
                    ws.writeMessage(response_json, .text) catch break;
                },
                .ping => {
                    ws.writeMessage(msg.data, .pong) catch break;
                },
                .binary => {
                    self.event_bus.publishToolCall(msg.data, "websocket");
                },
                else => {},
            }
        }
    }

    fn handleChatCompletions(self: *Gateway, request: *std.http.Server.Request) !void {
        if (request.head.method != .POST) {
            try request.respond(
                \\{"error":"method_not_allowed","message":"POST required"}
            , .{
                .status = .method_not_allowed,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        }

        // Read request body
        const body_reader = try request.reader();
        var body_buf: [65536]u8 = undefined;
        const body_len = try body_reader.readAll(&body_buf);
        const body = body_buf[0..body_len];

        // Publish as agent_thought event
        self.event_bus.publishThought(body, "openai_compat");

        // Generate OpenAI-compatible response
        const timestamp = std.time.timestamp();
        var response_buf: [4096]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf,
            \\{{"id":"chatcmpl-nullclaw-{d}","object":"chat.completion","created":{d},"model":"nullclaw-nexus-v0.1","choices":[{{"index":0,"message":{{"role":"assistant","content":"NullClaw Nexus agent processing your request."}},"finish_reason":"stop"}}],"usage":{{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}}}
        , .{ timestamp, timestamp }) catch
            \\{"error":"internal_error"}
        ;

        // Publish response event
        self.event_bus.publishResponse(response, "openai_compat");

        try request.respond(response, .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleHealth(_: *Gateway, request: *std.http.Server.Request) !void {
        try request.respond(
            \\{"status":"healthy","service":"nullclaw-nexus","version":"0.1.0"}
        , .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    /// Check if the gateway can bind to the configured port.
    pub fn checkPort(self: *Gateway) !bool {
        const address = std.net.Address.parseIp4(self.config.http_host, self.config.http_port) catch return false;
        var server = address.listen(.{ .reuse_address = true }) catch return false;
        server.deinit();
        return true;
    }
};
