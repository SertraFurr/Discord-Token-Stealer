# Discord Token Stealer in Zig

Just a random project I made using AI (Took them time) because I was bored and wanted to do something dumb with Zig.

Just a simple memory scanner that looks for the discord user token regex `[\w-]{24}\.[\w-]{6}\.[\w-]{38}` in a goofy way, because why using a regex lib !

## How to run
1. You need Zig installed (or just drop the compiler folder here).
2. Run the script:
   ```
   python build.py / or build.bat
   ```
3. Run the exe.

4. Random:
- To have a smaller exe, change the build param to something like ```"%ZIG_EXE%" build-exe %TARGET_FILE% -O ReleaseSmall -fstrip -fsingle-threaded -target x86_64-windows```
That's it. I don't know why would you use that! but it's cool isn't it (no)

No need to star this :)
