// SPDX-License-Identifier: MPL-2.0

// GenerationContext.res - Shared context type for IR code generators

type t = {
  mutable warnings: array<CodegenError.Warning.t>,
  path: string,
  insideComponentSchemas: bool, // Whether we're generating inside ComponentSchemas module
  availableSchemas: option<array<string>>, // Schemas available in current module (for fork schemas)
  modulePrefix: string, // Module prefix for qualified references (e.g., "MisskeyIo")
}

let make = (~path, ~insideComponentSchemas=false, ~availableSchemas=?, ~modulePrefix="", ()): t => {
  warnings: [],
  path,
  insideComponentSchemas,
  availableSchemas,
  modulePrefix,
}

let addWarning = (ctx: t, warning: CodegenError.Warning.t): unit => {
  ctx.warnings->Array.push(warning)
}
