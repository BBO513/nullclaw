//! NullClaw Nexus - Hyper-Optimized AI Agent Gateway Library
//!
//! This module exports the core components of the NullClaw Nexus system:
//! - Channel vtable interfaces for 18+ communication backends
//! - Event bus for agent_thought, tool_call, agent_response events
//! - ChaCha20-Poly1305 encrypted SecretStore
//! - Landlock sandbox for tool execution
//! - HTTP/WebSocket gateway

pub const config = @import("config.zig");
pub const channels = @import("channels.zig");
pub const event_bus = @import("event_bus.zig");
pub const secret_store = @import("secret_store.zig");
pub const sandbox = @import("sandbox.zig");
pub const gateway = @import("gateway.zig");
pub const doctor = @import("doctor.zig");

// Re-export primary types
pub const Config = config.Config;
pub const Channel = channels.Channel;
pub const ChannelRegistry = channels.ChannelRegistry;
pub const EventBus = event_bus.EventBus;
pub const Event = event_bus.Event;
pub const SecretStore = secret_store.SecretStore;
pub const Sandbox = sandbox.Sandbox;
pub const Gateway = gateway.Gateway;
pub const Doctor = doctor.Doctor;

test {
    @import("std").testing.refAllDecls(@This());
}
