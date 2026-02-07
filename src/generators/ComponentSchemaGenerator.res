// SPDX-License-Identifier: MPL-2.0

// ComponentSchemaGenerator.res - Generate shared component schema module
open Types

let rec extractReferencedSchemaNames = (irType: SchemaIR.irType) =>
  switch irType {
  | Reference(ref) =>
    let parts = ref->String.split("/")
    [parts->Array.get(parts->Array.length - 1)->Option.getOr("")]
  | Array({items}) => extractReferencedSchemaNames(items)
  | Object({properties}) => properties->Array.flatMap(((_name, fieldType, _)) => extractReferencedSchemaNames(fieldType))
  | Union(types)
  | Intersection(types) =>
    types->Array.flatMap(extractReferencedSchemaNames)
  | Option(inner) => extractReferencedSchemaNames(inner)
  | _ => []
  }

let generate = (~spec, ~outputDir) => {
  let (context, parseWarnings) =
    spec.components
    ->Option.flatMap(components => components.schemas)
    ->Option.mapOr(({SchemaIR.schemas: Dict.make()}, []), schemas =>
      SchemaIRParser.parseComponentSchemas(schemas)
    )

  if Dict.size(context.schemas) == 0 {
    Pipeline.empty
  } else {
    let schemas = Dict.valuesToArray(context.schemas)
    let schemaNameMap = Dict.fromArray(schemas->Array.map(s => (s.name, s)))

    // Map each schema to its internal dependencies (other schemas in the same spec)
    let dependencyMap = schemas->Array.reduce(Dict.make(), (acc, schema) => {
      let references =
        extractReferencedSchemaNames(schema.type_)->Array.filter(name =>
          Dict.has(schemaNameMap, name) && name != schema.name
        )
      Dict.set(acc, schema.name, references)
      acc
    })

    // Topological sort (Kahn's algorithm) to handle schema dependencies
    let sortedSchemas = []
    let inDegreeMap = schemas->Array.reduce(Dict.make(), (acc, schema) => {
      let degree = Dict.get(dependencyMap, schema.name)->Option.mapOr(0, Array.length)
      Dict.set(acc, schema.name, degree)
      acc
    })

    let queue = schemas->Array.filter(schema => Dict.get(inDegreeMap, schema.name)->Option.getOr(0) == 0)

    while Array.length(queue) > 0 {
      let schema = switch Array.shift(queue) {
      | Some(v) => v
      | None => schemas->Array.getUnsafe(0) // Should not happen
      }
      sortedSchemas->Array.push(schema)

      schemas->Array.forEach(otherSchema => {
        let dependsOnCurrent =
          Dict.get(dependencyMap, otherSchema.name)
          ->Option.getOr([])
          ->Array.some(name => name == schema.name)

        if dependsOnCurrent {
          let currentDegree = Dict.get(inDegreeMap, otherSchema.name)->Option.getOr(0)
          let newDegree = currentDegree - 1
          Dict.set(inDegreeMap, otherSchema.name, newDegree)
          if newDegree == 0 {
            queue->Array.push(otherSchema)
          }
        }
      })
    }

    // Ensure all schemas are included even if there's a circular dependency
    let sortedNames = sortedSchemas->Array.map(s => s.name)
    let remainingSchemas =
      schemas
      ->Array.filter(s => !(sortedNames->Array.some(name => name == s.name)))
      ->Array.toSorted((a, b) => String.compare(a.name, b.name))

    let finalSortedSchemas = Array.concat(sortedSchemas, remainingSchemas)
    let availableSchemaNames = finalSortedSchemas->Array.map(s => s.name)
    let warnings = Array.copy(parseWarnings)

    let moduleCodes = finalSortedSchemas->Array.map(schema => {
      let typeCtx = GenerationContext.make(
        ~path=`ComponentSchemas.${schema.name}`,
        ~insideComponentSchemas=true,
        ~availableSchemas=availableSchemaNames,
        (),
      )
      let schemaCtx = GenerationContext.make(
        ~path=`ComponentSchemas.${schema.name}`,
        ~insideComponentSchemas=true,
        ~availableSchemas=availableSchemaNames,
        (),
      )

      let typeCode = IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, schema.type_)
      let schemaCode = IRToSuryGenerator.generateSchemaWithContext(~ctx=schemaCtx, ~depth=0, schema.type_)

      warnings->Array.pushMany(typeCtx.warnings)
      warnings->Array.pushMany(schemaCtx.warnings)

      let docComment = schema.description->Option.mapOr("", d =>
        CodegenUtils.generateDocString(~description=d, ())
      )

      `${docComment}module ${CodegenUtils.toPascalCase(schema.name)} = {
  type t = ${typeCode}
  let schema = ${schemaCode}
}`
    })

    let fileHeader = CodegenUtils.generateFileHeader(~description="Shared component schemas")
    let fileContent = `${fileHeader}\n\n${moduleCodes->Array.join("\n\n")}`

    Pipeline.fromFilesAndWarnings(
      [{path: FileSystem.makePath(outputDir, "ComponentSchemas.res"), content: fileContent}],
      warnings,
    )
  }
}