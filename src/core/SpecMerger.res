// SPDX-License-Identifier: MPL-2.0

// SpecMerger.res - Merge base and fork OpenAPI specifications
open Types

// Helper to create endpoint key
let makeEndpointKey = (endpoint: endpoint): string => {
  `${endpoint.method}:${endpoint.path}`
}

// Extract shared endpoints (present in both specs with same signature)
// For SharedBase strategy, this returns ALL base endpoints
let extractSharedEndpoints = (
  baseEndpoints: array<endpoint>,
  _forkEndpoints: array<endpoint>,
): array<endpoint> => {
  // Return ALL base endpoints - the base should be complete
  baseEndpoints
}

// Extract fork-specific endpoints (new AND modified endpoints)
let extractForkExtensions = (
  baseEndpoints: array<endpoint>,
  forkEndpoints: array<endpoint>,
): array<endpoint> => {
  // Create base map for lookup
  let baseMap = Dict.make()
  baseEndpoints->Array.forEach(ep => {
    let key = makeEndpointKey(ep)
    Dict.set(baseMap, key, ep)
  })

  // Find endpoints in fork that are new OR modified
  forkEndpoints->Array.filter(forkEp => {
    let key = makeEndpointKey(forkEp)
    switch Dict.get(baseMap, key) {
    | None => true // New endpoint - include it
    | Some(baseEp) => {
        // Check if endpoint is modified
        switch SpecDiffer.compareEndpoints(baseEp, forkEp) {
        | Some(_diff) => true // Modified - include it
        | None => false // Identical - exclude it
        }
      }
    }
  })
}

// Extract shared component schemas (ALL base schemas for SharedBase strategy)
let extractSharedSchemas = (
  baseSchemas: option<dict<jsonSchema>>,
  _forkSchemas: option<dict<jsonSchema>>,
): option<dict<jsonSchema>> => {
  // Return ALL base schemas - the base should be complete
  baseSchemas
}

// Extract fork-specific component schemas
let extractForkSchemas = (
  baseSchemas: option<dict<jsonSchema>>,
  forkSchemas: option<dict<jsonSchema>>,
): option<dict<jsonSchema>> => {
  switch (baseSchemas, forkSchemas) {
  | (_, None) => None
  | (None, Some(fork)) => Some(fork) // All fork schemas are extensions
  | (Some(base), Some(fork)) => {
      let extensions = Dict.make()
      
      Dict.keysToArray(fork)->Array.forEach(name => {
        switch (Dict.get(base, name), Dict.get(fork, name)) {
        | (None, Some(forkSchema)) => {
            // New schema in fork
            Dict.set(extensions, name, forkSchema)
          }
        | (Some(baseSchema), Some(forkSchema)) => {
            // Check if modified
            if !SpecDiffer.schemasEqual(baseSchema, forkSchema) {
              Dict.set(extensions, name, forkSchema)
            }
          }
        | _ => ()
        }
      })
      
      if Dict.keysToArray(extensions)->Array.length > 0 {
        Some(extensions)
      } else {
        None
      }
    }
  }
}

// Create a new spec with given endpoints
let createSpecWithEndpoints = (
  ~baseSpec: openAPISpec,
  ~endpoints: array<endpoint>,
  ~schemas: option<dict<jsonSchema>>,
): openAPISpec => {
  // Group endpoints by path
  let pathsDict = Dict.make()
  
  endpoints->Array.forEach(ep => {
    let pathItem = switch Dict.get(pathsDict, ep.path) {
    | Some(existing) => existing
    | None => {
        get: None,
        post: None,
        put: None,
        delete: None,
        patch: None,
        head: None,
        options: None,
        parameters: None,
      }
    }
    
    let operation: operation = {
      operationId: ep.operationId,
      summary: ep.summary,
      description: ep.description,
      tags: ep.tags,
      parameters: ep.parameters,
      requestBody: ep.requestBody,
      responses: ep.responses,
    }
    
    let updatedPathItem = switch String.toLowerCase(ep.method) {
    | "get" => {...pathItem, get: Some(operation)}
    | "post" => {...pathItem, post: Some(operation)}
    | "put" => {...pathItem, put: Some(operation)}
    | "delete" => {...pathItem, delete: Some(operation)}
    | "patch" => {...pathItem, patch: Some(operation)}
    | _ => pathItem
    }
    
    Dict.set(pathsDict, ep.path, updatedPathItem)
  })
  
  // Update components with schemas
  let components = switch (baseSpec.components, schemas) {
  | (Some(_comp), Some(sch)) => Some({schemas: Some(sch)})
  | (Some(_comp), None) => Some({schemas: None})
  | (None, Some(sch)) => Some({
      schemas: Some(sch),
    })
  | (None, None) => None
  }
  
  {
    ...baseSpec,
    paths: pathsDict,
    components: components,
  }
}

// Merge two specs using SharedBase strategy
let mergeWithSharedBase = (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
  ~baseEndpoints: array<endpoint>,
  ~forkEndpoints: array<endpoint>,
): (openAPISpec, openAPISpec) => {
  // Extract shared and fork-specific endpoints
  let sharedEndpoints = extractSharedEndpoints(baseEndpoints, forkEndpoints)
  let forkExtensions = extractForkExtensions(baseEndpoints, forkEndpoints)
  
  // Extract shared and fork-specific schemas
  let baseSchemas = baseSpec.components->Option.flatMap(c => c.schemas)
  let forkSchemas = forkSpec.components->Option.flatMap(c => c.schemas)
  
  let sharedSchemas = extractSharedSchemas(baseSchemas, forkSchemas)
  let extensionSchemas = extractForkSchemas(baseSchemas, forkSchemas)
  
  // Create shared spec
  let sharedSpec = createSpecWithEndpoints(
    ~baseSpec=baseSpec,
    ~endpoints=sharedEndpoints,
    ~schemas=sharedSchemas,
  )
  
  // Create fork extensions spec
  let extensionsSpec = createSpecWithEndpoints(
    ~baseSpec=forkSpec,
    ~endpoints=forkExtensions,
    ~schemas=extensionSchemas,
  )
  
  (sharedSpec, extensionsSpec)
}

// Merge two specs using Separate strategy (keep both complete)
let mergeWithSeparate = (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
): (openAPISpec, openAPISpec) => {
  // No merging, just return both specs as-is
  (baseSpec, forkSpec)
}

// Merge specs according to strategy
let mergeSpecs = (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
  ~baseEndpoints: array<endpoint>,
  ~forkEndpoints: array<endpoint>,
  ~strategy: generationStrategy,
): (openAPISpec, openAPISpec) => {
  switch strategy {
  | Separate => mergeWithSeparate(~baseSpec, ~forkSpec)
  | SharedBase =>
      mergeWithSharedBase(~baseSpec, ~forkSpec, ~baseEndpoints, ~forkEndpoints)
  }
}

// Calculate merge statistics
type mergeStats = {
  sharedEndpointCount: int,
  forkExtensionCount: int,
  sharedSchemaCount: int,
  forkSchemaCount: int,
}

let getMergeStats = (
  ~baseEndpoints: array<endpoint>,
  ~forkEndpoints: array<endpoint>,
  ~baseSchemas: option<dict<jsonSchema>>,
  ~forkSchemas: option<dict<jsonSchema>>,
): mergeStats => {
  let shared = extractSharedEndpoints(baseEndpoints, forkEndpoints)
  let extensions = extractForkExtensions(baseEndpoints, forkEndpoints)
  let sharedSchemas = extractSharedSchemas(baseSchemas, forkSchemas)
  let extensionSchemas = extractForkSchemas(baseSchemas, forkSchemas)
  
  {
    sharedEndpointCount: Array.length(shared),
    forkExtensionCount: Array.length(extensions),
    sharedSchemaCount: sharedSchemas->Option.mapOr(0, s => 
      Dict.keysToArray(s)->Array.length
    ),
    forkSchemaCount: extensionSchemas->Option.mapOr(0, s => 
      Dict.keysToArray(s)->Array.length
    ),
  }
}
