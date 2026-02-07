// SPDX-License-Identifier: MPL-2.0

// SchemaIRParser.res - Parse JSON Schema to Unified IR

// Helper to convert raw JSON type string to our variant
// This is needed because Obj.magic from JSON gives us raw strings like "string", "object", etc.
// but our variant constructors compile to "String", "Object", etc. in JS
let parseTypeString = (rawType: Types.jsonSchemaType): Types.jsonSchemaType => {
  // The rawType might actually be a raw string from JSON, so we need to handle that
  // We use Obj.magic to get the underlying JS value and check it
  let rawStr: string = Obj.magic(rawType)
  switch rawStr {
  | "string" => Types.String
  | "number" => Types.Number
  | "integer" => Types.Integer
  | "boolean" => Types.Boolean
  | "object" => Types.Object
  | "null" => Types.Null
  | "array" => Types.Array(Types.Unknown)
  | _ => {
      // It might already be a proper variant (like when recursively constructed)
      // In that case, rawStr would be "String", "Number", etc.
      switch rawStr {
      | "String" => Types.String
      | "Number" => Types.Number
      | "Integer" => Types.Integer
      | "Boolean" => Types.Boolean
      | "Object" => Types.Object
      | "Null" => Types.Null
      | "Unknown" => Types.Unknown
      | _ => Types.Unknown
      }
    }
  }
}

// Parsing context to collect warnings
type parsingContext = {
  mutable warnings: array<Types.warning>,
  path: string,
}

let addWarning = (ctx: parsingContext, warning: Types.warning): unit => {
  ctx.warnings->Array.push(warning)
}

// Convert JSON Schema to IR with depth limit to prevent infinite recursion
let rec parseJsonSchemaWithContext = (
  ~ctx: parsingContext,
  ~depth=0,
  schema: Types.jsonSchema,
): SchemaIR.irType => {
  // Safety: Prevent infinite recursion on circular schemas
  if depth > 30 {
    addWarning(
      ctx,
      DepthLimitReached({
        depth: depth,
        path: ctx.path,
      }),
    )
    SchemaIR.Unknown
  } else {
  // Handle $ref first
  switch schema.ref {
  | Some(ref) => SchemaIR.Reference(ref)
  | None => {
      // Check if nullable
      let isNullable = schema.nullable->Option.getOr(false)
      
      // Normalize the type field (raw JSON strings like "string" -> variant String)
      let normalizedType = schema.type_->Option.map(parseTypeString)
      
      // Parse base type
      let baseType = switch normalizedType {
      | Some(Types.String) => {
          let constraints: SchemaIR.stringConstraints = {
            minLength: schema.minLength,
            maxLength: schema.maxLength,
            pattern: schema.pattern,
          }
          SchemaIR.String({constraints: constraints})
        }
      | Some(Types.Number) => {
          let constraints: SchemaIR.numberConstraints = {
            minimum: schema.minimum,
            maximum: schema.maximum,
            multipleOf: None, // Not in jsonSchema type
          }
          SchemaIR.Number({constraints: constraints})
        }
      | Some(Types.Integer) => {
          let constraints: SchemaIR.numberConstraints = {
            minimum: schema.minimum,
            maximum: schema.maximum,
            multipleOf: None, // Not in jsonSchema type
          }
          SchemaIR.Integer({constraints: constraints})
        }
      | Some(Types.Boolean) => SchemaIR.Boolean
      | Some(Types.Null) => SchemaIR.Null
       | Some(Types.Array(_)) => {
          let items = switch schema.items {
          | None => SchemaIR.Unknown
          | Some(itemSchema) => 
              parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, itemSchema)
          }
          
          let constraints: SchemaIR.arrayConstraints = {
            minItems: None, // Not in current jsonSchema type
            maxItems: None, // Not in current jsonSchema type
            uniqueItems: false,
          }
          
          SchemaIR.Array({items, constraints})
        }
      | Some(Types.Object) => {
          // Check if this is an allOf composition (common in OpenAPI)
          switch schema.allOf {
          | Some(schemas) => {
              // allOf with type: "object" - parse as intersection
              let types = schemas->Array.map(s => parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, s))
              SchemaIR.Intersection(types)
            }
          | None => {
              // Regular object type - parse properties
              let properties = switch schema.properties {
              | None => []
               | Some(propsDict) => {
                  let required = schema.required->Option.getOr([])
                  Dict.toArray(propsDict)->Array.map(((name, propSchema)) => {
                    let isRequired = required->Array.includes(name)
                    let propType = parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, propSchema)
                    (name, propType, isRequired)
                  })
                }
              }
              
              // additionalProperties not in current jsonSchema type
              let additionalProperties = None
              
              SchemaIR.Object({
                properties,
                additionalProperties,
              })
            }
          }
        }
      | Some(Types.Unknown) => SchemaIR.Unknown
      | None => {
          // No type specified, check for enum, properties, or combinators
          switch (schema.enum, schema.properties, schema.allOf, schema.oneOf, schema.anyOf) {
          | (Some(enumValues), _, _, _, _) => {
              // Enum - convert to union of literals
              let literals = enumValues->Array.map(value => {
                switch value {
                | String(str) => SchemaIR.Literal(SchemaIR.StringLiteral(str))
                | Number(num) => SchemaIR.Literal(SchemaIR.NumberLiteral(num))
                | Boolean(b) => SchemaIR.Literal(SchemaIR.BooleanLiteral(b))
                | Null => SchemaIR.Literal(SchemaIR.NullLiteral)
                | _ => SchemaIR.Unknown
                }
              })
              SchemaIR.Union(literals)
            }
           | (_, Some(_), _, _, _) => {
              // Has properties, treat as object
              parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, {...schema, type_: Some(Object)})
            }
          | (_, _, Some(schemas), _, _) => {
              // allOf - intersection
              let types = schemas->Array.map(s => parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, s))
              SchemaIR.Intersection(types)
            }
          | (_, _, _, Some(schemas), _) => {
              // oneOf - union
              let types = schemas->Array.map(s => parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, s))
              SchemaIR.Union(types)
            }
          | (_, _, _, _, Some(schemas)) => {
              // anyOf - union
              let types = schemas->Array.map(s => parseJsonSchemaWithContext(~ctx, ~depth=depth + 1, s))
              SchemaIR.Union(types)
            }
          | _ => SchemaIR.Unknown
          }
        }
      }
      
      // Wrap in Option if nullable
      if isNullable {
        SchemaIR.Option(baseType)
      } else {
        baseType
      }
    }
  }
  }
}

// Convenience wrapper that creates a context and returns warnings
let parseJsonSchema = (~depth=0, schema: Types.jsonSchema): (SchemaIR.irType, array<Types.warning>) => {
  let ctx = {warnings: [], path: "root"}
  let irType = parseJsonSchemaWithContext(~ctx, ~depth, schema)
  (irType, ctx.warnings)
}

// Parse a named schema
let parseNamedSchema = (~name: string, ~schema: Types.jsonSchema): (SchemaIR.namedSchema, array<Types.warning>) => {
  let ctx = {warnings: [], path: `components.schemas.${name}`}
  let type_ = parseJsonSchemaWithContext(~ctx, schema)
  ({
    name,
    description: schema.description,
    type_,
  }, ctx.warnings)
}

// Parse all component schemas
let parseComponentSchemas = (schemas: dict<Types.jsonSchema>): (SchemaIR.schemaContext, array<Types.warning>) => {
  let namedSchemas = Dict.make()
  let allWarnings = []
  
  schemas->Dict.toArray->Array.forEach(((name, schema)) => {
    let (namedSchema, warnings) = parseNamedSchema(~name, ~schema)
    Dict.set(namedSchemas, name, namedSchema)
    allWarnings->Array.pushMany(warnings)
  })
  
  ({schemas: namedSchemas}, allWarnings)
}

// Resolve a reference in the context
let resolveReference = (
  ~context: SchemaIR.schemaContext,
  ~ref: string,
): option<SchemaIR.namedSchema> => {
  // Handle #/components/schemas/SchemaName format
  let parts = ref->String.split("/")
  switch parts->Array.get(parts->Array.length - 1) {
  | None => None
  | Some(schemaName) => Dict.get(context.schemas, schemaName)
  }
}

// Inline simple references to reduce indirection
let rec inlineSimpleReferences = (
  ~context: SchemaIR.schemaContext,
  ~irType: SchemaIR.irType,
  ~depth: int=0,
  ~maxDepth: int=2,
): SchemaIR.irType => {
  if depth >= maxDepth {
    irType
  } else {
    switch irType {
    | SchemaIR.Reference(ref) => {
        switch resolveReference(~context, ~ref) {
        | None => irType
        | Some(schema) => {
            // Only inline if it's a simple type
            if SchemaIR.isSimpleType(schema.type_) {
              inlineSimpleReferences(~context, ~irType=schema.type_, ~depth=depth + 1, ~maxDepth)
            } else {
              irType
            }
          }
        }
      }
    | SchemaIR.Option(inner) => 
        SchemaIR.Option(inlineSimpleReferences(~context, ~irType=inner, ~depth, ~maxDepth))
    | SchemaIR.Array({items, constraints}) =>
        SchemaIR.Array({
          items: inlineSimpleReferences(~context, ~irType=items, ~depth, ~maxDepth),
          constraints,
        })
    | SchemaIR.Object({properties, additionalProperties}) => {
        let newProperties = properties->Array.map(((name, type_, required)) => {
          (name, inlineSimpleReferences(~context, ~irType=type_, ~depth, ~maxDepth), required)
        })
        let newAdditionalProps = additionalProperties->Option.map(type_ =>
          inlineSimpleReferences(~context, ~irType=type_, ~depth, ~maxDepth)
        )
        SchemaIR.Object({
          properties: newProperties,
          additionalProperties: newAdditionalProps,
        })
      }
    | SchemaIR.Union(types) =>
        SchemaIR.Union(types->Array.map(type_ =>
          inlineSimpleReferences(~context, ~irType=type_, ~depth, ~maxDepth)
        ))
    | SchemaIR.Intersection(types) =>
        SchemaIR.Intersection(types->Array.map(type_ =>
          inlineSimpleReferences(~context, ~irType=type_, ~depth, ~maxDepth)
        ))
    | other => other
    }
  }
}

// Optimize IR by simplifying unions, intersections, etc.
let rec optimizeIR = (irType: SchemaIR.irType): SchemaIR.irType => {
  switch irType {
  | SchemaIR.Union(types) => {
      // Flatten nested unions
      let flattened = types->Array.flatMap(t => {
        switch optimizeIR(t) {
        | SchemaIR.Union(inner) => inner
        | other => [other]
        }
      })
      
      // Remove duplicates (simple dedup by toString)
      let unique = []
      flattened->Array.forEach(type_ => {
        let typeStr = SchemaIR.toString(type_)
        let exists = unique->Array.some(t => SchemaIR.toString(t) == typeStr)
        if !exists { unique->Array.push(type_) }
      })
      
      // Simplify single-element unions
      switch unique {
      | [] => SchemaIR.Unknown
      | [single] => single
      | multiple => SchemaIR.Union(multiple)
      }
    }
  | SchemaIR.Intersection(types) => {
      // Flatten nested intersections
      let flattened = types->Array.flatMap(t => {
        switch optimizeIR(t) {
        | SchemaIR.Intersection(inner) => inner
        | other => [other]
        }
      })
      
      // Simplify single-element intersections
      switch flattened {
      | [] => SchemaIR.Unknown
      | [single] => single
      | multiple => SchemaIR.Intersection(multiple)
      }
    }
  | SchemaIR.Option(inner) => SchemaIR.Option(optimizeIR(inner))
  | SchemaIR.Array({items, constraints}) => 
      SchemaIR.Array({items: optimizeIR(items), constraints})
  | SchemaIR.Object({properties, additionalProperties}) => {
      let newProperties = properties->Array.map(((name, type_, required)) => {
        (name, optimizeIR(type_), required)
      })
      let newAdditionalProps = additionalProperties->Option.map(optimizeIR)
      SchemaIR.Object({
        properties: newProperties,
        additionalProperties: newAdditionalProps,
      })
    }
  | other => other
  }
}
