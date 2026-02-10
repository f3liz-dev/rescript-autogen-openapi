// SPDX-License-Identifier: MPL-2.0

// ModuleGenerator.res - Generate API modules organized by tags or in a flat structure
open Types

let generateSchemaCodeForDict = (schemaDict: dict<jsonSchema>) =>
  Dict.toArray(schemaDict)
  ->Array.toSorted(((nameA, _), (nameB, _)) => String.compare(nameA, nameB))
  ->Array.flatMap(((name, schema)) => {
    let (ir, _) = SchemaIRParser.parseJsonSchema(schema)
    let (typeCode, _, extractedTypes) = IRToTypeGenerator.generateNamedType(
      ~namedSchema={name: name, description: schema.description, type_: ir},
    )
    let (schemaCode, _) = IRToSuryGenerator.generateNamedSchema(
      ~namedSchema={name: `${name}Schema`, description: schema.description, type_: ir},
      ~extractedTypes,
    )
    [typeCode->CodegenUtils.indent(2), schemaCode->CodegenUtils.indent(2), ""]
  })

let generateTagModulesCode = (endpoints: array<endpoint>, ~overrideDir=?, ~indent=2) => {
  let groupedByTag = OpenAPIParser.groupByTag(endpoints)
  let indentStr = " "->String.repeat(indent)

  Dict.keysToArray(groupedByTag)
  ->Array.toSorted(String.compare)
  ->Array.filterMap(tag =>
    groupedByTag
    ->Dict.get(tag)
    ->Option.map(tagEndpoints => {
      let moduleName = CodegenUtils.toPascalCase(tag)
      let endpointLines = tagEndpoints->Array.flatMap(endpoint => [
        EndpointGenerator.generateEndpointCode(
          endpoint,
          ~overrideDir?,
          ~moduleName,
        )->CodegenUtils.indent(indent + 2),
        "",
      ])
      Array.concat(
        [`${indentStr}module ${moduleName} = {`],
        Array.concat(endpointLines, [`${indentStr}}`, ""]),
      )
    })
  )
  ->Array.flatMap(lines => lines)
}

let generateTagModuleFile = (
  ~tag,
  ~endpoints,
  ~includeSchemas as _: bool=true,
  ~wrapInModule=false,
  ~overrideDir=?,
) => {
  let moduleName = CodegenUtils.toPascalCase(tag)
  let header = CodegenUtils.generateFileHeader(~description=`API endpoints for ${tag}`)
  let body =
    endpoints
    ->Array.map(endpoint =>
      EndpointGenerator.generateEndpointCode(endpoint, ~overrideDir?, ~moduleName)
    )
    ->Array.join("\n\n")

  if wrapInModule {
    Handlebars.render(
      Templates.moduleWrapped,
      {
        "header": header->String.trimEnd,
        "moduleName": moduleName,
        "body": body->CodegenUtils.indent(2),
      },
    )
  } else {
    Handlebars.render(
      Templates.moduleUnwrapped,
      {
        "header": header->String.trimEnd,
        "body": body,
      },
    )
  }
}

let generateAllTagModules = (
  ~endpoints,
  ~includeSchemas=true,
  ~wrapInModule=false,
  ~overrideDir=?,
) => {
  let groupedByTag = OpenAPIParser.groupByTag(endpoints)
  Dict.toArray(groupedByTag)
  ->Array.toSorted(((tagA, _), (tagB, _)) => String.compare(tagA, tagB))
  ->Array.map(((tag, tagEndpoints)) => (
    tag,
    generateTagModuleFile(~tag, ~endpoints=tagEndpoints, ~includeSchemas, ~wrapInModule, ~overrideDir?),
  ))
}

let generateIndexModule = (~tags, ~moduleName="API") => {
  let header = CodegenUtils.generateFileHeader(~description="Main API module index")
  let tagData =
    tags
    ->Array.toSorted(String.compare)
    ->Array.map(tag => {"modulePascal": CodegenUtils.toPascalCase(tag)})

  Handlebars.render(
    Templates.indexModule,
    {
      "header": header->String.trimEnd,
      "moduleName": moduleName,
      "tags": tagData,
    },
  )
}

let generateFlatModuleCode = (~moduleName, ~endpoints, ~overrideDir=?) => {
  let header = CodegenUtils.generateFileHeader(~description=`All API endpoints in ${moduleName}`)
  let body =
    endpoints
    ->Array.map(endpoint =>
      EndpointGenerator.generateEndpointCode(
        endpoint,
        ~overrideDir?,
        ~moduleName,
      )->CodegenUtils.indent(2)
    )
    ->Array.join("\n\n")

  Handlebars.render(
    Templates.moduleWrapped,
    {
      "header": header->String.trimEnd,
      "moduleName": moduleName,
      "body": body,
    },
  )
}

let internalGenerateIntegratedModule = (
  ~name,
  ~description,
  ~endpoints,
  ~schemas,
  ~overrideDir=?,
  ~isExtension=false,
  ~includeHeader=true,
) => {
  let lines = []
  
  if includeHeader {
    lines->Array.pushMany([CodegenUtils.generateFileHeader(~description), ""])
  }

  lines->Array.push(`module ${name} = {`)

  schemas->Option.forEach(schemaDict =>
    if Dict.keysToArray(schemaDict)->Array.length > 0 {
      lines->Array.pushMany([
        `  // ${isExtension ? "Extension" : "Component"} Schemas`,
        "",
        ...generateSchemaCodeForDict(schemaDict),
      ])
    }
  )

  if Array.length(endpoints) > 0 {
    if isExtension {
      lines->Array.pushMany(["  // Extension Endpoints", ""])
    }
    lines->Array.pushMany(generateTagModulesCode(endpoints, ~overrideDir?))
  }

  lines->Array.push("}")
  Array.join(lines, "\n")
}

let generateSharedModule = (~endpoints, ~schemas, ~overrideDir=?, ~includeHeader=true) =>
  internalGenerateIntegratedModule(
    ~name="Shared",
    ~description="Shared API code",
    ~endpoints,
    ~schemas,
    ~overrideDir?,
    ~includeHeader,
  )

let generateExtensionModule = (~forkName, ~endpoints, ~schemas, ~overrideDir=?, ~includeHeader=true) =>
  internalGenerateIntegratedModule(
    ~name=`${CodegenUtils.toPascalCase(forkName)}Extensions`,
    ~description=`${forkName} extensions`,
    ~endpoints,
    ~schemas,
    ~overrideDir?,
    ~isExtension=true,
    ~includeHeader,
  )

let generateCombinedModule = (
  ~forkName,
  ~sharedEndpoints,
  ~extensionEndpoints,
  ~sharedSchemas,
  ~extensionSchemas,
  ~overrideDir=?,
) => {
  let header = CodegenUtils.generateFileHeader(~description=`Combined Shared and ${forkName} extensions`)
  
  let shared = generateSharedModule(
    ~endpoints=sharedEndpoints,
    ~schemas=sharedSchemas,
    ~overrideDir?,
    ~includeHeader=false,
  )
  
  let extension = generateExtensionModule(
    ~forkName,
    ~endpoints=extensionEndpoints,
    ~schemas=extensionSchemas,
    ~overrideDir?,
    ~includeHeader=false,
  )
  
  Handlebars.render(
    Templates.combinedModule,
    {
      "header": header->String.trimEnd,
      "shared": shared,
      "extension": extension,
    },
  )
}

let generateTagModuleFiles = (~endpoints, ~outputDir, ~wrapInModule=false, ~overrideDir=?) => {
  let files =
    generateAllTagModules(~endpoints, ~includeSchemas=true, ~wrapInModule, ~overrideDir?)->Array.map(((
      tag,
      content,
    )) => {
      let path = FileSystem.makePath(outputDir, `${CodegenUtils.toPascalCase(tag)}.res`)
      ({path, content}: FileSystem.fileToWrite)
    })
  Pipeline.fromFilesAndWarnings(files, [])
}

let generateFlatModuleFile = (~moduleName, ~endpoints, ~outputDir, ~overrideDir=?) => {
  let path = FileSystem.makePath(outputDir, `${moduleName}.res`)
  let content = generateFlatModuleCode(~moduleName, ~endpoints, ~overrideDir?)
  Pipeline.fromFile(({path, content}: FileSystem.fileToWrite))
}

let generateInstanceTagModules = (
  ~instanceName,
  ~modulePrefix,
  ~endpoints,
  ~schemas,
  ~outputDir,
  ~overrideDir=?,
) => {
  let apiDir = FileSystem.makePath(FileSystem.makePath(outputDir, instanceName), "api")

  let schemaFiles = schemas->Option.mapOr([], schemaDict =>
    if Dict.keysToArray(schemaDict)->Array.length == 0 {
      []
    } else {
      let result = ComponentSchemaGenerator.generate(
        ~spec={
          openapi: "3.1.0",
          info: {title: instanceName, version: "1.0.0", description: None},
          paths: Dict.make(),
          components: Some({schemas: Some(schemaDict)}),
        },
        ~outputDir=apiDir,
      )
      result.files->Array.map(file =>
        if file.path->String.endsWith("ComponentSchemas.res") {
          {
            ...file,
            path: file.path->String.replace(
              "ComponentSchemas.res",
              `${modulePrefix}ComponentSchemas.res`,
            ),
          }
        } else {
          file
        }
      )
    }
  )

  let groupedByTag = OpenAPIParser.groupByTag(endpoints)
  let endpointFiles =
    Dict.toArray(groupedByTag)
    ->Array.toSorted(((tagA, _), (tagB, _)) => String.compare(tagA, tagB))
    ->Array.filterMap(((tag, tagEndpoints)) => {
      let moduleName = `${modulePrefix}${CodegenUtils.toPascalCase(tag)}`
      let endpointCodes = tagEndpoints->Array.flatMap(endpoint => [
        EndpointGenerator.generateEndpointCode(endpoint, ~overrideDir?, ~moduleName, ~modulePrefix),
        "",
      ])
      let content = Array.join(
        [
          CodegenUtils.generateFileHeader(~description=`${instanceName} API for ${tag}`),
          "",
          ...endpointCodes,
        ],
        "\n",
      )
      let path = FileSystem.makePath(apiDir, `${moduleName}.res`)
      Some(({path, content}: FileSystem.fileToWrite))
    })

  Pipeline.fromFilesAndWarnings(Array.concat(schemaFiles, endpointFiles), [])
}

let generateBaseTagModules = (~baseName, ~basePrefix, ~endpoints, ~schemas, ~outputDir, ~overrideDir=?) =>
  generateInstanceTagModules(
    ~instanceName=baseName,
    ~modulePrefix=basePrefix,
    ~endpoints,
    ~schemas,
    ~outputDir,
    ~overrideDir?,
  )

let generateForkTagModules = (~forkName, ~forkPrefix, ~endpoints, ~schemas, ~outputDir, ~overrideDir=?) =>
  generateInstanceTagModules(
    ~instanceName=forkName,
    ~modulePrefix=forkPrefix,
    ~endpoints,
    ~schemas,
    ~outputDir,
    ~overrideDir?,
  )

let generateSeparatePerTagModules = (
  ~baseName,
  ~basePrefix,
  ~forkName,
  ~forkPrefix=None,
  ~sharedEndpoints,
  ~extensionEndpoints,
  ~sharedSchemas,
  ~extensionSchemas,
  ~outputDir,
  ~overrideDir=?,
) =>
  Pipeline.combine([
    generateBaseTagModules(
      ~baseName,
      ~basePrefix,
      ~endpoints=sharedEndpoints,
      ~schemas=sharedSchemas,
      ~outputDir,
      ~overrideDir?,
    ),
    generateForkTagModules(
      ~forkName,
      ~forkPrefix=Option.getOr(forkPrefix, CodegenUtils.toPascalCase(forkName)),
      ~endpoints=extensionEndpoints,
      ~schemas=extensionSchemas,
      ~outputDir,
      ~overrideDir?,
    ),
  ])
