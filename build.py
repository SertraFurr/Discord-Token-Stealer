import subprocess
import os
import sys
import glob
import shutil

def find_zig_compiler():
    path_zig = shutil.which("zig")
    if path_zig:
        print(f"Found Zig in system PATH: {path_zig}")
        return path_zig
    for root, dirs, files in os.walk("."):
        if "zig.exe" in files:
            local_path = os.path.join(root, "zig.exe")
            print(f"Found Zig locally: {local_path}")
            return local_path 
    return None

def build():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    source_file = "main.zig"
    if not os.path.exists(source_file):
        print(f"Error: {source_file} not found.")
        return

    zig_exe = find_zig_compiler()
    if not zig_exe:
        print("Error: Zig compiler not found. Please add 'zig' to your PATH or place the zig_compiler folder in this directory.")
        print("You can download it from: https://ziglang.org/download/")
        return
    print(f"Using compiler: {zig_exe}")
    print(f"Building {source_file}...")
    
    try:
        cmd = [
            zig_exe, 
            "build-exe", 
            source_file, 
            "-O", "ReleaseFast", 
            "-fstrip",
            "-target", "x86_64-windows"
        ]
        subprocess.run(cmd, check=True)
        print("\nBuild successful!")
        
        if os.path.exists("main.exe"):
            size = os.path.getsize("main.exe")
            print(f"Artifact: main.exe")
            print(f"Size: {size} bytes ({size/1024:.2f} KB)")
            
    except subprocess.CalledProcessError as e:
        print(f"\nBuild failed with exit code {e.returncode}")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")

if __name__ == "__main__":
    build()
