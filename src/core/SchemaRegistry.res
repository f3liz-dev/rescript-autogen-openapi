// SPDX-License-Identifier: MPL-2.0

// SchemaRegistry.res - Registry for resolving $ref references in OpenAPI specs
// 
// This module provides a way to:
// 1. Store all component schemas from an OpenAPI spec
// 2. Resolve $ref strings to their underlying jsonSchema
// 3. Track which schemas are being visited to detect circular references

open Types

// The registry type
type t = {
  // All schemas from components.schemas
  schemas: Dict.t<jsonSchema>,
  // Track visited schemas during resolution to detect cycles
  mutable visiting: array<string>,
}

// Create a registry from an OpenAPI spec
let fromSpec = (spec: openAPISpec): t => {
  let schemas = switch spec.components {
  | None => Dict.make()
  | Some(components) => {
      switch components.schemas {
      | None => Dict.make()
      | Some(s) => s
      }
    }
  }
  
  {
    schemas,
    visiting: [],
  }
}

// Create an empty registry
let empty = (): t => {
  {
    schemas: Dict.make(),
    visiting: [],
  }
}

// Extract schema name from a $ref string
// e.g., "#/components/schemas/Note" -> Some("Note")
let extractSchemaName = (ref: string): option<string> => {
  let prefix = "#/components/schemas/"
  if String.startsWith(ref, prefix) {
    Some(String.slice(ref, ~start=String.length(prefix)))
  } else {
    None
  }
}

// Check if a schema name is currently being visited (cycle detection)
let isVisiting = (registry: t, name: string): bool => {
  registry.visiting->Array.includes(name)
}

// Start visiting a schema (for cycle detection)
let startVisiting = (registry: t, name: string): unit => {
  registry.visiting = Array.concat(registry.visiting, [name])
}

// Stop visiting a schema
let stopVisiting = (registry: t, name: string): unit => {
  registry.visiting = registry.visiting->Array.filter(n => n != name)
}

// Look up a schema by name
let getSchema = (registry: t, name: string): option<jsonSchema> => {
  Dict.get(registry.schemas, name)
}

// Look up a schema by $ref string
let resolveRef = (registry: t, ref: string): option<jsonSchema> => {
  switch extractSchemaName(ref) {
  | None => None
  | Some(name) => getSchema(registry, name)
  }
}

// Get all schema names
let getSchemaNames = (registry: t): array<string> => {
  Dict.keysToArray(registry.schemas)
}

// Check if a schema exists
let hasSchema = (registry: t, name: string): bool => {
  Dict.get(registry.schemas, name)->Option.isSome
}

// Add a schema to the registry
let addSchema = (registry: t, name: string, schema: jsonSchema): unit => {
  Dict.set(registry.schemas, name, schema)
}

// Merge schemas from another registry
let merge = (registry: t, other: t): unit => {
  Dict.toArray(other.schemas)->Array.forEach(((name, schema)) => {
    if !hasSchema(registry, name) {
      addSchema(registry, name, schema)
    }
  })
}
