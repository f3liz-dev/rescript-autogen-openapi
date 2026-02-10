// SPDX-License-Identifier: MPL-2.0

// DocOverride.res - Handle documentation override from markdown files

// Generate hash of endpoint for change detection
let generateEndpointHash = (endpoint: Types.endpoint): string => {
  let parts = [
    endpoint.path,
    endpoint.method,
    endpoint.operationId->Option.getOr(""),
    endpoint.summary->Option.getOr(""),
    endpoint.description->Option.getOr(""),
  ]
  
  // Simple hash: just join and take first chars of each part
  // In production, you might want to use a proper hash function
  let combined = Array.join(parts, "|")
  let hash = combined
    ->String.split("")
    ->Array.reduce(0, (acc, char) => {
      let code = Js.String.charCodeAt(0, char)->Int.fromFloat
      mod((acc->Int.shiftLeft(5)) - acc + code, 0x7FFFFFFF)
    })
    ->Int.toString(~radix=16)
  
  hash
}

// Endpoint documentation metadata
type endpointDocMetadata = {
  endpoint: string,
  method: string,
  hash: string,
  host: option<string>,
  version: option<string>,
  operationId: option<string>,
}

// Validation result
type validationResult =
  | Valid
  | HashMismatch({expected: string, found: string})
  | MissingFile
  | ParseError(string)

// Parse markdown override file
type overrideContent = {
  metadata: endpointDocMetadata,
  defaultDescription: string,
  overrideDescription: option<string>,
  hasOverride: bool, // Whether user provided custom documentation
}

// Extract code block content from markdown between ```
let extractCodeBlock = (markdown: string): option<string> => {
  // Find the first ``` block manually
  let parts = markdown->String.split("```")
  
  // We need at least 3 parts: [before, content, after]
  if Array.length(parts) >= 3 {
    switch parts->Array.get(1) {
    | None => None
    | Some(content) => {
        let trimmed = content->String.trim
        
        // Check if content is empty or placeholder
        if trimmed == "" || trimmed == "<!-- Empty - no override -->" {
          None
        } else {
          Some(trimmed)
        }
      }
    }
  } else {
    None
  }
}

// Parse override markdown file
let parseOverrideMarkdown = (content: string): option<overrideContent> => {
  // Split into frontmatter and body
  let parts = content->String.split("---")
  
  if Array.length(parts) < 3 {
    None
  } else {
    // Parse frontmatter (parts[1])
    let frontmatter = parts->Array.get(1)->Option.getOr("")
    let body = parts->Array.slice(~start=2, ~end=Array.length(parts))->Array.join("---")->String.trim
    
    // Extract metadata from frontmatter
    let lines = frontmatter->String.split("\n")->Array.map(String.trim)
    let metadata = {
      endpoint: lines
        ->Array.find(l => l->String.startsWith("endpoint:"))
        ->Option.map(l => {
          let parts = l->String.split(":")
          parts->Array.slice(~start=1, ~end=Array.length(parts))->Array.join(":")->String.trim
        })
        ->Option.getOr(""),
      method: lines
        ->Array.find(l => l->String.startsWith("method:"))
        ->Option.map(l => l->String.split(":")->Array.get(1)->Option.getOr("")->String.trim)
        ->Option.getOr(""),
      hash: lines
        ->Array.find(l => l->String.startsWith("hash:"))
        ->Option.map(l => l->String.split(":")->Array.get(1)->Option.getOr("")->String.trim)
        ->Option.getOr(""),
      host: lines
        ->Array.find(l => l->String.startsWith("host:"))
        ->Option.flatMap(l => {
          let parts = l->String.split(":")
          parts->Array.slice(~start=1, ~end=Array.length(parts))->Array.join(":")->String.trim->Some
        }),
      version: lines
        ->Array.find(l => l->String.startsWith("version:"))
        ->Option.flatMap(l => l->String.split(":")->Array.get(1)->Option.map(String.trim)),
      operationId: lines
        ->Array.find(l => l->String.startsWith("operationId:"))
        ->Option.flatMap(l => l->String.split(":")->Array.get(1)->Option.map(String.trim)),
    }
    
    // Extract default description and override
    let defaultDescSection = body
      ->String.split("## Override")
      ->Array.get(0)
      ->Option.getOr("")
      ->String.split("## Default Description")
      ->{parts => parts->Array.slice(~start=1, ~end=Array.length(parts))}
      ->Array.join("## Default Description")
      ->String.trim
    
    let overrideSection = body
      ->String.split("## Override")
      ->{parts => parts->Array.slice(~start=1, ~end=Array.length(parts))}
      ->Array.join("## Override")
    
    let overrideDesc = extractCodeBlock(overrideSection)
    let hasOverride = overrideDesc->Option.isSome
    
    Some({
      metadata,
      defaultDescription: defaultDescSection,
      overrideDescription: overrideDesc,
      hasOverride,
    })
  }
}

// Generate markdown override file content
let generateOverrideMarkdown = (
  ~endpoint: Types.endpoint,
  ~host: option<string>=?,
  ~version: option<string>=?,
  ()
): string => {
  let hash = generateEndpointHash(endpoint)
  let operationName = CodegenUtils.generateOperationName(
    endpoint.operationId,
    endpoint.path,
    endpoint.method,
  )
  
  let defaultDesc = switch (endpoint.summary, endpoint.description) {
  | (None, None) => "No description provided."
  | (Some(s), None) => s
  | (None, Some(d)) => d
  | (Some(s), Some(d)) if s == d => s
  | (Some(s), Some(d)) => s ++ "\n\n" ++ d
  }
  
  let metadata = [
    "---",
    `endpoint: ${endpoint.path}`,
    `method: ${endpoint.method->String.toUpperCase}`,
    `hash: ${hash}`,
  ]->Array.concat(
    [
      host->Option.map(h => `host: ${h}`),
      version->Option.map(v => `version: ${v}`),
      endpoint.operationId->Option.map(id => `operationId: ${id}`),
      Some("---"),
    ]->Array.filterMap(x => x)
  )
  
  Handlebars.render(Templates.overrideMarkdown, {
      "metadataBlock": Array.join(metadata, "\n"),
      "title": endpoint.summary->Option.getOr(endpoint.path),
      "path": endpoint.path,
      "methodUpper": endpoint.method->String.toUpperCase,
      "operationName": operationName,
      "defaultDesc": defaultDesc,
    },
  )
}

// Read override from file system
@module("fs") external existsSync: string => bool = "existsSync"
@module("fs") external readFileSync: (string, {..}) => string = "readFileSync"

// Validate override hash against current endpoint
let validateOverride = (
  override: overrideContent,
  currentHash: string,
): validationResult => {
  if override.metadata.hash == currentHash {
    Valid
  } else {
    HashMismatch({expected: currentHash, found: override.metadata.hash})
  }
}

// Read and validate override with hash checking
type readResult =
  | NoOverride
  | ValidOverride(string)
  | InvalidHash({override: string, expected: string, found: string})
  | FileError(string)

let readOverrideWithValidation = (
  overrideDir: string,
  moduleName: string,
  functionName: string,
  currentHash: string,
): readResult => {
  let filePath = FileSystem.makePath(
    FileSystem.makePath(overrideDir, moduleName),
    functionName ++ ".md"
  )
  
  if existsSync(filePath) {
    try {
      let content = readFileSync(filePath, {"encoding": "utf8"})
      let parsed = parseOverrideMarkdown(content)
      
      switch parsed {
      | None => FileError("Failed to parse markdown file")
      | Some(override) => {
          // Check if user provided override
          if !override.hasOverride {
            NoOverride
          } else {
            // Validate hash
            switch validateOverride(override, currentHash) {
            | Valid => {
                switch override.overrideDescription {
                | None => NoOverride
                | Some(desc) => ValidOverride(desc)
                }
              }
            | HashMismatch({expected, found}) => {
                switch override.overrideDescription {
                | None => NoOverride
                | Some(desc) => InvalidHash({override: desc, expected, found})
                }
              }
            | MissingFile => FileError("Override file missing")
            | ParseError(msg) => FileError(msg)
            }
          }
        }
      }
    } catch {
    | JsExn(err) => FileError(err->JsExn.message->Option.getOr("Unknown error"))
    | _ => FileError("Unknown error reading file")
    }
  } else {
    NoOverride
  }
}

// Simple read for backward compatibility (no validation)
let readOverride = (overrideDir: string, moduleName: string, functionName: string): option<string> => {
  let filePath = FileSystem.makePath(
    FileSystem.makePath(overrideDir, moduleName),
    functionName ++ ".md"
  )
  
  if existsSync(filePath) {
    try {
      let content = readFileSync(filePath, {"encoding": "utf8"})
      let parsed = parseOverrideMarkdown(content)
      
      switch parsed {
      | None => None
      | Some(override) => override.overrideDescription
      }
    } catch {
    | _ => None
    }
  } else {
    None
  }
}

// Check if an override file has been customized (has user content in override section)
let isFileCustomized = (filePath: string): bool => {
  if !existsSync(filePath) {
    false
  } else {
    try {
      let content = readFileSync(filePath, {"encoding": "utf8"})
      let parsed = parseOverrideMarkdown(content)
      
      switch parsed {
      | None => false
      | Some(override) => override.hasOverride  // true if user added custom content
      }
    } catch {
    | _ => false  // If we can't read it, assume not customized
    }
  }
}

// Generate all override markdown files for an API spec
// IMPORTANT: This will NOT overwrite files that already exist with custom content
let generateOverrideFiles = (
  ~spec: Types.openAPISpec,
  ~endpoints: array<Types.endpoint>,
  ~outputDir: string,
  ~host: option<string>=?,
  ~groupByTag: bool=true,  // Whether to organize by tags or use flat structure
  ()
): array<FileSystem.fileToWrite> => {
  let version = Some(spec.info.version)
  let hostUrl = switch host {
  | Some(h) => Some(h)
  | None => spec.info.description
  }
  
  endpoints
    ->Array.map(endpoint => {
      let moduleName = if groupByTag {
        switch endpoint.tags {
        | Some(tags) => tags->Array.get(0)->Option.getOr("Default")
        | None => "Default"
        }
      } else {
        "API" // Flat structure - all in API module
      }
      
      let functionName = CodegenUtils.generateOperationName(
        endpoint.operationId,
        endpoint.path,
        endpoint.method,
      )
      
      let modulePath = FileSystem.makePath(outputDir, CodegenUtils.toPascalCase(moduleName))
      let filePath = FileSystem.makePath(modulePath, functionName ++ ".md")
      
      // Check if file already exists with custom content
      if isFileCustomized(filePath) {
        // File has been customized - skip it
        Console.log(`ℹ️  Skipping ${moduleName}/${functionName} - file already customized`)
        None
      } else {
        // File doesn't exist or has no custom content - generate it
        let content = generateOverrideMarkdown(
          ~endpoint,
          ~host=?hostUrl,
          ~version=?version,
          ()
        )
        
        Some({
          FileSystem.path: filePath,
          content: content,
        })
      }
    })
    ->Array.keepSome
}

// Generate README for override directory
let generateOverrideReadme = (~host: option<string>=?, ~version: option<string>=?, ()): string => {
  let hostInfo = host->Option.getOr("Not specified")
  let versionInfo = version->Option.getOr("Not specified")
  
  Handlebars.render(Templates.overrideReadme, {"hostInfo": hostInfo, "versionInfo": versionInfo})
}

// No automatic refresh - users should manually delete outdated files
// This is safer and forces users to review changes via git diff
//
// When an endpoint changes:
// 1. User gets a hash mismatch warning
// 2. User checks git diff to see their custom documentation
// 3. User deletes the outdated override file
// 4. User regenerates to get new template
// 5. User re-adds their custom documentation (reviewing if it's still valid)
