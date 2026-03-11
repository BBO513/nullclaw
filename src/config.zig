const std = @import("std");

pub const ChannelConfig = struct {
    name: []const u8,
    enabled: bool,
    endpoint: ?[]const u8 = null,
    auth_token_key: ?[]const u8 = null,
};

/// Provider configuration for LLM routing
pub const ProviderConfig = struct {
    /// Provider type: "ollama", "openai", "anthropic", "groq", "together", "openrouter", "custom"
    provider: []const u8 = "ollama",
    /// Base URL for the provider API
    base_url: []const u8 = "http://localhost:11434",
    /// API key (empty for Ollama/local providers)
    api_key: []const u8 = "",
    /// Default model to use
    model: []const u8 = "llama3.1",
};

pub const Config = struct {
    websocket_host: []const u8 = "127.0.0.1",
    websocket_port: u16 = 3000,
    http_host: []const u8 = "127.0.0.1",
    http_port: u16 = 3000,
    secret_store_path: []const u8 = "/var/lib/nullclaw/secrets.enc",
    sandbox_enabled: bool = true,
    max_memory_bytes: u64 = 1_048_576,
    channels: []const ChannelConfig = &default_channels,
    /// LLM provider routing configuration
    provider: ProviderConfig = .{},
    /// Master key for authenticating admin endpoints (e.g. /config/provider POST)
    /// If empty, falls back to NULLCLAW_MASTER_KEY env var. If both empty, admin endpoints are unprotected.
    master_key: []const u8 = "",

    pub const default_channels: [18]ChannelConfig = .{
        .{ .name = "whatsapp", .enabled = true, .endpoint = "https://api.twilio.com/2010-04-01", .auth_token_key = "WHATSAPP_TOKEN" },
        .{ .name = "twilio_sms", .enabled = true, .endpoint = "https://api.twilio.com/2010-04-01", .auth_token_key = "TWILIO_TOKEN" },
        .{ .name = "websocket", .enabled = true, .endpoint = "ws://127.0.0.1:3000/ws" },
        .{ .name = "email", .enabled = true, .endpoint = "smtp://localhost:587" },
        .{ .name = "telegram", .enabled = true, .endpoint = "https://api.telegram.org", .auth_token_key = "TELEGRAM_TOKEN" },
        .{ .name = "slack", .enabled = true, .endpoint = "https://slack.com/api", .auth_token_key = "SLACK_TOKEN" },
        .{ .name = "discord", .enabled = true, .endpoint = "https://discord.com/api/v10", .auth_token_key = "DISCORD_TOKEN" },
        .{ .name = "signal", .enabled = true, .endpoint = "https://textsecure-service.whispersystems.org" },
        .{ .name = "messenger", .enabled = true, .endpoint = "https://graph.facebook.com/v18.0", .auth_token_key = "MESSENGER_TOKEN" },
        .{ .name = "line", .enabled = true, .endpoint = "https://api.line.me/v2", .auth_token_key = "LINE_TOKEN" },
        .{ .name = "wechat", .enabled = true, .endpoint = "https://api.weixin.qq.com", .auth_token_key = "WECHAT_TOKEN" },
        .{ .name = "viber", .enabled = true, .endpoint = "https://chatapi.viber.com/pa", .auth_token_key = "VIBER_TOKEN" },
        .{ .name = "teams", .enabled = true, .endpoint = "https://graph.microsoft.com/v1.0", .auth_token_key = "TEAMS_TOKEN" },
        .{ .name = "irc", .enabled = true, .endpoint = "irc://irc.libera.chat:6697" },
        .{ .name = "matrix", .enabled = true, .endpoint = "https://matrix.org/_matrix/client/r0" },
        .{ .name = "xmpp", .enabled = true, .endpoint = "xmpp://jabber.org:5222" },
        .{ .name = "rcs", .enabled = true, .endpoint = "https://jibe.google.com/rcs" },
        .{ .name = "push_notification", .enabled = true, .endpoint = "https://fcm.googleapis.com/v1", .auth_token_key = "FCM_TOKEN" },
    };

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return Config{};
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_048_576);
        defer allocator.free(content);

        return parseJson(allocator, content);
    }

    pub fn parseJson(allocator: std.mem.Allocator, json_str: []const u8) !Config {
        var config = Config{};

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch {
            return config;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return config;

        // String fields: dupe them so they outlive parsed.deinit()
        if (root.object.get("websocket_host")) |v| {
            if (v == .string) config.websocket_host = try allocator.dupe(u8, v.string);
        }
        if (root.object.get("websocket_port")) |v| {
            if (v == .integer) config.websocket_port = @intCast(v.integer);
        }
        if (root.object.get("http_host")) |v| {
            if (v == .string) config.http_host = try allocator.dupe(u8, v.string);
        }
        if (root.object.get("http_port")) |v| {
            if (v == .integer) config.http_port = @intCast(v.integer);
        }
        if (root.object.get("secret_store_path")) |v| {
            if (v == .string) config.secret_store_path = try allocator.dupe(u8, v.string);
        }
        if (root.object.get("sandbox_enabled")) |v| {
            if (v == .bool) config.sandbox_enabled = v.bool;
        }
        if (root.object.get("max_memory_bytes")) |v| {
            if (v == .integer) config.max_memory_bytes = @intCast(v.integer);
        }

        // Master key
        if (root.object.get("master_key")) |v| {
            if (v == .string) config.master_key = try allocator.dupe(u8, v.string);
        }

        // Provider config
        if (root.object.get("provider")) |pv| {
            if (pv == .object) {
                if (pv.object.get("type")) |v| {
                    if (v == .string) config.provider.provider = try allocator.dupe(u8, v.string);
                }
                if (pv.object.get("base_url")) |v| {
                    if (v == .string) config.provider.base_url = try allocator.dupe(u8, v.string);
                }
                if (pv.object.get("api_key")) |v| {
                    if (v == .string) config.provider.api_key = try allocator.dupe(u8, v.string);
                }
                if (pv.object.get("model")) |v| {
                    if (v == .string) config.provider.model = try allocator.dupe(u8, v.string);
                }
            }
        }

        return config;
    }
};
