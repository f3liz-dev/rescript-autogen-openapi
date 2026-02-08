// SPDX-License-Identifier: MPL-2.0

// Error.res - Compact error and warning types with helpers

// Error context for debugging (defined here to avoid circular dependency)
@genType
type context = {
  path: string,
  operation: string,
  schema: option<JSON.t>, // Use JSON.t to avoid circular dependency with Types.jsonSchema
}

// Structured error types (keep original names for backward compat)
@genType
type t =
  | SpecResolutionError({url: string, message: string})
  | SchemaParseError({context: context, reason: string})
  | ReferenceError({ref: string, context: context})
  | ValidationError({schema: string, input: JSON.t, issues: array<string>})
  | CircularSchemaError({ref: string, depth: int, path: string})
  | FileWriteError({filePath: string, message: string})
  | InvalidConfigError({field: string, message: string})
  | UnknownError({message: string, context: option<context>})

// Warning types
module Warning = {
  @genType
  type t =
    | FallbackToJson({reason: string, context: context})
    | UnsupportedFeature({feature: string, fallback: string, location: string})
    | DepthLimitReached({depth: int, path: string})
    | MissingSchema({ref: string, location: string})
    | IntersectionNotFullySupported({location: string, note: string})
    | ComplexUnionSimplified({location: string, types: string})

  let toString = w =>
    switch w {
    | FallbackToJson({reason, context}) =>
      `⚠️  Falling back to JSON.t at '${context.path}' (${context.operation}): ${reason}`
    | UnsupportedFeature({feature, fallback, location}) =>
      `⚠️  Unsupported feature '${feature}' at '${location}', using fallback: ${fallback}`
    | DepthLimitReached({depth, path}) =>
      `⚠️  Depth limit ${depth->Int.toString} reached at '${path}', using simplified type`
    | MissingSchema({ref, location}) =>
      `⚠️  Schema reference '${ref}' not found at '${location}'`
    | IntersectionNotFullySupported({location, note}) =>
      `⚠️  Intersection type at '${location}' not fully supported: ${note}`
    | ComplexUnionSimplified({location, types}) =>
      `⚠️  Complex union at '${location}' simplified (types: ${types})`
    }

  let print = warnings =>
    if Array.length(warnings) > 0 {
      Console.log("\n⚠️  Warnings:")
      warnings->Array.forEach(w => Console.log(toString(w)))
    }
}

// Error helpers
let toString = e =>
  switch e {
  | SpecResolutionError({url, message}) => `Failed to resolve spec from '${url}': ${message}`
  | SchemaParseError({context, reason}) =>
    `Failed to parse schema at '${context.path}' (${context.operation}): ${reason}`
  | ReferenceError({ref, context}) =>
    `Failed to resolve reference '${ref}' at '${context.path}' (${context.operation})`
  | ValidationError({schema, issues}) =>
    `Validation failed for schema '${schema}': ${issues->Array.join(", ")}`
  | CircularSchemaError({ref, depth, path}) =>
    `Circular schema detected for '${ref}' at depth ${depth->Int.toString} (path: ${path})`
  | FileWriteError({filePath, message}) => `Failed to write file '${filePath}': ${message}`
  | InvalidConfigError({field, message}) => `Invalid configuration for field '${field}': ${message}`
  | UnknownError({message, context}) =>
    switch context {
    | Some(ctx) => `Unknown error at '${ctx.path}' (${ctx.operation}): ${message}`
    | None => `Unknown error: ${message}`
    }
  }

// Create context helper
let makeContext = (~path, ~operation, ~schema=?, ()) => {
  path,
  operation,
  schema,
}
