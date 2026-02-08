// SPDX-License-Identifier: MPL-2.0

// FileSystem.res - File system operations (side effects isolated)

@module("fs") external mkdirSync: (string, {"recursive": bool}) => unit = "mkdirSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"
@module("pathe") external join: (string, string) => string = "join"
@module("pathe") external dirname: string => string = "dirname"

// Represents a file to be written
@genType
type fileToWrite = {
  path: string,
  content: string,
}

// Ensure directory exists
let ensureDir = (path: string): unit => {
  try {
    mkdirSync(dirname(path), {"recursive": true})
  } catch {
  | _ => ()
  }
}

// Write a single file to disk
let writeFile = (file: fileToWrite): result<unit, string> => {
  try {
    ensureDir(file.path)
    writeFileSync(file.path, file.content, "utf8")
    Ok()
  } catch {
  | JsExn(exn) => {
      let message = exn->JsExn.message->Option.getOr("Unknown error")
      Error(`Failed to write file ${file.path}: ${message}`)
    }
  | _ => Error(`Failed to write file ${file.path}: Unknown error`)
  }
}

// Write multiple files to disk
let writeFiles = (files: array<fileToWrite>): result<array<string>, array<string>> => {
  let successes = []
  let errors = []
  
  files->Array.forEach(file => {
    switch writeFile(file) {
    | Ok() => successes->Array.push(file.path)
    | Error(err) => errors->Array.push(err)
    }
  })
  
  if Array.length(errors) > 0 {
    Error(errors)
  } else {
    Ok(successes)
  }
}

// Helper to create a file path
let makePath = (baseDir: string, filename: string): string => {
  join(baseDir, filename)
}
