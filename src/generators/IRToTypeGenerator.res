// SPDX-License-Identifier: MPL-2.0

// IRToTypeGenerator.res - Generate ReScript types from Schema IR
open Types

let addWarning = GenerationContext.addWarning

// `inline` tracks whether the type appears inside a type constructor (array<_>, option<_>, etc.)
// where ReScript forbids inline record declarations and variant definitions.
// When a complex type is encountered inline, it's extracted as a separate named type.
let rec generateTypeWithContext = (~ctx: GenerationContext.t, ~depth=0, ~inline=false, irType: SchemaIR.irType): string => {
  // We keep a high depth limit just to prevent infinite recursion on circular schemas that escaped IRBuilder
  if depth > 100 {
    addWarning(ctx, DepthLimitReached({depth, path: ctx.path}))
    "JSON.t"
  } else {
    // Inside type constructors, records/variants can't appear; recurse as inline
    let recurseInline = nextIrType => generateTypeWithContext(~ctx, ~depth=depth + 1, ~inline=true, nextIrType)

    switch irType {
    | String(_) => "string"
    | Number(_) => "float"
    | Integer(_) => "int"
    | Boolean => "bool"
    | Null => "unit"
    | Array({items}) => `array<${recurseInline(items)}>`
    | Object({properties, additionalProperties}) =>
      if Array.length(properties) == 0 {
        switch additionalProperties {
        | Some(valueType) => `dict<${recurseInline(valueType)}>`
        | None => "dict<JSON.t>"
        }
      } else if inline {
        // Extract inline record as a separate named type
        let baseName = ctx.path->String.split(".")->Array.get(ctx.path->String.split(".")->Array.length - 1)->Option.getOr("item")
        let typeName = GenerationContext.extractType(ctx, ~baseName, irType)
        typeName
      } else {
        let fields =
          properties
          ->Array.map(((name, fieldType, isRequired)) => {
            let typeCode = recurseInline(fieldType)
            // Avoid double-option: check both generated string and IR type for nullability
            let alreadyNullable = String.startsWith(typeCode, "option<") || switch fieldType {
              | Option(_) => true
              | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
              | _ => false
            }
            let finalType = isRequired || alreadyNullable ? typeCode : `option<${typeCode}>`
            let camelName = name->CodegenUtils.toCamelCase
            let escapedName = camelName->CodegenUtils.escapeKeyword
            let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
            `  ${aliasAnnotation}${escapedName}: ${finalType},`
          })
          ->Array.join("\n")
        `{\n${fields}\n}`
      }
    | Literal(value) =>
      switch value {
      | StringLiteral(_) => "string"
      | NumberLiteral(_) => "float"
      | BooleanLiteral(_) => "bool"
      | NullLiteral => "unit"
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

      // If the union is just [T, null], treat as option<T>
      if hasNull && Array.length(nonNullTypes) == 1 {
        let inner = generateTypeWithContext(~ctx, ~depth=depth + 1, ~inline=true, nonNullTypes->Array.getUnsafe(0))
        `option<${inner}>`
      } else {
        // Work with the non-null types (re-wrap in option at the end if hasNull)
        let effectiveTypes = hasNull ? nonNullTypes : types

        // Attempt to simplify common union patterns
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
          `array<${recurseInline(Option.getOr(arrayItemType, Unknown))}>`
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
          // Polymorphic variants: valid inline
          let variants =
            effectiveTypes
            ->Array.map(t =>
              switch t {
              | Literal(StringLiteral(s)) => `#${CodegenUtils.toPascalCase(s)}`
              | _ => "#Unknown"
              }
            )
            ->Array.join(" | ")
          `[${variants}]`
        } else if Array.length(effectiveTypes) > 0 {
          // Check if @unboxed variant is valid: each member must have a distinct runtime representation
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
            // Valid if no kind appears more than once
            Dict.valuesToArray(runtimeKinds)->Array.every(count => count <= 1)
          }
          
          if canUnbox {
            // Safe to use @unboxed variant
            let extractIR = if hasNull {
              SchemaIR.Union(effectiveTypes)
            } else {
              irType
            }
            let baseName = ctx.path->String.split(".")->Array.get(ctx.path->String.split(".")->Array.length - 1)->Option.getOr("union")
            let typeName = GenerationContext.extractType(ctx, ~baseName, ~isUnboxed=true, extractIR)
            typeName
          } else {
            // Can't use @unboxed: pick the last (most derived/specific) type
            recurseInline(effectiveTypes->Array.getUnsafe(Array.length(effectiveTypes) - 1))
          }
        } else {
          "JSON.t"
        }

        hasNull ? `option<${result}>` : result
      }
    | Intersection(types) =>
      // Support for intersections: merge object properties or pick last reference
      if types->Array.every(t =>
        switch t {
        | Reference(_) => true
        | _ => false
        }
      ) && Array.length(types) > 0 {
        generateTypeWithContext(~ctx, ~depth=depth + 1, ~inline, types->Array.get(Array.length(types) - 1)->Option.getOr(Unknown))
      } else if inline {
        // Extract complex intersection as a separate type
        let baseName = ctx.path->String.split(".")->Array.get(ctx.path->String.split(".")->Array.length - 1)->Option.getOr("intersection")
        let typeName = GenerationContext.extractType(ctx, ~baseName, irType)
        typeName
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
          // All objects: merge properties
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let typeCode = recurseInline(fieldType)
              let alreadyNullable = String.startsWith(typeCode, "option<") || switch fieldType {
                | Option(_) => true
                | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
                | _ => false
              }
              let finalType = isRequired || alreadyNullable ? typeCode : `option<${typeCode}>`
              let camelName = name->CodegenUtils.toCamelCase
              let escapedName = camelName->CodegenUtils.escapeKeyword
              let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
              `  ${aliasAnnotation}${escapedName}: ${finalType},`
            })
            ->Array.join("\n")
          `{\n${fields}\n}`
        } else if Array.length(nonObjectTypes) > 0 && Array.length(objectProps) == 0 {
          // No objects: pick last type as best effort
          generateTypeWithContext(~ctx, ~depth=depth + 1, ~inline, types->Array.get(Array.length(types) - 1)->Option.getOr(Unknown))
        } else {
          addWarning(
            ctx,
            IntersectionNotFullySupported({location: ctx.path, note: "Mixed object/non-object intersection"}),
          )
          // Merge what we can, ignore non-object parts
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let typeCode = recurseInline(fieldType)
              let alreadyNullable = String.startsWith(typeCode, "option<") || switch fieldType {
                | Option(_) => true
                | Union(types) => types->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
                | _ => false
              }
              let finalType = isRequired || alreadyNullable ? typeCode : `option<${typeCode}>`
              let camelName = name->CodegenUtils.toCamelCase
              let escapedName = camelName->CodegenUtils.escapeKeyword
              let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
              `  ${aliasAnnotation}${escapedName}: ${finalType},`
            })
            ->Array.join("\n")
          `{\n${fields}\n}`
        }
      }
    | Option(inner) => `option<${recurseInline(inner)}>`
    | Reference(ref) =>
      // After IR normalization, ref may be just the schema name (no path prefix)
      // Extract the name from the ref (handles both "Name" and "#/components/schemas/Name")
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
        "t" // Use recursive self-reference
      } else {
        let typePath = switch ctx.availableSchemas {
        | Some(available) =>
          available->Array.includes(refName)
            ? `${CodegenUtils.toPascalCase(refName)}.t`
            : `ComponentSchemas.${CodegenUtils.toPascalCase(refName)}.t`
        | None =>
          ReferenceResolver.refToTypePath(
            ~insideComponentSchemas=ctx.insideComponentSchemas,
            ~modulePrefix=ctx.modulePrefix,
            ref,
          )->Option.getOr("JSON.t")
        }
        if typePath == "JSON.t" {
          addWarning(
            ctx,
            FallbackToJson({
              reason: `Unresolved ref: ${ref}`,
              context: {path: ctx.path, operation: "gen ref", schema: None},
            }),
          )
        }
        typePath
      }
    | Unknown => "JSON.t"
    }
  }
}

// Generate @unboxed variant body from a Union IR type.
// Each member must have a distinct runtime representation (validated by canUnbox check).
let generateUnboxedVariantBody = (~ctx: GenerationContext.t, types: array<SchemaIR.irType>): string => {
  let rawNames = types->Array.map(CodegenUtils.variantConstructorName)
  let names = CodegenUtils.deduplicateNames(rawNames)
  
  types->Array.mapWithIndex((irType, i) => {
    let constructorName = names->Array.getUnsafe(i)
    let payloadType = switch irType {
    | Object({properties, additionalProperties}) =>
      if Array.length(properties) == 0 {
        switch additionalProperties {
        | Some(valueType) => {
            let innerType = generateTypeWithContext(~ctx, ~depth=1, ~inline=true, valueType)
            `(dict<${innerType}>)`
          }
        | None => `(dict<JSON.t>)`
        }
      } else {
        let fields = properties->Array.map(((name, fieldType, isRequired)) => {
          let typeCode = generateTypeWithContext(~ctx, ~depth=1, ~inline=true, fieldType)
          let alreadyNullable = String.startsWith(typeCode, "option<") || switch fieldType {
            | Option(_) => true
            | Union(unionTypes) => unionTypes->Array.some(t => switch t { | Null | Literal(NullLiteral) => true | _ => false })
            | _ => false
          }
          let finalType = isRequired || alreadyNullable ? typeCode : `option<${typeCode}>`
          let camelName = name->CodegenUtils.toCamelCase
          let escapedName = camelName->CodegenUtils.escapeKeyword
          let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
          `${aliasAnnotation}${escapedName}: ${finalType}`
        })->Array.join(", ")
        `({${fields}})`
      }
    | _ =>
      let innerType = generateTypeWithContext(~ctx, ~depth=1, ~inline=true, irType)
      `(${innerType})`
    }
    `${constructorName}${payloadType}`
  })->Array.join(" | ")
}

let generateType = (
  ~depth=0,
  ~path="",
  ~insideComponentSchemas=false,
  ~availableSchemas=?,
  ~modulePrefix="",
  irType,
) => {
  let ctx = GenerationContext.make(~path, ~insideComponentSchemas, ~availableSchemas?, ~modulePrefix, ())
  (generateTypeWithContext(~ctx, ~depth, irType), ctx.warnings)
}

let generateNamedType = (
  ~namedSchema: SchemaIR.namedSchema,
  ~insideComponentSchemas=false,
  ~availableSchemas=?,
  ~modulePrefix="",
) => {
  let ctx = GenerationContext.make(
    ~path=`type.${namedSchema.name}`,
    ~insideComponentSchemas,
    ~availableSchemas?,
    ~modulePrefix,
    (),
  )
  let doc = switch namedSchema.description {
  | Some(d) => CodegenUtils.generateDocString(~description=d, ())
  | None => ""
  }
  let mainType = generateTypeWithContext(~ctx, ~depth=0, namedSchema.type_)

  // Iteratively resolve extracted types (handles nested extraction).
  // Use the same ctx so all nested extractions accumulate in ctx.extractedTypes
  // and dedup works correctly.
  let processed = ref(0)
  while processed.contents < Array.length(ctx.extractedTypes) {
    let idx = processed.contents
    let {irType, isUnboxed, _}: GenerationContext.extractedType = ctx.extractedTypes->Array.getUnsafe(idx)
    if !isUnboxed {
      // Generate at top level to discover nested extractions
      ignore(generateTypeWithContext(~ctx, ~depth=0, ~inline=false, irType))
    } else {
      // For unboxed variants, walk union members to discover nested extractions
      switch irType {
      | Union(types) =>
        types->Array.forEach(memberType => {
          ignore(generateTypeWithContext(~ctx, ~depth=0, ~inline=true, memberType))
        })
      | _ => ignore(generateTypeWithContext(~ctx, ~depth=0, ~inline=false, irType))
      }
    }
    processed := idx + 1
  }

  let allExtracted = Array.copy(ctx.extractedTypes)

  // Generate final code for each extracted type.
  let extractedDefs = allExtracted->Array.map(({typeName, irType, isUnboxed}: GenerationContext.extractedType) => {
    if isUnboxed {
      switch irType {
      | Union(types) =>
        let body = generateUnboxedVariantBody(~ctx, types)
        `@unboxed type ${typeName} = ${body}`
      | _ =>
        let auxType = generateTypeWithContext(~ctx, ~depth=0, irType)
        `type ${typeName} = ${auxType}`
      }
    } else {
      let auxType = generateTypeWithContext(~ctx, ~depth=0, irType)
      `type ${typeName} = ${auxType}`
    }
  })

  // Reverse so deeper-nested types are defined first (dependencies before dependents)
  let reversedExtracted = allExtracted->Array.toReversed

  let allDefs = Array.concat(extractedDefs->Array.toReversed, [`${doc}type ${namedSchema.name} = ${mainType}`])
  (
    allDefs->Array.join("\n\n"),
    ctx.warnings,
    reversedExtracted,
  )
}

let generateAllTypes = (~context: SchemaIR.schemaContext) => {
  let warnings = []
  let types =
    Dict.valuesToArray(context.schemas)
    ->Array.toSorted((a, b) => String.compare(a.name, b.name))
    ->Array.map(s => {
      let (code, w, _) = generateNamedType(~namedSchema=s)
      warnings->Array.pushMany(w)
      code
    })
  (types, warnings)
}

let generateTypeAndSchema = (~namedSchema) => {
  let (tCode, tW, extractedTypes) = generateNamedType(~namedSchema)
  let (sCode, sW) = IRToSuryGenerator.generateNamedSchema(~namedSchema, ~extractedTypes)
  ((tCode, sCode), Array.concat(tW, sW))
}