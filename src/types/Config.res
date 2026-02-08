// SPDX-License-Identifier: MPL-2.0

// Config.res - Generation configuration types

@genType
type generationStrategy =
  | Separate
  | SharedBase

@genType
type breakingChangeHandling =
  | Error
  | Warn
  | Ignore

@genType
type forkSpecConfig = {
  name: string,
  specPath: string,
}

@genType
type generationTargets = {
  rescriptApi: bool,              // Generate base ReScript API (always true by default)
  rescriptWrapper: bool,          // Generate ReScript thin wrapper (pipe-first)
  typescriptDts: bool,            // Generate .d.ts type definitions
  typescriptWrapper: bool,        // Generate TypeScript/JavaScript wrapper
}

@genType
type t = {
  specPath: string,
  forkSpecs: option<array<forkSpecConfig>>,
  outputDir: string,
  strategy: generationStrategy,
  modulePerTag: bool,
  includeTags: option<array<string>>,
  excludeTags: option<array<string>>,
  generateDiffReport: bool,
  breakingChangeHandling: breakingChangeHandling,
  generateDocOverrides: option<bool>,
  docOverrideDir: option<string>,
  targets: option<generationTargets>,  // Generation targets (what to generate)
  dtsOutputDir: option<string>,        // Output directory for .d.ts files (default: "types")
  wrapperOutputDir: option<string>,    // Output directory for wrapper files (default: "wrapper")
  baseInstanceName: option<string>,    // Subdirectory name for base instance (e.g., "misskey-io")
  baseModulePrefix: option<string>,    // Module prefix for base instance (e.g., "MisskeyIo")
}

// Default configuration
@genType
let make = (
  ~specPath,
  ~outputDir,
  ~strategy=SharedBase,
  ~modulePerTag=true,
  ~includeTags=?,
  ~excludeTags=?,
  ~generateDiffReport=true,
  ~breakingChangeHandling=Warn,
  ~forkSpecs=?,
  ~generateDocOverrides=?,
  ~docOverrideDir=?,
  ~targets=?,
  ~dtsOutputDir=?,
  ~wrapperOutputDir=?,
  ~baseInstanceName=?,
  ~baseModulePrefix=?,
  (),
) => {
  specPath,
  outputDir,
  strategy,
  modulePerTag,
  includeTags,
  excludeTags,
  generateDiffReport,
  breakingChangeHandling,
  forkSpecs,
  generateDocOverrides,
  docOverrideDir,
  targets,
  dtsOutputDir,
  wrapperOutputDir,
  baseInstanceName,
  baseModulePrefix,
}

// Default generation targets
let defaultTargets = (): generationTargets => {
  rescriptApi: true,
  rescriptWrapper: false,
  typescriptDts: false,
  typescriptWrapper: false,
}
