#!/usr/bin/env python3
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox

ACTIONS = [
    ("RemoveBloatApps", "Remove common bundled apps"),
    ("RemoveCortana", "Remove Cortana"),
    ("RemoveTeamsConsumer", "Remove Teams (consumer)"),
    ("RemoveWidgets", "Disable Widgets"),
    ("DisableTelemetry", "Disable telemetry and diagnostics"),
    ("DisableSuggestions", "Disable suggestions and consumer experiences"),
    ("RemoveOneDrive", "Uninstall OneDrive"),
    ("RevertPolicies", "Revert policy changes (telemetry, suggestions, widgets)"),
    ("RestoreApps", "Restore removed bundled apps (best effort)"),
]


def build_command(selections, what_if):
    command = ["powershell", "-ExecutionPolicy", "Bypass", "-File", "scripts\\win11-debloater.ps1"]
    if what_if:
        command.append("-WhatIf")
    for key, _ in ACTIONS:
        if selections.get(key):
            command.append(f"-{key}")
    return command


def main():
    root = tk.Tk()
    root.title("Win11 Debloater")
    root.geometry("560x520")

    vars_map = {}

    header = tk.Label(root, text="Select actions to run", font=("Segoe UI", 12, "bold"))
    header.pack(pady=10)

    list_frame = tk.Frame(root)
    list_frame.pack(fill="both", expand=True, padx=12)

    for key, label in ACTIONS:
        var = tk.BooleanVar(value=False)
        cb = tk.Checkbutton(list_frame, text=label, variable=var, anchor="w", justify="left")
        cb.pack(fill="x", pady=2)
        vars_map[key] = var

    what_if_var = tk.BooleanVar(value=True)
    what_if_cb = tk.Checkbutton(root, text="Preview actions with -WhatIf", variable=what_if_var)
    what_if_cb.pack(pady=6)

    info = tk.Label(
        root,
        text="Tip: Run as Administrator. Revert/restore options run alone and skip other actions.",
        wraplength=520,
        justify="left",
    )
    info.pack(pady=6)

    def on_run():
        selections = {key: var.get() for key, var in vars_map.items()}
        if not any(selections.values()):
            messagebox.showwarning("No selection", "Select at least one action to run.")
            return

        if selections.get("RevertPolicies") or selections.get("RestoreApps"):
            if any(
                selections.get(key)
                for key in selections
                if key not in {"RevertPolicies", "RestoreApps"}
            ):
                messagebox.showwarning(
                    "Selection adjusted",
                    "Revert/restore actions run alone; other selections will be ignored.",
                )

        command = build_command(selections, what_if_var.get())
        try:
            subprocess.run(command, check=True)
        except FileNotFoundError:
            messagebox.showerror("PowerShell not found", "PowerShell is required to run this script.")
        except subprocess.CalledProcessError as exc:
            messagebox.showerror("Execution failed", f"PowerShell exited with code {exc.returncode}.")

    button_frame = tk.Frame(root)
    button_frame.pack(pady=12)

    run_button = tk.Button(button_frame, text="Run", width=12, command=on_run)
    run_button.pack(side="left", padx=8)

    quit_button = tk.Button(button_frame, text="Close", width=12, command=root.destroy)
    quit_button.pack(side="left", padx=8)

    root.mainloop()


if __name__ == "__main__":
    sys.exit(main())
