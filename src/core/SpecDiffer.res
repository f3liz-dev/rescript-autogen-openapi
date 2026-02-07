// SPDX-License-Identifier: MPL-2.0

// SpecDiffer.res - Compare two OpenAPI specifications
open Types

// Helper to create endpoint keys for comparison
let makeEndpointKey = (method: string, path: string): string => {
  `${method}:${path}`
}

// Compare two schemas for equality (deep comparison)
let rec schemasEqual = (schema1: jsonSchema, schema2: jsonSchema): bool => {
  // Compare type
  let typeMatches = switch (schema1.type_, schema2.type_) {
  | (Some(t1), Some(t2)) => t1 == t2
  | (None, None) => true
  | _ => false
  }
  
  if !typeMatches {
    false
  } else if schema1.format != schema2.format {
    false
  } else if schema1.nullable != schema2.nullable {
    false
  } else if schema1.enum != schema2.enum {
    false
  } else {
    // Compare properties for objects
    switch (schema1.properties, schema2.properties) {
    | (Some(props1), Some(props2)) => {
        let keys1 = Dict.keysToArray(props1)->Array.toSorted(String.compare)
        let keys2 = Dict.keysToArray(props2)->Array.toSorted(String.compare)
        
        if keys1 != keys2 {
          false
        } else {
          keys1->Array.every(key => {
            switch (Dict.get(props1, key), Dict.get(props2, key)) {
            | (Some(s1), Some(s2)) => schemasEqual(s1, s2)
            | _ => false
            }
          })
        }
      }
    | (None, None) => true
    | _ => false
    }
  }
}

// Compare two endpoints
let compareEndpoints = (endpoint1: endpoint, endpoint2: endpoint): option<endpointDiff> => {
  let hasRequestBodyChanged = switch (endpoint1.requestBody, endpoint2.requestBody) {
  | (Some(rb1), Some(rb2)) => {
      // Compare content types
      let keys1 = Dict.keysToArray(rb1.content)->Array.toSorted(String.compare)
      let keys2 = Dict.keysToArray(rb2.content)->Array.toSorted(String.compare)
      
      if keys1 != keys2 {
        true
      } else {
        keys1->Array.some(contentType => {
          switch (Dict.get(rb1.content, contentType), Dict.get(rb2.content, contentType)) {
          | (Some(mt1), Some(mt2)) =>
            switch (mt1.schema, mt2.schema) {
            | (Some(s1), Some(s2)) => !schemasEqual(s1, s2)
            | _ => false
            }
          | _ => false
          }
        })
      }
    }
  | (None, None) => false
  | _ => true
  }

  let hasResponseChanged = {
    let codes1 = Dict.keysToArray(endpoint1.responses)->Array.toSorted(String.compare)
    let codes2 = Dict.keysToArray(endpoint2.responses)->Array.toSorted(String.compare)
    
    if codes1 != codes2 {
      true
    } else {
      codes1->Array.some(code => {
        switch (Dict.get(endpoint1.responses, code), Dict.get(endpoint2.responses, code)) {
        | (Some(r1), Some(r2)) =>
          switch (r1.content, r2.content) {
          | (Some(c1), Some(c2)) => {
              let contentKeys1 = Dict.keysToArray(c1)->Array.toSorted(String.compare)
              let contentKeys2 = Dict.keysToArray(c2)->Array.toSorted(String.compare)
              
              if contentKeys1 != contentKeys2 {
                true
              } else {
                contentKeys1->Array.some(contentType => {
                  switch (Dict.get(c1, contentType), Dict.get(c2, contentType)) {
                  | (Some(mt1), Some(mt2)) =>
                    switch (mt1.schema, mt2.schema) {
                    | (Some(s1), Some(s2)) => !schemasEqual(s1, s2)
                    | _ => false
                    }
                  | _ => false
                  }
                })
              }
            }
          | (None, None) => false
          | _ => true
          }
        | _ => false
        }
      })
    }
  }

  if hasRequestBodyChanged || hasResponseChanged {
    Some({
      path: endpoint1.path,
      method: endpoint1.method,
      requestBodyChanged: hasRequestBodyChanged,
      responseChanged: hasResponseChanged,
      breakingChange: hasResponseChanged, // Response changes are breaking
    })
  } else {
    None
  }
}

// Compare endpoints between two specs
let compareEndpointLists = (
  baseEndpoints: array<endpoint>,
  forkEndpoints: array<endpoint>,
): (array<endpoint>, array<endpoint>, array<endpointDiff>) => {
  // Create maps for efficient lookup
  let baseMap = Dict.make()
  baseEndpoints->Array.forEach(ep => {
    let key = makeEndpointKey(ep.method, ep.path)
    Dict.set(baseMap, key, ep)
  })

  let forkMap = Dict.make()
  forkEndpoints->Array.forEach(ep => {
    let key = makeEndpointKey(ep.method, ep.path)
    Dict.set(forkMap, key, ep)
  })

  let baseKeys = Dict.keysToArray(baseMap)->Set.fromArray
  let forkKeys = Dict.keysToArray(forkMap)->Set.fromArray

  // Find added endpoints (in fork but not in base)
  let added = forkKeys
    ->Set.difference(baseKeys)
    ->Set.toArray
    ->Array.filterMap(key => Dict.get(forkMap, key))

  // Find removed endpoints (in base but not in fork)
  let removed = baseKeys
    ->Set.difference(forkKeys)
    ->Set.toArray
    ->Array.filterMap(key => Dict.get(baseMap, key))

  // Find modified endpoints (in both but different)
  let modified = baseKeys
    ->Set.intersection(forkKeys)
    ->Set.toArray
    ->Array.filterMap(key => {
      switch (Dict.get(baseMap, key), Dict.get(forkMap, key)) {
      | (Some(baseEp), Some(forkEp)) => compareEndpoints(baseEp, forkEp)
      | _ => None
      }
    })

  (added, removed, modified)
}

// Compare component schemas between two specs
let compareComponentSchemas = (
  baseSchemas: option<dict<jsonSchema>>,
  forkSchemas: option<dict<jsonSchema>>,
): (array<string>, array<string>, array<schemaDiff>) => {
  switch (baseSchemas, forkSchemas) {
  | (None, None) => ([], [], [])
  | (None, Some(fork)) => (Dict.keysToArray(fork), [], [])
  | (Some(base), None) => ([], Dict.keysToArray(base), [])
  | (Some(base), Some(fork)) => {
      let baseKeys = Dict.keysToArray(base)->Set.fromArray
      let forkKeys = Dict.keysToArray(fork)->Set.fromArray

      // Added schemas
      let added = forkKeys
        ->Set.difference(baseKeys)
        ->Set.toArray

      // Removed schemas
      let removed = baseKeys
        ->Set.difference(forkKeys)
        ->Set.toArray

      // Modified schemas
      let modified = baseKeys
        ->Set.intersection(forkKeys)
        ->Set.toArray
        ->Array.filterMap(name => {
          switch (Dict.get(base, name), Dict.get(fork, name)) {
          | (Some(baseSchema), Some(forkSchema)) =>
            if !schemasEqual(baseSchema, forkSchema) {
              Some({
                name: name,
                breakingChange: true, // Schema changes are generally breaking
              })
            } else {
              None
            }
          | _ => None
          }
        })

      (added, removed, modified)
    }
  }
}

// Generate a complete diff between two specs
let generateDiff = (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
  ~baseEndpoints: array<endpoint>,
  ~forkEndpoints: array<endpoint>,
): specDiff => {
  let (addedEndpoints, removedEndpoints, modifiedEndpoints) = 
    compareEndpointLists(baseEndpoints, forkEndpoints)

  let (addedSchemas, removedSchemas, modifiedSchemas) = 
    compareComponentSchemas(
      baseSpec.components->Option.flatMap(c => c.schemas),
      forkSpec.components->Option.flatMap(c => c.schemas)
    )

  {
    addedEndpoints: addedEndpoints,
    removedEndpoints: removedEndpoints,
    modifiedEndpoints: modifiedEndpoints,
    addedSchemas: addedSchemas,
    removedSchemas: removedSchemas,
    modifiedSchemas: modifiedSchemas,
  }
}

// Detect if there are any breaking changes
let hasBreakingChanges = (diff: specDiff): bool => {
  let hasRemovedEndpoints = Array.length(diff.removedEndpoints) > 0
  let hasBreakingEndpointChanges = diff.modifiedEndpoints
    ->Array.some(d => d.breakingChange)
  let hasBreakingSchemaChanges = diff.modifiedSchemas
    ->Array.some(d => d.breakingChange)

  hasRemovedEndpoints || hasBreakingEndpointChanges || hasBreakingSchemaChanges
}

// Count total changes
let countChanges = (diff: specDiff): int => {
  Array.length(diff.addedEndpoints) +
  Array.length(diff.removedEndpoints) +
  Array.length(diff.modifiedEndpoints) +
  Array.length(diff.addedSchemas) +
  Array.length(diff.removedSchemas) +
  Array.length(diff.modifiedSchemas)
}
