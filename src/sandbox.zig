const std = @import("std");

/// Landlock sandboxing for the tool execution layer.
/// Uses Linux Landlock LSM (Linux Security Module) to restrict
/// filesystem access for untrusted tool execution.
pub const Sandbox = struct {
    enabled: bool,
    ruleset_fd: ?i32,
    allowed_read_paths: std.ArrayList([]const u8),
    allowed_write_paths: std.ArrayList([]const u8),

    // Landlock syscall numbers (via std.os.linux SYS enum)
    const SYS = std.os.linux.SYS;
    const LANDLOCK_CREATE_RULESET = SYS.landlock_create_ruleset;
    const LANDLOCK_ADD_RULE = SYS.landlock_add_rule;
    const LANDLOCK_RESTRICT_SELF = SYS.landlock_restrict_self;

    const LANDLOCK_ACCESS_FS_EXECUTE: u64 = 1 << 0;
    const LANDLOCK_ACCESS_FS_WRITE_FILE: u64 = 1 << 1;
    const LANDLOCK_ACCESS_FS_READ_FILE: u64 = 1 << 2;
    const LANDLOCK_ACCESS_FS_READ_DIR: u64 = 1 << 3;
    const LANDLOCK_ACCESS_FS_REMOVE_DIR: u64 = 1 << 4;
    const LANDLOCK_ACCESS_FS_REMOVE_FILE: u64 = 1 << 5;
    const LANDLOCK_ACCESS_FS_MAKE_CHAR: u64 = 1 << 6;
    const LANDLOCK_ACCESS_FS_MAKE_DIR: u64 = 1 << 7;
    const LANDLOCK_ACCESS_FS_MAKE_REG: u64 = 1 << 8;
    const LANDLOCK_ACCESS_FS_MAKE_SOCK: u64 = 1 << 9;
    const LANDLOCK_ACCESS_FS_MAKE_FIFO: u64 = 1 << 10;
    const LANDLOCK_ACCESS_FS_MAKE_BLOCK: u64 = 1 << 11;
    const LANDLOCK_ACCESS_FS_MAKE_SYM: u64 = 1 << 12;
    const LANDLOCK_ACCESS_FS_REFER: u64 = 1 << 13;
    const LANDLOCK_ACCESS_FS_TRUNCATE: u64 = 1 << 14;

    const LANDLOCK_RULE_PATH_BENEATH: u32 = 1;

    const LandlockRulesetAttr = extern struct {
        handled_access_fs: u64,
        handled_access_net: u64 = 0,
    };

    const LandlockPathBeneathAttr = extern struct {
        allowed_access: u64,
        parent_fd: i32,
        _pad: u32 = 0,
    };

    pub fn init(allocator: std.mem.Allocator, enabled: bool) Sandbox {
        return .{
            .enabled = enabled,
            .ruleset_fd = null,
            .allowed_read_paths = std.ArrayList([]const u8).init(allocator),
            .allowed_write_paths = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Sandbox) void {
        if (self.ruleset_fd) |fd| {
            std.posix.close(fd);
        }
        self.allowed_read_paths.deinit();
        self.allowed_write_paths.deinit();
    }

    /// Add a path that tools are allowed to read from.
    pub fn allowRead(self: *Sandbox, path: []const u8) !void {
        try self.allowed_read_paths.append(path);
    }

    /// Add a path that tools are allowed to write to.
    pub fn allowWrite(self: *Sandbox, path: []const u8) !void {
        try self.allowed_write_paths.append(path);
    }

    /// Check if Landlock is available on this kernel.
    pub fn isAvailable() bool {
        const attr = LandlockRulesetAttr{
            .handled_access_fs = LANDLOCK_ACCESS_FS_READ_FILE,
        };
        const rc = std.os.linux.syscall3(
            LANDLOCK_CREATE_RULESET,
            @intFromPtr(&attr),
            @sizeOf(LandlockRulesetAttr),
            0,
        );
        const signed: isize = @bitCast(rc);
        if (signed >= 0) {
            // Close the fd we just created
            std.posix.close(@intCast(signed));
            return true;
        }
        return false;
    }

    /// Create and enforce the Landlock ruleset.
    /// After calling this, the current thread is restricted.
    pub fn enforce(self: *Sandbox) !void {
        if (!self.enabled) return;

        const all_fs_access: u64 =
            LANDLOCK_ACCESS_FS_EXECUTE |
            LANDLOCK_ACCESS_FS_WRITE_FILE |
            LANDLOCK_ACCESS_FS_READ_FILE |
            LANDLOCK_ACCESS_FS_READ_DIR |
            LANDLOCK_ACCESS_FS_REMOVE_DIR |
            LANDLOCK_ACCESS_FS_REMOVE_FILE |
            LANDLOCK_ACCESS_FS_MAKE_CHAR |
            LANDLOCK_ACCESS_FS_MAKE_DIR |
            LANDLOCK_ACCESS_FS_MAKE_REG |
            LANDLOCK_ACCESS_FS_MAKE_SOCK |
            LANDLOCK_ACCESS_FS_MAKE_FIFO |
            LANDLOCK_ACCESS_FS_MAKE_BLOCK |
            LANDLOCK_ACCESS_FS_MAKE_SYM;

        const attr = LandlockRulesetAttr{
            .handled_access_fs = all_fs_access,
        };

        const rc = std.os.linux.syscall3(
            LANDLOCK_CREATE_RULESET,
            @intFromPtr(&attr),
            @sizeOf(LandlockRulesetAttr),
            0,
        );

        const signed: isize = @bitCast(rc);
        if (signed < 0) {
            // Landlock not available; degrade gracefully
            self.enabled = false;
            return;
        }

        const ruleset_fd: i32 = @intCast(signed);
        self.ruleset_fd = ruleset_fd;

        // Add read rules
        for (self.allowed_read_paths.items) |path| {
            try self.addPathRule(
                ruleset_fd,
                path,
                LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR | LANDLOCK_ACCESS_FS_EXECUTE,
            );
        }

        // Add write rules
        for (self.allowed_write_paths.items) |path| {
            try self.addPathRule(
                ruleset_fd,
                path,
                LANDLOCK_ACCESS_FS_READ_FILE |
                    LANDLOCK_ACCESS_FS_READ_DIR |
                    LANDLOCK_ACCESS_FS_WRITE_FILE |
                    LANDLOCK_ACCESS_FS_MAKE_DIR |
                    LANDLOCK_ACCESS_FS_MAKE_REG |
                    LANDLOCK_ACCESS_FS_REMOVE_DIR |
                    LANDLOCK_ACCESS_FS_REMOVE_FILE,
            );
        }

        // Enforce: restrict this thread
        // First, set no_new_privs via prctl
        const prctl_rc = std.os.linux.syscall5(
            SYS.prctl,
            38, // PR_SET_NO_NEW_PRIVS
            1,
            0,
            0,
        );
        _ = prctl_rc;

        const enforce_rc = std.os.linux.syscall3(
            LANDLOCK_RESTRICT_SELF,
            @as(usize, @intCast(ruleset_fd)),
            0,
            0,
        );
        const enforce_signed: isize = @bitCast(enforce_rc);
        if (enforce_signed < 0) {
            self.enabled = false;
        }
    }

    fn addPathRule(self: *Sandbox, ruleset_fd: i32, path: []const u8, access: u64) !void {
        _ = self;
        const fd = std.posix.open(
            @ptrCast(path.ptr),
            .{ .ACCMODE = .RDONLY, .PATH = true },
            0,
        ) catch return;
        defer std.posix.close(fd);

        const path_beneath = LandlockPathBeneathAttr{
            .allowed_access = access,
            .parent_fd = fd,
        };

        _ = std.os.linux.syscall4(
            LANDLOCK_ADD_RULE,
            @as(usize, @intCast(ruleset_fd)),
            LANDLOCK_RULE_PATH_BENEATH,
            @intFromPtr(&path_beneath),
            0,
        );
    }

    /// Return a diagnostic report of sandbox status.
    pub fn status(self: *Sandbox) SandboxStatus {
        return .{
            .enabled = self.enabled,
            .landlock_available = isAvailable(),
            .enforced = self.ruleset_fd != null,
            .read_paths = self.allowed_read_paths.items.len,
            .write_paths = self.allowed_write_paths.items.len,
        };
    }

    pub const SandboxStatus = struct {
        enabled: bool,
        landlock_available: bool,
        enforced: bool,
        read_paths: usize,
        write_paths: usize,
    };
};
