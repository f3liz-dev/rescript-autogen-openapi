// SPDX-License-Identifier: MPL-2.0

// IRToSuryGenerator.res - Generate Sury schema code from Schema IR
open Types

let addWarning = GenerationContext.addWarning

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

let rec generateSchemaWithContext = (~ctx: GenerationContext.t, ~depth=0, irType: SchemaIR.irType): string => {
  // We keep a high depth limit just to prevent infinite recursion on circular schemas that escaped IRBuilder
  if depth > 100 {
    addWarning(ctx, DepthLimitReached({depth, path: ctx.path}))
    "S.json"
  } else {
    let recurse = nextIrType => generateSchemaWithContext(~ctx, ~depth=depth + 1, nextIrType)

    switch irType {
    | String({constraints: c}) =>
      let s = applyConstraints("S.string", c.minLength, c.maxLength, v => Int.toString(v))
      switch c.pattern {
      | Some(p) => `${s}->S.pattern(%re("/${CodegenUtils.escapeString(p)}/"))`
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
        | None => "S.json"
        }
      } else {
        let fields =
          properties
          ->Array.map(((name, fieldType, isRequired)) => {
            let schemaCode = recurse(fieldType)
            let camelName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
            isRequired
              ? `    ${camelName}: s.field("${name}", ${schemaCode}),`
              : `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
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
          // Generate S.union for mixed-type unions
          `S.union([${effectiveTypes->Array.map(recurse)->Array.join(", ")}])`
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
              isRequired
                ? `    ${camelName}: s.field("${name}", ${schemaCode}),`
                : `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
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
              isRequired
                ? `    ${camelName}: s.field("${name}", ${schemaCode}),`
                : `    ${camelName}: s.fieldOr("${name}", S.nullableAsOption(${schemaCode}), None),`
            })
            ->Array.join("\n")
          `S.object(s => {\n${fields}\n  })`
        }
      }
    | Reference(ref) =>
      let schemaPath = switch ctx.availableSchemas {
      | Some(available) =>
        let name =
          ref
          ->String.split("/")
          ->Array.get(ref->String.split("/")->Array.length - 1)
          ->Option.getOr("")
        available->Array.includes(name)
          ? `${CodegenUtils.toPascalCase(name)}.schema`
          : `ComponentSchemas.${CodegenUtils.toPascalCase(name)}.schema`
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
    | Option(inner) => `S.nullableAsOption(${recurse(inner)})`
    | Unknown => "S.json"
    }
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
  (
    `${doc}let ${namedSchema.name}Schema = ${generateSchemaWithContext(~ctx, ~depth=0, namedSchema.type_)}`,
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