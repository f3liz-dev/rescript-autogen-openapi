// SPDX-License-Identifier: MPL-2.0

// IRToSuryGenerator.res - Generate Sury schema code from Schema IR
open Types

let addWarning = GenerationContext.addWarning

// Sury can't set defaults for dict/object types, so we need s.field with S.option instead of s.fieldOr
let cannotSetDefault = (schemaCode: string) =>
  String.includes(schemaCode, "S.dict(") || String.includes(schemaCode, "S.object(")

// Replace S.nullableAsOption(...) with S.option(...) to avoid double-option wrapping
let nullableToOption = (schemaCode: string) =>
  if String.startsWith(schemaCode, "S.nullableAsOption(") {
    "S.option(" ++ String.sliceToEnd(schemaCode, ~start=String.length("S.nullableAsOption("))
  } else {
    `S.option(${schemaCode})`
  }

let applyConstraints = (base, min, max, toString) => {
  let s1 = switch min {
  | Some(v) => `${base}->S.min(${toString(v)})`
  | None => base
  }
  switch max {
  | Some(v) => `${s1}->S.max(${toString(v)})`
  | None => s1
  }
}

// When extractedTypeMap is provided, complex inline types reference extracted schemas instead of regenerating
let rec generateSchemaWithContext = (~ctx: GenerationContext.t, ~depth=0, ~extractedTypeMap: option<array<GenerationContext.extractedType>>=?, irType: SchemaIR.irType): string => {
  // We keep a high depth limit just to prevent infinite recursion on circular schemas that escaped IRBuilder
  if depth > 100 {
    addWarning(ctx, DepthLimitReached({depth, path: ctx.path}))
    "S.json"
  } else {
    let recurse = nextIrType => generateSchemaWithContext(~ctx, ~depth=depth + 1, ~extractedTypeMap?, nextIrType)

    // Check if this irType was extracted — if so, reference the schema by name
    let foundExtracted = switch extractedTypeMap {
    | Some(extracted) =>
      extracted->Array.find(({irType: extractedIr}: GenerationContext.extractedType) =>
        SchemaIR.equals(extractedIr, irType)
      )
    | None => None
    }

    switch foundExtracted {
    | Some({typeName}) => `${typeName}Schema`
    | None =>

    switch irType {
    | String({constraints: c}) =>
      let s = applyConstraints("S.string", c.minLength, c.maxLength, v => Int.toString(v))
      switch c.pattern {
      | Some(p) => `${s}->S.pattern(/${CodegenUtils.escapeRegexPattern(p)}/)`
      | None => s
      }
    | Number({constraints: c}) =>
      applyConstraints("S.float", c.minimum, c.maximum, v => Float.toInt(v)->Int.toString)
    | Integer({constraints: c}) =>
      applyConstraints("S.int", c.minimum, c.maximum, v => Float.toInt(v)->Int.toString)
    | Boolean => "S.bool"
    | Null => "S.null"
    | Array({items, constraints: c}) =>
      applyConstraints(`S.array(${recurse(items)})`, c.minItems, c.maxItems, v => Int.toString(v))
    | Object({properties, additionalProperties}) =>
      if Array.length(properties) == 0 {
        switch additionalProperties {
        | Some(valueType) => `S.dict(${recurse(valueType)})`
        | None => "S.dict(S.json)"
        }
      } else {
        let fields =
          properties
          ->Array.map(((name, fieldType, isRequired)) => {
            let schemaCode = recurse(fieldType)
            let camelName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
            let alreadyNullable = String.startsWith(schemaCode, "S.nullableAsOption(") || switch fieldType {
              | Option(_) => true
              | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
              | _ => false
            }
            if isRequired {
              `    ${camelName}: s.field("${name}", ${schemaCode}),`
            } else if alreadyNullable {
              if cannotSetDefault(schemaCode) {
                `    ${camelName}: s.field("${name}", ${nullableToOption(schemaCode)}),`
              } else {
                `    ${camelName}: s.fieldOr("${name}", ${schemaCode}, None),`
              }
            } else {
              if cannotSetDefault(schemaCode) {
                `    ${camelName}: s.field("${name}", S.option(${schemaCode})),`
              } else {
                `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
              }
            }
          })
          ->Array.join("\n")
        `S.object(s => {\n${fields}\n  })`
      }
    | Literal(value) =>
      switch value {
      | StringLiteral(s) => `S.literal("${CodegenUtils.escapeString(s)}")`
      | NumberLiteral(n) => `S.literal(${Float.toString(n)})`
      | BooleanLiteral(b) => `S.literal(${b ? "true" : "false"})`
      | NullLiteral => "S.literal(null)"
      }
    | Union(types) =>
      // Separate Null from non-null members (handles OpenAPI 3.1 nullable via oneOf)
      let nonNullTypes = types->Array.filter(t =>
        switch t {
        | Null | Literal(NullLiteral) => false
        | _ => true
        }
      )
      let hasNull = Array.length(nonNullTypes) < Array.length(types)

      // If the union is just [T, null], treat as nullable
      if hasNull && Array.length(nonNullTypes) == 1 {
        `S.nullableAsOption(${recurse(nonNullTypes->Array.getUnsafe(0))})`
      } else {
        let effectiveTypes = hasNull ? nonNullTypes : types

        let (hasArray, hasNonArray, arrayItemType, nonArrayType) = effectiveTypes->Array.reduce(
          (false, false, None, None),
          ((hArr, hNonArr, arrItem, nonArr), t) =>
            switch t {
            | Array({items}) => (true, hNonArr, Some(items), nonArr)
            | _ => (hArr, true, arrItem, Some(t))
            },
        )

        let result = if (
          hasArray &&
          hasNonArray &&
          Array.length(effectiveTypes) == 2 &&
          SchemaIR.equals(Option.getOr(arrayItemType, Unknown), Option.getOr(nonArrayType, Unknown))
        ) {
          `S.array(${recurse(Option.getOr(arrayItemType, Unknown))})`
        } else if (
          effectiveTypes->Array.every(t =>
            switch t {
            | Literal(StringLiteral(_)) => true
            | _ => false
            }
          ) &&
          Array.length(effectiveTypes) > 0 &&
          Array.length(effectiveTypes) <= 50
        ) {
          `S.union([${effectiveTypes->Array.map(recurse)->Array.join(", ")}])`
        } else if Array.length(effectiveTypes) > 0 {
          // Check if @unboxed variant is valid (same logic as type generator)
          let canUnbox = {
            let runtimeKinds: Dict.t<int> = Dict.make()
            effectiveTypes->Array.forEach(t => {
              let kind = switch t {
              | Boolean | Literal(BooleanLiteral(_)) => "boolean"
              | String(_) | Literal(StringLiteral(_)) => "string"
              | Number(_) | Integer(_) | Literal(NumberLiteral(_)) => "number"
              | Array(_) => "array"
              | Object(_) | Reference(_) | Intersection(_) => "object"
              | Null | Literal(NullLiteral) => "null"
              | _ => "unknown"
              }
              let count = runtimeKinds->Dict.get(kind)->Option.getOr(0)
              runtimeKinds->Dict.set(kind, count + 1)
            })
            Dict.valuesToArray(runtimeKinds)->Array.every(count => count <= 1)
          }
          
          if canUnbox {
            // @unboxed variant with S.union + S.shape
            let rawNames = effectiveTypes->Array.map(CodegenUtils.variantConstructorName)
            let names = CodegenUtils.deduplicateNames(rawNames)
            
            let branches = effectiveTypes->Array.mapWithIndex((memberType, i) => {
              let constructorName = names->Array.getUnsafe(i)
              switch memberType {
              | Object({properties, additionalProperties}) =>
                if Array.length(properties) == 0 {
                  switch additionalProperties {
                  | Some(valueType) => `S.dict(${recurse(valueType)})->S.shape(v => ${constructorName}(v))`
                  | None => `S.dict(S.json)->S.shape(v => ${constructorName}(v))`
                  }
                } else {
                  let fields = properties->Array.map(((name, fieldType, isRequired)) => {
                    let schemaCode = recurse(fieldType)
                    let camelName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
                    let alreadyNullable = String.startsWith(schemaCode, "S.nullableAsOption(") || switch fieldType {
                      | Option(_) => true
                      | Union(unionTypes) => unionTypes->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
                      | _ => false
                    }
                    if isRequired {
                      `      ${camelName}: s.field("${name}", ${schemaCode}),`
                    } else if alreadyNullable {
                      if cannotSetDefault(schemaCode) {
                        `      ${camelName}: s.field("${name}", ${nullableToOption(schemaCode)}),`
                      } else {
                        `      ${camelName}: s.fieldOr("${name}", ${schemaCode}, None),`
                      }
                    } else {
                      if cannotSetDefault(schemaCode) {
                        `      ${camelName}: s.field("${name}", S.option(${schemaCode})),`
                      } else {
                        `      ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
                      }
                    }
                  })->Array.join("\n")
                  `S.object(s => ${constructorName}({\n${fields}\n    }))`
                }
              | _ =>
                let innerSchema = recurse(memberType)
                `${innerSchema}->S.shape(v => ${constructorName}(v))`
              }
            })
            `S.union([${branches->Array.join(", ")}])`
          } else {
            // Can't use @unboxed: pick last schema (matching type gen)
            recurse(effectiveTypes->Array.getUnsafe(Array.length(effectiveTypes) - 1))
          }
        } else {
          "S.json"
        }

        hasNull ? `S.nullableAsOption(${result})` : result
      }
    | Intersection(types) =>
      if types->Array.every(t =>
        switch t {
        | Reference(_) => true
        | _ => false
        }
      ) && Array.length(types) > 0 {
        recurse(types->Array.get(Array.length(types) - 1)->Option.getOr(Unknown))
      } else {
        // Try to merge all Object types in the intersection
        let (objectProps, nonObjectTypes) = types->Array.reduce(
          ([], []),
          ((props, nonObj), t) =>
            switch t {
            | Object({properties}) => (Array.concat(props, properties), nonObj)
            | _ => (props, Array.concat(nonObj, [t]))
            },
        )
        if Array.length(objectProps) > 0 && Array.length(nonObjectTypes) == 0 {
          // All objects: merge properties into single S.object
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let schemaCode = recurse(fieldType)
              let camelName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
              let alreadyNullable = String.startsWith(schemaCode, "S.nullableAsOption(") || switch fieldType {
                | Option(_) => true
                | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
                | _ => false
              }
              if isRequired {
                `    ${camelName}: s.field("${name}", ${schemaCode}),`
              } else if alreadyNullable {
                if cannotSetDefault(schemaCode) {
                  `    ${camelName}: s.field("${name}", ${nullableToOption(schemaCode)}),`
                } else {
                  `    ${camelName}: s.fieldOr("${name}", ${schemaCode}, None),`
                }
              } else {
                if cannotSetDefault(schemaCode) {
                  `    ${camelName}: s.field("${name}", S.option(${schemaCode})),`
                } else {
                  `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
                }
              }
            })
            ->Array.join("\n")
          `S.object(s => {\n${fields}\n  })`
        } else if Array.length(nonObjectTypes) > 0 && Array.length(objectProps) == 0 {
          recurse(types->Array.get(Array.length(types) - 1)->Option.getOr(Unknown))
        } else {
          addWarning(
            ctx,
            IntersectionNotFullySupported({location: ctx.path, note: "Mixed object/non-object intersection"}),
          )
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let schemaCode = recurse(fieldType)
              let camelName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
              let alreadyNullable = String.startsWith(schemaCode, "S.nullableAsOption(") || switch fieldType {
                | Option(_) => true
                | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
                | _ => false
              }
              if isRequired {
                `    ${camelName}: s.field("${name}", ${schemaCode}),`
              } else if alreadyNullable {
                if cannotSetDefault(schemaCode) {
                  `    ${camelName}: s.field("${name}", ${nullableToOption(schemaCode)}),`
                } else {
                  `    ${camelName}: s.fieldOr("${name}", ${schemaCode}, None),`
                }
              } else {
                if cannotSetDefault(schemaCode) {
                  `    ${camelName}: s.field("${name}", S.option(${schemaCode})),`
                } else {
                  `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
                }
              }
            })
            ->Array.join("\n")
          `S.object(s => {\n${fields}\n  })`
        }
      }
    | Reference(ref) =>
      // After IR normalization, ref may be just the schema name
      let refName = if ref->String.includes("/") {
        ref->String.split("/")->Array.get(ref->String.split("/")->Array.length - 1)->Option.getOr("")
      } else {
        ref
      }
      
      // Detect self-reference using selfRefName from context
      let isSelfRef = switch ctx.selfRefName {
      | Some(selfName) => refName == selfName
      | None => false
      }

      if isSelfRef {
        "schema" // Self-reference: use the recursive schema binding
      } else {
        let schemaPath = switch ctx.availableSchemas {
        | Some(available) =>
          available->Array.includes(refName)
            ? `${CodegenUtils.toPascalCase(refName)}.schema`
            : `ComponentSchemas.${CodegenUtils.toPascalCase(refName)}.schema`
        | None =>
          ReferenceResolver.refToSchemaPath(
            ~insideComponentSchemas=ctx.insideComponentSchemas,
            ~modulePrefix=ctx.modulePrefix,
            ref,
          )->Option.getOr("S.json")
        }
        if schemaPath == "S.json" {
          addWarning(
            ctx,
            FallbackToJson({
              reason: `Unresolved ref: ${ref}`,
              context: {path: ctx.path, operation: "gen ref", schema: None},
            }),
          )
        }
        schemaPath
      }
    | Option(inner) => `S.nullableAsOption(${recurse(inner)})`
    | Unknown => "S.json"
    }
    } // end switch foundExtracted
  }
}

let generateSchema = (
  ~depth=0,
  ~path="",
  ~insideComponentSchemas=false,
  ~availableSchemas=?,
  ~modulePrefix="",
  irType,
) => {
  let ctx = GenerationContext.make(~path, ~insideComponentSchemas, ~availableSchemas?, ~modulePrefix, ())
  (generateSchemaWithContext(~ctx, ~depth, irType), ctx.warnings)
}

let generateNamedSchema = (
  ~namedSchema: SchemaIR.namedSchema,
  ~insideComponentSchemas=false,
  ~availableSchemas=?,
  ~modulePrefix="",
  ~extractedTypes: array<GenerationContext.extractedType>=[],
) => {
  let ctx = GenerationContext.make(
    ~path=`schema.${namedSchema.name}`,
    ~insideComponentSchemas,
    ~availableSchemas?,
    ~modulePrefix,
    (),
  )
  let doc = switch namedSchema.description {
  | Some(d) => CodegenUtils.generateDocComment(~description=d, ())
  | None => ""
  }
  let extractedTypeMap = if Array.length(extractedTypes) > 0 { Some(extractedTypes) } else { None }
  let mainSchema = generateSchemaWithContext(~ctx, ~depth=0, ~extractedTypeMap?, namedSchema.type_)

  // Generate schemas for extracted auxiliary types
  // Exclude the type being generated from the map to avoid self-reference
  let extractedDefs = extractedTypes->Array.map(({typeName, irType}: GenerationContext.extractedType) => {
    let auxCtx = GenerationContext.make(
      ~path=`schema.${typeName}`,
      ~insideComponentSchemas,
      ~availableSchemas?,
      ~modulePrefix,
      (),
    )
    let filteredMap = extractedTypes->Array.filter(({typeName: tn}: GenerationContext.extractedType) => tn != typeName)
    let auxExtractedTypeMap = if Array.length(filteredMap) > 0 { Some(filteredMap) } else { None }
    let auxSchema = generateSchemaWithContext(~ctx=auxCtx, ~depth=0, ~extractedTypeMap=?auxExtractedTypeMap, irType)
    `let ${typeName}Schema = ${auxSchema}`
  })

  let allDefs = Array.concat(extractedDefs, [`${doc}let ${namedSchema.name}Schema = ${mainSchema}`])
  (
    allDefs->Array.join("\n\n"),
    ctx.warnings,
  )
}

let generateAllSchemas = (~context: SchemaIR.schemaContext) => {
  let warnings = []
  let schemas =
    Dict.valuesToArray(context.schemas)
    ->Array.toSorted((a, b) => String.compare(a.name, b.name))
    ->Array.map(s => {
      let (code, w) = generateNamedSchema(~namedSchema=s)
      warnings->Array.pushMany(w)
      code
    })
  (schemas, warnings)
}