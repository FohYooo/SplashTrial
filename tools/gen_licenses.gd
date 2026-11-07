extends SceneTree
## Writes GODOT_COPYRIGHT.txt (Godot's MIT license + every third-party component's copyright and
## license text) from the running engine's own data, so it always matches the Godot version used to
## export. Ship it next to SplashTrial.exe in the download zip.
##   Godot --headless --script tools/gen_licenses.gd -- out=build/GODOT_COPYRIGHT.txt

const RULE := "-----------------------------------------------------------------------"


func _init() -> void:
	var out_path := "GODOT_COPYRIGHT.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_path = a.substr(4)
	var v := Engine.get_version_info()
	var lines: Array = []
	lines.append("Splash Trial: Godot Engine and third-party notices")
	lines.append("")
	lines.append("Splash Trial is made with Godot Engine %s (https://godotengine.org)." % v["string"])
	lines.append("The game itself: all the hard work done by Foh, Noomie and Dani, little bit of help from Claude.")
	lines.append("This file lists the open-source software inside the engine and its licenses.")
	lines.append("")
	lines.append(RULE)
	lines.append("Godot Engine (MIT License)")
	lines.append(RULE)
	lines.append(Engine.get_license_text().strip_edges())
	lines.append("")
	lines.append(RULE)
	lines.append("Third-party components included in Godot Engine")
	lines.append(RULE)
	for c in Engine.get_copyright_info():
		lines.append("")
		lines.append("Component: " + str(c["name"]))
		for part in c["parts"]:
			lines.append("  Files: " + ", ".join(part["files"]))
			for cr in part["copyright"]:
				lines.append("  Copyright: " + str(cr))
			lines.append("  License: " + str(part["license"]))
	var lic: Dictionary = Engine.get_license_info()
	var names: Array = lic.keys()
	names.sort()
	lines.append("")
	lines.append(RULE)
	lines.append("License texts")
	lines.append(RULE)
	for n in names:
		lines.append("")
		lines.append("License: " + str(n))
		lines.append("")
		lines.append(str(lic[n]).strip_edges())
	var text := "\n".join(lines) + "\n"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("gen_licenses: cannot write " + out_path)
		quit(1)
		return
	f.store_string(text.replace("\n", "\r\n"))  # CRLF so it reads cleanly in any Windows editor
	f.close()
	print("gen_licenses: wrote %s (%d components, %d license texts)" % [out_path, Engine.get_copyright_info().size(), names.size()])
	quit()
