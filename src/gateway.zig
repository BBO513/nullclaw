const std = @import("std");
const EventBus = @import("event_bus.zig").EventBus;
const Event = @import("event_bus.zig").Event;
const Config = @import("config.zig").Config;
const ProviderConfig = @import("config.zig").ProviderConfig;

/// Escape a string for JSON output
fn appendJsonEscaped(list: *std.ArrayList(u8), input: []const u8) !void {
    for (input) |c| {
        switch (c) {
            '"' => try list.appendSlice("\\\""),
            '\\' => try list.appendSlice("\\\\"),
            '\n' => try list.appendSlice("\\n"),
            '\r' => try list.appendSlice("\\r"),
            '\t' => try list.appendSlice("\\t"),
            else => try list.append(c),
        }
    }
}

/// Gateway is the main HTTP + WebSocket server for NullClaw.
/// Routes /v1/chat/completions to configured LLM provider (Ollama, OpenAI, Anthropic, etc.)
pub const Gateway = struct {
    allocator: std.mem.Allocator,
    config: Config,
    event_bus: *EventBus,
    server: ?std.net.Server,
    running: bool,
    active_provider: ProviderConfig,
    provider_mutex: std.Thread.Mutex,
    start_time: i64,

    pub fn init(allocator: std.mem.Allocator, config: Config, event_bus: *EventBus) Gateway {
        return .{
            .allocator = allocator,
            .config = config,
            .event_bus = event_bus,
            .server = null,
            .running = false,
            .active_provider = config.provider,
            .provider_mutex = .{},
            .start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Gateway) void {
        if (self.server) |*s| {
            s.deinit();
        }
    }

    pub fn start(self: *Gateway) !void {
        const address = try std.net.Address.parseIp4(self.config.http_host, self.config.http_port);
        self.server = try address.listen(.{ .reuse_address = true });
        self.running = true;

        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            \\NullClaw Nexus Gateway v0.2.0
            \\  Chat completions:   http://{s}:{d}/v1/chat/completions
            \\  WebSocket:          ws://{s}:{d}/ws
            \\  Health:             http://{s}:{d}/health
            \\  Status:             http://{s}:{d}/status
            \\  Provider:           {s} @ {s}
            \\  Model:              {s}
            \\
            \\Gateway ready. Listening...
            \\
        , .{
            self.config.http_host, self.config.http_port,
            self.config.websocket_host, self.config.websocket_port,
            self.config.http_host, self.config.http_port,
            self.config.http_host, self.config.http_port,
            self.config.provider.provider, self.config.provider.base_url,
            self.config.provider.model,
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

        if (request.head.method == .OPTIONS) {
            try self.handleCorsPreFlight(request);
            return;
        }

        if (std.mem.eql(u8, target, "/ws")) {
            try self.handleWebSocketUpgrade(request);
        } else if (std.mem.eql(u8, target, "/v1/chat/completions")) {
            try self.handleChatCompletions(request);
        } else if (std.mem.eql(u8, target, "/health")) {
            try self.handleHealth(request);
        } else if (std.mem.eql(u8, target, "/status")) {
            try self.handleStatus(request);
        } else if (std.mem.eql(u8, target, "/config/provider")) {
            try self.handleConfigProvider(request);
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

    fn handleCorsPreFlight(_: *Gateway, request: *std.http.Server.Request) !void {
        try request.respond("", .{
            .status = .no_content,
            .extra_headers = &.{
                .{ .name = "access-control-allow-origin", .value = "*" },
                .{ .name = "access-control-allow-methods", .value = "GET, POST, OPTIONS" },
                .{ .name = "access-control-allow-headers", .value = "Content-Type, Authorization, X-Pairing-Code, X-Master-Key" },
                .{ .name = "access-control-max-age", .value = "86400" },
            },
        });
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

        const body_reader = try request.reader();
        var body_buf: [65536]u8 = undefined;
        const body_len = try body_reader.readAll(&body_buf);
        const body = body_buf[0..body_len];

        self.event_bus.publishThought(body, "openai_compat");

        // Get current provider config (thread-safe)
        const provider = blk: {
            self.provider_mutex.lock();
            defer self.provider_mutex.unlock();
            break :blk self.active_provider;
        };

        std.log.info("Forwarding to {s} at {s}", .{ provider.provider, provider.base_url });

        const response_body = self.forwardToProvider(provider, body) catch {
            const timestamp = std.time.timestamp();
            var err_buf: [2048]u8 = undefined;
            const err_response = std.fmt.bufPrint(&err_buf,
                \\{{"id":"chatcmpl-err-{d}","object":"chat.completion","created":{d},"model":"{s}","choices":[{{"index":0,"message":{{"role":"assistant","content":"Error: Could not connect to {s} provider at {s}. Please check your settings."}},"finish_reason":"stop"}}],"usage":{{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}}}
            , .{ timestamp, timestamp, provider.model, provider.provider, provider.base_url }) catch
                \\{"error":"provider_error","message":"Failed to forward request"}
            ;
            try request.respond(err_response, .{
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        };
        defer self.allocator.free(response_body);

        self.event_bus.publishResponse(response_body, "openai_compat");

        try request.respond(response_body, .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    /// Forward request to configured LLM provider via HTTP client
    fn forwardToProvider(self: *Gateway, provider: ProviderConfig, body: []const u8) ![]u8 {
        var url_buf: [2048]u8 = undefined;
        const is_anthropic = std.mem.eql(u8, provider.provider, "anthropic");
        const target_url = if (is_anthropic)
            std.fmt.bufPrint(&url_buf, "{s}/v1/messages", .{provider.base_url}) catch return error.Overflow
        else
            std.fmt.bufPrint(&url_buf, "{s}/v1/chat/completions", .{provider.base_url}) catch return error.Overflow;

        const uri = std.Uri.parse(target_url) catch return error.InvalidUri;

        var auth_buf: [1024]u8 = undefined;
        var auth_value: ?[]const u8 = null;
        if (provider.api_key.len > 0 and !is_anthropic) {
            auth_value = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{provider.api_key}) catch return error.Overflow;
        }

        // For Anthropic, transform request body
        var request_body: []const u8 = body;
        var transformed_body: ?[]u8 = null;
        defer if (transformed_body) |b| self.allocator.free(b);

        if (is_anthropic) {
            transformed_body = self.transformToAnthropicRequest(body) catch null;
            if (transformed_body) |b| request_body = b;
        }

        var client: std.http.Client = .{ .allocator = self.allocator };
        defer client.deinit();

        var server_header_buf: [16384]u8 = undefined;

        var req = blk: {
            if (is_anthropic and provider.api_key.len > 0) {
                break :blk client.open(.POST, uri, .{
                    .server_header_buffer = &server_header_buf,
                    .extra_headers = &.{
                        .{ .name = "content-type", .value = "application/json" },
                        .{ .name = "x-api-key", .value = provider.api_key },
                        .{ .name = "anthropic-version", .value = "2023-06-01" },
                    },
                }) catch return error.ConnectionFailed;
            } else if (auth_value) |av| {
                break :blk client.open(.POST, uri, .{
                    .server_header_buffer = &server_header_buf,
                    .extra_headers = &.{
                        .{ .name = "content-type", .value = "application/json" },
                        .{ .name = "authorization", .value = av },
                    },
                }) catch return error.ConnectionFailed;
            } else {
                break :blk client.open(.POST, uri, .{
                    .server_header_buffer = &server_header_buf,
                    .extra_headers = &.{
                        .{ .name = "content-type", .value = "application/json" },
                    },
                }) catch return error.ConnectionFailed;
            }
        };
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = request_body.len };
        req.send() catch return error.SendFailed;
        req.writer().writeAll(request_body) catch return error.WriteFailed;
        req.finish() catch return error.SendFailed;
        req.wait() catch return error.WaitFailed;

        if (req.response.status != .ok and req.response.status != .created) {
            std.log.err("Provider returned status: {d}", .{@intFromEnum(req.response.status)});
            return error.ProviderError;
        }

        const response_body = req.reader().readAllAlloc(self.allocator, 1024 * 1024) catch return error.ReadFailed;

        // For Anthropic, transform response to OpenAI format
        if (is_anthropic) {
            const transformed_resp = self.transformFromAnthropicResponse(response_body) catch {
                return response_body;
            };
            self.allocator.free(response_body);
            return transformed_resp;
        }

        return response_body;
    }

    /// Transform OpenAI request to Anthropic format
    fn transformToAnthropicRequest(self: *Gateway, body: []const u8) ![]u8 {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch return error.InvalidJson;
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidJson;

        const model = blk: {
            if (root.object.get("model")) |v| {
                if (v == .string) break :blk v.string;
            }
            break :blk "claude-sonnet-4-20250514";
        };

        var system_content = std.ArrayList(u8).init(self.allocator);
        defer system_content.deinit();
        var messages_json = std.ArrayList(u8).init(self.allocator);
        defer messages_json.deinit();
        var msg_count: usize = 0;

        if (root.object.get("messages")) |msgs| {
            if (msgs == .array) {
                for (msgs.array.items) |msg| {
                    if (msg != .object) continue;
                    const role_val = msg.object.get("role") orelse continue;
                    if (role_val != .string) continue;
                    const content_val = msg.object.get("content") orelse continue;
                    if (content_val != .string) continue;

                    if (std.mem.eql(u8, role_val.string, "system")) {
                        if (system_content.items.len > 0) try system_content.appendSlice("\n\n");
                        try system_content.appendSlice(content_val.string);
                    } else {
                        if (msg_count > 0) try messages_json.append(',');
                        try messages_json.appendSlice("{\"role\":\"");
                        try appendJsonEscaped(&messages_json, role_val.string);
                        try messages_json.appendSlice("\",\"content\":\"");
                        try appendJsonEscaped(&messages_json, content_val.string);
                        try messages_json.appendSlice("\"}");
                        msg_count += 1;
                    }
                }
            }
        }

        var output = std.ArrayList(u8).init(self.allocator);
        errdefer output.deinit();

        try output.appendSlice("{\"model\":\"");
        try appendJsonEscaped(&output, model);
        try output.append('"');

        if (system_content.items.len > 0) {
            try output.appendSlice(",\"system\":\"");
            try appendJsonEscaped(&output, system_content.items);
            try output.append('"');
        }

        try output.appendSlice(",\"messages\":[");
        try output.appendSlice(messages_json.items);
        try output.appendSlice("],\"max_tokens\":4096}");

        return try output.toOwnedSlice();
    }

    /// Transform Anthropic response to OpenAI format
    fn transformFromAnthropicResponse(self: *Gateway, body: []const u8) ![]u8 {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch return error.InvalidJson;
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidJson;

        var content_text: []const u8 = "";
        if (root.object.get("content")) |content| {
            if (content == .array and content.array.items.len > 0) {
                const first = content.array.items[0];
                if (first == .object) {
                    if (first.object.get("text")) |text| {
                        if (text == .string) content_text = text.string;
                    }
                }
            }
        }

        const id = blk: {
            if (root.object.get("id")) |v| if (v == .string) break :blk v.string;
            break :blk "msg-unknown";
        };
        const resp_model = blk: {
            if (root.object.get("model")) |v| if (v == .string) break :blk v.string;
            break :blk "claude";
        };

        var output = std.ArrayList(u8).init(self.allocator);
        errdefer output.deinit();

        const timestamp = std.time.timestamp();
        var ts_buf: [20]u8 = undefined;
        const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{timestamp}) catch "0";

        try output.appendSlice("{\"id\":\"");
        try appendJsonEscaped(&output, id);
        try output.appendSlice("\",\"object\":\"chat.completion\",\"created\":");
        try output.appendSlice(ts_str);
        try output.appendSlice(",\"model\":\"");
        try appendJsonEscaped(&output, resp_model);
        try output.appendSlice("\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"");
        try appendJsonEscaped(&output, content_text);
        try output.appendSlice("\"},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":0,\"completion_tokens\":0,\"total_tokens\":0}}");

        return try output.toOwnedSlice();
    }

    fn handleStatus(self: *Gateway, request: *std.http.Server.Request) !void {
        const provider = blk: {
            self.provider_mutex.lock();
            defer self.provider_mutex.unlock();
            break :blk self.active_provider;
        };

        const now = std.time.timestamp();
        const uptime = now - self.start_time;

        var response_buf: [2048]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf,
            \\{{"status":"running","version":"0.2.0","uptime_seconds":{d},"provider":{{"type":"{s}","base_url":"{s}","model":"{s}","has_api_key":{s}}}}}
        , .{
            uptime,
            provider.provider,
            provider.base_url,
            provider.model,
            if (provider.api_key.len > 0) "true" else "false",
        }) catch
            \\{"status":"running","version":"0.2.0"}
        ;

        try request.respond(response, .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleConfigProvider(self: *Gateway, request: *std.http.Server.Request) !void {
        if (request.head.method == .GET) {
            const provider = blk: {
                self.provider_mutex.lock();
                defer self.provider_mutex.unlock();
                break :blk self.active_provider;
            };

            var response_buf: [2048]u8 = undefined;
            const response = std.fmt.bufPrint(&response_buf,
                \\{{"type":"{s}","base_url":"{s}","model":"{s}","has_api_key":{s}}}
            , .{
                provider.provider,
                provider.base_url,
                provider.model,
                if (provider.api_key.len > 0) "true" else "false",
            }) catch
                \\{"error":"format_error"}
            ;

            try request.respond(response, .{
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        }

        if (request.head.method != .POST) {
            try request.respond(
                \\{"error":"method_not_allowed","message":"GET or POST required"}
            , .{
                .status = .method_not_allowed,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        }

        const body_reader = try request.reader();
        var body_buf: [8192]u8 = undefined;
        const body_len = try body_reader.readAll(&body_buf);
        const body = body_buf[0..body_len];

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            try request.respond(
                \\{"error":"invalid_json","message":"Request body must be valid JSON"}
            , .{
                .status = .bad_request,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            try request.respond(
                \\{"error":"invalid_json","message":"Expected JSON object"}
            , .{
                .status = .bad_request,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            });
            return;
        }

        {
            self.provider_mutex.lock();
            defer self.provider_mutex.unlock();

            if (root.object.get("type")) |v| {
                if (v == .string) self.active_provider.provider = self.allocator.dupe(u8, v.string) catch self.active_provider.provider;
            }
            if (root.object.get("base_url")) |v| {
                if (v == .string) self.active_provider.base_url = self.allocator.dupe(u8, v.string) catch self.active_provider.base_url;
            }
            if (root.object.get("api_key")) |v| {
                if (v == .string) self.active_provider.api_key = self.allocator.dupe(u8, v.string) catch self.active_provider.api_key;
            }
            if (root.object.get("model")) |v| {
                if (v == .string) self.active_provider.model = self.allocator.dupe(u8, v.string) catch self.active_provider.model;
            }
            std.log.info("Provider updated: {s} @ {s}", .{ self.active_provider.provider, self.active_provider.base_url });
        }

        try request.respond(
            \\{"status":"ok","message":"Provider configuration updated"}
        , .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    fn handleHealth(_: *Gateway, request: *std.http.Server.Request) !void {
        try request.respond(
            \\{"status":"healthy","service":"nullclaw-nexus","version":"0.2.0"}
        , .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "access-control-allow-origin", .value = "*" },
            },
        });
    }

    pub fn checkPort(self: *Gateway) !bool {
        const address = std.net.Address.parseIp4(self.config.http_host, self.config.http_port) catch return false;
        var server = address.listen(.{ .reuse_address = true }) catch return false;
        server.deinit();
        return true;
    }
};
