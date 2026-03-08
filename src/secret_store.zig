const std = @import("std");

/// SecretStore provides ChaCha20-Poly1305 encrypted key-value storage
/// for sensitive tokens (WhatsApp, Twilio, etc.).
pub const SecretStore = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(EncryptedEntry),
    master_key: [key_length]u8,
    store_path: []const u8,

    const key_length = 32;
    const nonce_length = 12;
    const tag_length = 16;
    const ChaCha = std.crypto.aead.chacha_poly.ChaCha20Poly1305;

    const EncryptedEntry = struct {
        ciphertext: []u8,
        nonce: [nonce_length]u8,
        tag: [tag_length]u8,
    };

    /// Initialize the secret store with a master key derived from the given passphrase.
    pub fn init(allocator: std.mem.Allocator, store_path: []const u8, passphrase: []const u8) SecretStore {
        var master_key: [key_length]u8 = undefined;
        // Derive key from passphrase using a simple hash (in production, use Argon2/scrypt)
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(passphrase);
        hasher.update("nullclaw-secret-store-salt-v1");
        hasher.final(&master_key);

        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(EncryptedEntry).init(allocator),
            .master_key = master_key,
            .store_path = store_path,
        };
    }

    pub fn deinit(self: *SecretStore) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.ciphertext);
        }
        self.entries.deinit();
        // Zero out the master key
        @memset(&self.master_key, 0);
    }

    /// Store a secret value, encrypting it with ChaCha20-Poly1305.
    pub fn put(self: *SecretStore, key_name: []const u8, plaintext: []const u8) !void {
        var nonce: [nonce_length]u8 = undefined;
        std.crypto.random.bytes(&nonce);

        const ciphertext = try self.allocator.alloc(u8, plaintext.len);
        errdefer self.allocator.free(ciphertext);

        var tag: [tag_length]u8 = undefined;
        ChaCha.encrypt(ciphertext, &tag, plaintext, key_name, nonce, self.master_key);

        // Free old entry if it exists
        if (self.entries.getPtr(key_name)) |old| {
            self.allocator.free(old.ciphertext);
        }

        try self.entries.put(key_name, .{
            .ciphertext = ciphertext,
            .nonce = nonce,
            .tag = tag,
        });
    }

    /// Retrieve and decrypt a secret value.
    pub fn get(self: *SecretStore, allocator: std.mem.Allocator, key_name: []const u8) !?[]u8 {
        const entry = self.entries.get(key_name) orelse return null;

        const plaintext = try allocator.alloc(u8, entry.ciphertext.len);
        errdefer allocator.free(plaintext);

        ChaCha.decrypt(plaintext, entry.ciphertext, entry.tag, key_name, entry.nonce, self.master_key) catch {
            allocator.free(plaintext);
            return error.AuthenticationFailed;
        };

        return plaintext;
    }

    /// Check if a key exists in the store.
    pub fn contains(self: *SecretStore, key_name: []const u8) bool {
        return self.entries.contains(key_name);
    }

    /// Remove a secret from the store.
    pub fn remove(self: *SecretStore, key_name: []const u8) void {
        if (self.entries.fetchRemove(key_name)) |kv| {
            self.allocator.free(kv.value.ciphertext);
        }
    }

    /// Return the number of stored secrets.
    pub fn count(self: *SecretStore) usize {
        return self.entries.count();
    }

    /// Persist the encrypted store to disk.
    pub fn save(self: *SecretStore) !void {
        const dir_path = std.fs.path.dirname(self.store_path) orelse ".";
        std.fs.cwd().makePath(dir_path) catch {};

        const file = try std.fs.cwd().createFile(self.store_path, .{});
        defer file.close();

        const writer = file.writer();

        // Write header magic
        try writer.writeAll("NCSS"); // NullClaw Secret Store
        try writer.writeInt(u32, 1, .little); // version

        // Write entry count
        try writer.writeInt(u32, @intCast(self.entries.count()), .little);

        // Write each entry
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            // Key name length + data
            try writer.writeInt(u32, @intCast(entry.key_ptr.len), .little);
            try writer.writeAll(entry.key_ptr.*);

            // Nonce
            try writer.writeAll(&entry.value_ptr.nonce);

            // Tag
            try writer.writeAll(&entry.value_ptr.tag);

            // Ciphertext length + data
            try writer.writeInt(u32, @intCast(entry.value_ptr.ciphertext.len), .little);
            try writer.writeAll(entry.value_ptr.ciphertext);
        }
    }

    /// Load the encrypted store from disk.
    pub fn load(self: *SecretStore) !void {
        const file = std.fs.cwd().openFile(self.store_path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const reader = file.reader();

        // Read and verify header
        var magic: [4]u8 = undefined;
        _ = try reader.readAll(&magic);
        if (!std.mem.eql(u8, &magic, "NCSS")) return error.InvalidFormat;

        const version = try reader.readInt(u32, .little);
        if (version != 1) return error.InvalidFormat;

        const entry_count = try reader.readInt(u32, .little);

        var i: u32 = 0;
        while (i < entry_count) : (i += 1) {
            // Read key name
            const key_len = try reader.readInt(u32, .little);
            const key_buf = try self.allocator.alloc(u8, key_len);
            defer self.allocator.free(key_buf);
            _ = try reader.readAll(key_buf);

            // Read nonce
            var nonce: [nonce_length]u8 = undefined;
            _ = try reader.readAll(&nonce);

            // Read tag
            var tag: [tag_length]u8 = undefined;
            _ = try reader.readAll(&tag);

            // Read ciphertext
            const ct_len = try reader.readInt(u32, .little);
            const ciphertext = try self.allocator.alloc(u8, ct_len);
            errdefer self.allocator.free(ciphertext);
            _ = try reader.readAll(ciphertext);

            try self.entries.put(key_buf, .{
                .ciphertext = ciphertext,
                .nonce = nonce,
                .tag = tag,
            });
        }
    }
};
