---
name: ae-video-automation
description: Automate Adobe After Effects on Windows for video editing and motion graphics by generating and running ExtendScript .jsx scripts. Use when the user asks to operate AE, build compositions, animate layers or keyframes, apply effects, cut or assemble footage, or render and export videos with AE. Do not use for Premiere Pro or non-Adobe editors.
---

# AE Video Automation

After Effects has no remote API. The reliable automation path on Windows is: generate an ExtendScript `.jsx` file, run it via `AfterFX.exe -s "$.evalFile(...)"` (some builds silently exit on `-r`; the helper handles this), and read results back from a JSON log the script writes (jsx cannot return values to the shell). Never drive AE by clicking its UI unless scripting is impossible.

## Prerequisites

- Windows with After Effects installed (CC 2018+ recommended).
- The helper script `scripts/run_ae_script.ps1` handles AE discovery, wrapper injection, execution, and log collection. Always use it instead of calling AfterFX.exe directly.

## Workflow (follow in order)

1. **Locate AE.** Run:
   ```powershell
   powershell -NoProfile -File "<skill-dir>\scripts\run_ae_script.ps1" -FindAE
   ```
   - If `found=false`, tell the user AE was not detected and ask for the install path (pass it later via `-AePath`).
2. **Write the task script.** Create a `.jsx` file implementing the task. Use the API cheatsheet in [references/extendscript-api.md](references/extendscript-api.md) and copy a starting pattern from [references/recipes.md](references/recipes.md).
   - Inside the script, call `aeLog("message")` (injected by the wrapper) for progress notes.
   - Save user-facing outputs to absolute paths you control.
3. **Execute.** Run:
   ```powershell
   powershell -NoProfile -File "<skill-dir>\scripts\run_ae_script.ps1" -ScriptPath "D:\work\task.jsx"
   ```
   - Optional: `-LogPath <path>` (default `<script>.result.json`), `-KeepOpen` (leave AE open for the user to inspect), `-TimeoutMinutes <n>` (default 30), `-AePath <exe>`.
   - The script exits 0 when the log reports `status:"ok"`, 1 on script error, 3 on timeout.
4. **Read the log JSON.** Fields: `status` ("ok"/"error"), `error`, `line` (jsx line number), `log` (array of aeLog messages). On error, fix the jsx and re-run.
5. **Verify deliverables.** Confirm every output file (video, project) exists on disk before reporting success to the user.

## Hard facts to respect

- The wrapper injects `aeLog()` and a top-level try/catch. Do not redefine them; just write task code.
- Unless `-KeepOpen` is used, the wrapper closes the project **without saving** and exits AE when the script ends. Persist anything worth keeping inside your script (`app.project.save(...)` or render outputs).
- `app.project.renderQueue.render()` is synchronous — it blocks until rendering finishes, so render jobs belong inside the same script.
- ExtendScript file paths: prefer forward slashes (`"D:/work/out.mp4"`). The wrapper already normalizes its own paths.
- Never call `alert()`, `confirm()`, or `prompt()` in automation scripts — they block forever without a user. Uncaught jsx errors also pop a modal dialog that freezes automation, so keep task code inside the wrapper's try/catch.
- Some AE builds ship an ExtendScript engine **without the native `JSON` object** (symptom: `"JSON"未定义` error dialog at runtime). Do not use `JSON.stringify/parse` in task scripts on this machine; pass plain strings/numbers via `aeLog`, or inline a small serializer like the wrapper's `__ser`.
- ExtendScript decodes BOM-less `.jsx` files as the system ANSI codepage, mangling non-ASCII string literals (e.g. Chinese paths turn into `鍒朵綔`). Scripts must be UTF-8 **with BOM** — the helper already writes its wrapper that way, so keep task scripts readable by the helper rather than launching them directly.
- If an AfterFX.exe instance is already open, a new `-r` invocation may attach to or conflict with it. Prefer running with AE closed; the helper warns when a process exists.
- Newer AE versions default `Pref_SCRIPTING_FILE_NETWORK_SECURITY` to `"0"` (Preferences > Scripting & Expressions > Allow Scripts to Write Files and Access Network = off), which silently kills any jsx that writes files. Symptom: run times out with no log file. The helper auto-flips this preference in the main prefs file when AE is closed; if AE is running, toggle it manually in the UI.
- H.264 output via the render queue only exists in AE 22.x+; on older versions queue to Adobe Media Encoder (`queueInAME`) or render a lossless intermediate. See [references/recipes.md](references/recipes.md).

## When scripting is not enough

Some operations (third-party plugin UIs, roto brush propagation review) genuinely need the GUI. Only then ask the user to perform that step manually, and still keep project setup/teardown in jsx where possible.
