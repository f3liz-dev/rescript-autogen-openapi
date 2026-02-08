// SPDX-License-Identifier: MPL-2.0

// GenerationContext.res - Shared context type for IR code generators

// Extracted auxiliary type that was too complex to inline
type extractedType = {
  typeName: string,
  irType: SchemaIR.irType,
  isUnboxed: bool, // Needs @unboxed annotation (for variant types from mixed unions)
}

type t = {
  mutable warnings: array<CodegenError.Warning.t>,
  mutable extractedTypes: array<extractedType>,
  mutable extractCounter: int,
  path: string,
  insideComponentSchemas: bool, // Whether we're generating inside ComponentSchemas module
  availableSchemas: option<array<string>>, // Schemas available in current module (for fork schemas)
  modulePrefix: string, // Module prefix for qualified references (e.g., "MisskeyIo")
  selfRefName: option<string>, // Schema name for self-referential type detection (e.g., "DriveFolder")
}

let make = (~path, ~insideComponentSchemas=false, ~availableSchemas=?, ~modulePrefix="", ~selfRefName=?, ()): t => {
  warnings: [],
  extractedTypes: [],
  extractCounter: 0,
  path,
  insideComponentSchemas,
  availableSchemas,
  modulePrefix,
  selfRefName,
}

let addWarning = (ctx: t, warning: CodegenError.Warning.t): unit => {
  ctx.warnings->Array.push(warning)
}

let extractType = (ctx: t, ~baseName: string, ~isUnboxed=false, irType: SchemaIR.irType): string => {
  // Check if this irType was already extracted (avoid duplicates)
  let existing = ctx.extractedTypes->Array.find(({irType: existingIr}: extractedType) =>
    SchemaIR.equals(existingIr, irType)
  )
  switch existing {
  | Some({typeName}) => typeName
  | None =>
    ctx.extractCounter = ctx.extractCounter + 1
    // ReScript type names must start with lowercase
    let lowerBaseName = switch baseName->String.charAt(0) {
    | "" => "extracted"
    | first => first->String.toLowerCase ++ baseName->String.sliceToEnd(~start=1)
    }
    let typeName = `${lowerBaseName}_${Int.toString(ctx.extractCounter)}`
    ctx.extractedTypes->Array.push({typeName, irType, isUnboxed})
    typeName
  }
}
