// SPDX-License-Identifier: MPL-2.0

// Pipeline.res - Compact data transformation pipeline
open Types

@genType
type t = {
  files: array<FileSystem.fileToWrite>,
  warnings: array<warning>,
}

let empty = {files: [], warnings: []}

// Combine two pipelines
let merge = (a, b) => {
  files: Array.concat(a.files, b.files),
  warnings: Array.concat(a.warnings, b.warnings),
}

// Pipe-first API
let combine = outputs => {
  files: outputs->Array.flatMap(p => p.files),
  warnings: outputs->Array.flatMap(p => p.warnings),
}

let addFile = (file, p) => {...p, files: Array.concat(p.files, [file])}
let addFiles = (files, p) => {...p, files: Array.concat(p.files, files)}
let addWarning = (warning, p) => {...p, warnings: Array.concat(p.warnings, [warning])}
let addWarnings = (warnings, p) => {...p, warnings: Array.concat(p.warnings, warnings)}

let mapFiles = (fn, p) => {...p, files: p.files->Array.map(fn)}
let filterWarnings = (pred, p) => {...p, warnings: p.warnings->Array.filter(pred)}

// Constructors
let make = (~files=[], ~warnings=[], ()) => {files, warnings}
let fromFile = file => make(~files=[file], ())
let fromFiles = files => make(~files, ())
let fromWarning = warning => make(~warnings=[warning], ())
let fromWarnings = warnings => make(~warnings, ())

// Accessors
let files = p => p.files
let warnings = p => p.warnings
let fileCount = p => Array.length(p.files)
let warningCount = p => Array.length(p.warnings)
let filePaths = p => p.files->Array.map(f => f.path)

// Legacy aliases for compatibility during migration
type generationOutput = t
let withWarnings = (p, w) => addWarnings(w, p)
let withFiles = (p, f) => addFiles(f, p)
let fromFilesAndWarnings = (files, warnings) => make(~files, ~warnings, ())
