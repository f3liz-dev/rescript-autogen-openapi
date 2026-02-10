// SPDX-License-Identifier: MPL-2.0

// ComponentSchemaGenerator.res - Generate shared component schema module
open Types

let rec extractReferencedSchemaNames = (irType: SchemaIR.irType) =>
  switch irType {
  | Reference(ref) =>
    // After normalization, ref is just the schema name (no path prefix)
    [ref]
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

    // Build dependency edges for topological sort
    // Edge (A, B) means "A depends on B" so B must come before A
    let allNodes = schemas->Array.map(s => s.name)
    let edges = schemas->Array.flatMap(schema => {
      let references =
        extractReferencedSchemaNames(schema.type_)->Array.filter(name =>
          Dict.has(schemaNameMap, name) && name != schema.name
        )
      references->Array.map(dep => (schema.name, dep))
    })

    // Use toposort with cycle tolerance: if there's a cycle, catch and fall back
    // Note: toposort returns dependents first, dependencies last.
    // We reverse to get execution order (dependencies first).
    let sortedNames = try {
      Toposort.sortArray(allNodes, edges)->Array.toReversed
    } catch {
    | _ =>
      // Cycles exist — remove back-edges and re-sort
      let visited = Dict.make()
      let inStack = Dict.make()
      let cycleEdges: array<(string, string)> = []
      
      let rec dfs = (node) => {
        if Dict.get(inStack, node)->Option.getOr(false) {
          ()
        } else if Dict.get(visited, node)->Option.getOr(false) {
          ()
        } else {
          Dict.set(visited, node, true)
          Dict.set(inStack, node, true)
          edges->Array.forEach(((from, to)) => {
            if from == node {
              if Dict.get(inStack, to)->Option.getOr(false) {
                cycleEdges->Array.push((from, to))
              } else {
                dfs(to)
              }
            }
          })
          Dict.set(inStack, node, false)
        }
      }
      allNodes->Array.forEach(dfs)
      
      let nonCycleEdges = edges->Array.filter(((from, to)) =>
        !(cycleEdges->Array.some(((cf, ct)) => cf == from && ct == to))
      )
      try {
        Toposort.sortArray(allNodes, nonCycleEdges)->Array.toReversed
      } catch {
      | _ => allNodes->Array.toSorted((a, b) => String.compare(a, b))
      }
    }

    let finalSortedSchemas = sortedNames->Array.filterMap(name => Dict.get(schemaNameMap, name))
    let availableSchemaNames = finalSortedSchemas->Array.map(s => s.name)
    let warnings = Array.copy(parseWarnings)

    // Detect self-referencing schemas (schema references itself directly or indirectly through properties)
    let selfRefSchemas = Dict.make()
    finalSortedSchemas->Array.forEach(schema => {
      let refs = extractReferencedSchemaNames(schema.type_)
      if refs->Array.some(name => name == schema.name) {
        Dict.set(selfRefSchemas, schema.name, true)
      }
    })

    let moduleCodes = finalSortedSchemas->Array.map(schema => {
      let isSelfRef = Dict.get(selfRefSchemas, schema.name)->Option.getOr(false)
      let selfRefName = isSelfRef ? Some(schema.name) : None
      
      let typeCtx = GenerationContext.make(
        ~path=`ComponentSchemas.${schema.name}`,
        ~insideComponentSchemas=true,
        ~availableSchemas=availableSchemaNames,
        ~selfRefName?,
        (),
      )

      let typeCode = IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, schema.type_)

      // Iteratively resolve nested extractions using typeCtx
      let processed = ref(0)
      while processed.contents < Array.length(typeCtx.extractedTypes) {
        let idx = processed.contents
        let {irType, isUnboxed, _}: GenerationContext.extractedType = typeCtx.extractedTypes->Array.getUnsafe(idx)
        if !isUnboxed {
          ignore(IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, ~inline=false, irType))
        } else {
          switch irType {
          | Union(types) =>
            types->Array.forEach(memberType => {
              ignore(IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, ~inline=true, memberType))
            })
          | _ => ignore(IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, ~inline=false, irType))
          }
        }
        processed := idx + 1
      }

      let allExtracted = Array.copy(typeCtx.extractedTypes)->Array.toReversed
      let extractedTypeMap = if Array.length(allExtracted) > 0 { Some(allExtracted) } else { None }

      // Generate schema with extracted type map for correct references
      let schemaCtx = GenerationContext.make(
        ~path=`ComponentSchemas.${schema.name}`,
        ~insideComponentSchemas=true,
        ~availableSchemas=availableSchemaNames,
        ~selfRefName?,
        (),
      )
      let schemaCode = IRToSuryGenerator.generateSchemaWithContext(~ctx=schemaCtx, ~depth=0, ~extractedTypeMap?, schema.type_)

      warnings->Array.pushMany(typeCtx.warnings)
      warnings->Array.pushMany(schemaCtx.warnings)

      // Generate extracted auxiliary types and schemas (use ctx for dedup)
      let extractedTypeDefs = allExtracted->Array.map(({typeName, irType, isUnboxed}: GenerationContext.extractedType) => {
        let auxTypeCode = if isUnboxed {
          switch irType {
          | Union(types) =>
            let body = IRToTypeGenerator.generateUnboxedVariantBody(~ctx=typeCtx, types)
            `@unboxed type ${typeName} = ${body}`
          | _ =>
            let auxType = IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, irType)
            `type ${typeName} = ${auxType}`
          }
        } else {
          let auxType = IRToTypeGenerator.generateTypeWithContext(~ctx=typeCtx, ~depth=0, irType)
          `type ${typeName} = ${auxType}`
        }
        let auxSchemaCtx = GenerationContext.make(
          ~path=`ComponentSchemas.${schema.name}.${typeName}`,
          ~insideComponentSchemas=true,
          ~availableSchemas=availableSchemaNames,
          (),
        )
        // Exclude the current type from the map to avoid self-reference
        let filteredMap = allExtracted->Array.filter(({typeName: tn}: GenerationContext.extractedType) => tn != typeName)
        let auxExtractedTypeMap = if Array.length(filteredMap) > 0 { Some(filteredMap) } else { None }
        let auxSchema = IRToSuryGenerator.generateSchemaWithContext(~ctx=auxSchemaCtx, ~depth=0, ~extractedTypeMap=?auxExtractedTypeMap, irType)
        `  ${auxTypeCode}\n  let ${typeName}Schema = ${auxSchema}`
      })

      let docComment = schema.description->Option.mapOr("", d =>
        CodegenUtils.generateDocString(~description=d, ())
      )

      let extractedBlock = if Array.length(extractedTypeDefs) > 0 {
        extractedTypeDefs->Array.join("\n") ++ "\n"
      } else {
        ""
      }

      // Use `type rec t` for self-referential types
      let typeKeyword = isSelfRef ? "type rec t" : "type t"
      // Wrap schema in S.recursive for self-referential types
      let finalSchemaCode = isSelfRef
        ? `S.recursive("${schema.name}", schema => ${schemaCode})`
        : schemaCode

      Handlebars.render(Templates.componentSchemaModule, {
        "docComment": docComment,
        "moduleName": CodegenUtils.toPascalCase(schema.name),
        "extractedBlock": extractedBlock,
        "typeKeyword": `  ${typeKeyword}`,
        "typeCode": typeCode,
        "schemaCode": finalSchemaCode,
      })
    })

    let fileHeader = CodegenUtils.generateFileHeader(~description="Shared component schemas")
    let fileContent = `${fileHeader}\n\n${moduleCodes->Array.join("\n\n")}`

    Pipeline.fromFilesAndWarnings(
      [{path: FileSystem.makePath(outputDir, "ComponentSchemas.res"), content: fileContent}],
      warnings,
    )
  }
}