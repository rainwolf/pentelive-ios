# Usage: ruby Scripts/add_swift_file.rb <relative_file_path> <target_name> <group_path>
#
# Adds a source file reference to an Xcode group and the given target's compile
# sources phase. File references are created group-relative (bare basename +
# sourceTree "<group>") to avoid path doubling, matching how the existing
# PenteEngine files (Capture.swift, Scan.swift) are referenced.
require "xcodeproj"

rel_path, target_name, group_path = ARGV
abort("usage: add_swift_file.rb <path> <target> <group>") unless rel_path && target_name && group_path

project = Xcodeproj::Project.open("penteLive.xcodeproj")
target  = project.targets.find { |t| t.name == target_name } or abort("no target #{target_name}")

# Locate the existing group whose on-disk path matches group_path; create it if absent.
target_real = File.expand_path(group_path)
group = project.objects.select { |o| o.isa == "PBXGroup" }.find do |g|
  begin
    g.real_path.to_s == target_real
  rescue StandardError
    false
  end
end
group ||= project.main_group.find_subpath(group_path, true)

basename = File.basename(rel_path)
ref = group.files.find { |f| f.display_name == basename || f.path == basename }
unless ref
  ref = group.new_reference(basename)
  ref.set_path(basename)
  ref.source_tree = "<group>"
end

already = target.source_build_phase.files_references.include?(ref)
target.add_file_references([ref]) unless already
project.save
puts "added #{basename} to #{target_name} via group #{group.display_name} (#{already ? "already present" : "new"})"
