// SPDX-License-Identifier: MPL-2.0

// IRToTypeGenerator.res - Generate ReScript types from Schema IR
open Types

let addWarning = GenerationContext.addWarning

let rec generateTypeWithContext = (~ctx: GenerationContext.t, ~depth=0, irType: SchemaIR.irType): string => {
  // We keep a high depth limit just to prevent infinite recursion on circular schemas that escaped IRBuilder
  if depth > 100 {
    addWarning(ctx, DepthLimitReached({depth, path: ctx.path}))
    "JSON.t"
  } else {
    let recurse = nextIrType => generateTypeWithContext(~ctx, ~depth=depth + 1, nextIrType)

    switch irType {
    | String(_) => "string"
    | Number(_) => "float"
    | Integer(_) => "int"
    | Boolean => "bool"
    | Null => "unit"
    | Array({items}) => `array<${recurse(items)}>`
    | Object({properties, additionalProperties}) =>
      if Array.length(properties) == 0 {
        switch additionalProperties {
        | Some(valueType) => `dict<${recurse(valueType)}>`
        | None => "JSON.t"
        }
      } else {
        let fields =
          properties
          ->Array.map(((name, fieldType, isRequired)) => {
            let typeCode = recurse(fieldType)
            let finalType = isRequired ? typeCode : `option<${typeCode}>`
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
        let inner = recurse(nonNullTypes->Array.getUnsafe(0))
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
          `array<${recurse(Option.getOr(arrayItemType, Unknown))}>`
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
          // Generate @unboxed variant for mixed-type unions
          let hasPrimitives = ref(false)
          let variantCases = effectiveTypes->Array.mapWithIndex((t, i) => {
            let (tag, typeStr) = switch t {
            | String(_) => { hasPrimitives := true; ("String", "string") }
            | Number(_) => { hasPrimitives := true; ("Float", "float") }
            | Integer(_) => { hasPrimitives := true; ("Int", "int") }
            | Boolean => { hasPrimitives := true; ("Bool", "bool") }
            | Array({items}) => ("Array", `array<${recurse(items)}>`)
            | Object(_) => ("Object", recurse(t))
            | Reference(ref) => {
                let name = ref->String.split("/")->Array.get(ref->String.split("/")->Array.length - 1)->Option.getOr("")
                (CodegenUtils.toPascalCase(name), recurse(t))
              }
            | _ => (`V${Int.toString(i)}`, recurse(t))
            }
            `  | ${tag}(${typeStr})`
          })
          let unboxedAttr = hasPrimitives.contents ? "@unboxed " : ""
          `${unboxedAttr}[\n${variantCases->Array.join("\n")}\n]`
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
          // All objects: merge properties
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let typeCode = recurse(fieldType)
              let finalType = isRequired ? typeCode : `option<${typeCode}>`
              let camelName = name->CodegenUtils.toCamelCase
              let escapedName = camelName->CodegenUtils.escapeKeyword
              let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
              `  ${aliasAnnotation}${escapedName}: ${finalType},`
            })
            ->Array.join("\n")
          `{\n${fields}\n}`
        } else if Array.length(nonObjectTypes) > 0 && Array.length(objectProps) == 0 {
          // No objects: pick last type as best effort
          recurse(types->Array.get(Array.length(types) - 1)->Option.getOr(Unknown))
        } else {
          addWarning(
            ctx,
            IntersectionNotFullySupported({location: ctx.path, note: "Mixed object/non-object intersection"}),
          )
          // Merge what we can, ignore non-object parts
          let fields =
            objectProps
            ->Array.map(((name, fieldType, isRequired)) => {
              let typeCode = recurse(fieldType)
              let finalType = isRequired ? typeCode : `option<${typeCode}>`
              let camelName = name->CodegenUtils.toCamelCase
              let escapedName = camelName->CodegenUtils.escapeKeyword
              let aliasAnnotation = escapedName != name ? `@as("${name}") ` : ""
              `  ${aliasAnnotation}${escapedName}: ${finalType},`
            })
            ->Array.join("\n")
          `{\n${fields}\n}`
        }
      }
    | Option(inner) => `option<${recurse(inner)}>`
    | Reference(ref) =>
      let typePath = switch ctx.availableSchemas {
      | Some(available) =>
        let name =
          ref
          ->String.split("/")
          ->Array.get(ref->String.split("/")->Array.length - 1)
          ->Option.getOr("")
        available->Array.includes(name)
          ? `${CodegenUtils.toPascalCase(name)}.t`
          : `ComponentSchemas.${CodegenUtils.toPascalCase(name)}.t`
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
    | Unknown => "JSON.t"
    }
  }
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
  (
    `${doc}type ${namedSchema.name} = ${generateTypeWithContext(~ctx, ~depth=0, namedSchema.type_)}`,
    ctx.warnings,
  )
}

let generateAllTypes = (~context: SchemaIR.schemaContext) => {
  let warnings = []
  let types =
    Dict.valuesToArray(context.schemas)
    ->Array.toSorted((a, b) => String.compare(a.name, b.name))
    ->Array.map(s => {
      let (code, w) = generateNamedType(~namedSchema=s)
      warnings->Array.pushMany(w)
      code
    })
  (types, warnings)
}

let generateTypeAndSchema = (~namedSchema) => {
  let (tCode, tW) = generateNamedType(~namedSchema)
  let (sCode, sW) = IRToSuryGenerator.generateNamedSchema(~namedSchema)
  ((tCode, sCode), Array.concat(tW, sW))
}