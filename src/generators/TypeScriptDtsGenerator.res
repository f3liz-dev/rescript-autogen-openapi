// SPDX-License-Identifier: MPL-2.0

// TypeScriptDtsGenerator.res - Generate TypeScript .d.ts definition files
open Types

let getFirstJsonSchema = (contentDict: dict<mediaType>): option<jsonSchema> =>
  Dict.keysToArray(contentDict)
  ->Array.get(0)
  ->Option.flatMap(contentType => Dict.get(contentDict, contentType))
  ->Option.flatMap(mediaType => mediaType.schema)

let generateTypeScriptType = (name, description, schema) => {
  let (irType, _) = SchemaIRParser.parseJsonSchema(schema)
  IRToTypeScriptGenerator.generateNamedType(~namedSchema={name, description, type_: irType})
}

// Generate TypeScript interface for request type
let generateRequestInterface = (~endpoint: endpoint, ~functionName) => {
  let requestTypeName = `${CodegenUtils.toPascalCase(functionName)}Request`
  endpoint.requestBody->Option.flatMap(body =>
    getFirstJsonSchema(body.content)->Option.map(schema =>
      generateTypeScriptType(requestTypeName, body.description, schema)
    )
  )
}

// Generate TypeScript interface for response type
let generateResponseInterface = (~endpoint: endpoint, ~functionName) => {
  let responseTypeName = `${CodegenUtils.toPascalCase(functionName)}Response`
  let successCodes = ["200", "201", "202", "204"]
  let successResponse = successCodes
    ->Array.filterMap(code => Dict.get(endpoint.responses, code))
    ->Array.get(0)

  successResponse
  ->Option.flatMap(response =>
    response.content
    ->Option.flatMap(getFirstJsonSchema)
    ->Option.map(schema => generateTypeScriptType(responseTypeName, response.description->Some, schema))
  )
  ->Option.getOr(`export type ${responseTypeName} = void;`)
}

// Generate method signature for endpoint in an interface
let generateMethodSignature = (~endpoint: endpoint, ~functionName) => {
  let params = endpoint.requestBody->Option.isSome
    ? `client: MisskeyClient, request: ${CodegenUtils.toPascalCase(functionName)}Request`
    : "client: MisskeyClient"

  let docLines = switch (endpoint.summary, endpoint.description) {
  | (None, None) => ""
  | (Some(summary), None) => `  /** ${summary} */`
  | (None, Some(desc)) => {
      let lines = desc->String.split("\n")->Array.map(line => line == "" ? "   *" : `   * ${line}`)
      `  /**\n${lines->Array.join("\n")}\n   */`
    }
  | (Some(summary), Some(desc)) if summary == desc => `  /** ${summary} */`
  | (Some(summary), Some(desc)) => {
      let descLines = desc->String.split("\n")->Array.map(line => line == "" ? "   *" : `   * ${line}`)
      `  /**\n   * ${summary}\n   *\n${descLines->Array.join("\n")}\n   */`
    }
  }

  Handlebars.render(
    Templates.methodSignature,
    {
      "docLines": docLines,
      "functionName": functionName,
      "params": params,
      "responsePascalName": CodegenUtils.toPascalCase(functionName),
    },
  )
}

// Generate .d.ts file for a module (grouped by tag)
let generateModuleDts = (~moduleName, ~endpoints: array<endpoint>) => {
  let interfaces =
    endpoints
    ->Array.map(endpoint => {
      let functionName = CodegenUtils.generateOperationName(
        endpoint.operationId,
        endpoint.path,
        endpoint.method,
      )
      let requestPart =
        generateRequestInterface(~endpoint, ~functionName)->Option.getOr("")
      let responsePart = generateResponseInterface(~endpoint, ~functionName)
      [requestPart, responsePart]->Array.filter(s => s != "")->Array.join("\n")
    })
    ->Array.join("\n\n")

  let methodSignatures =
    endpoints
    ->Array.map(endpoint =>
      generateMethodSignature(
        ~endpoint,
        ~functionName=CodegenUtils.generateOperationName(
          endpoint.operationId,
          endpoint.path,
          endpoint.method,
        ),
      )
    )
    ->Array.join("\n")

  Handlebars.render(
    Templates.moduleDts,
    {
      "moduleName": moduleName,
      "interfaces": interfaces,
      "methodSignatures": methodSignatures,
    },
  )
}

// Generate ComponentSchemas.d.ts
let generateComponentSchemasDts = (~schemas: Dict.t<jsonSchema>) => {
  let content =
    Dict.toArray(schemas)
    ->Array.map(((name, schema)) => generateTypeScriptType(name, schema.description, schema))
    ->Array.join("\n\n")

  Handlebars.render(
    Templates.componentSchemasDts,
    {"content": content},
  )
}

// Generate main index.d.ts with MisskeyClient class
let generateIndexDts = (~moduleNames) => {
  let modules = moduleNames->Array.map(m => {
    "importLine": `import { ${m}Module } from './${m}';`,
    "exportLine": `export const ${m}: ${m}Module;`,
  })

  Handlebars.render(Templates.indexDts, {"modules": modules})
}

// Generate all .d.ts files for a spec
let generate = (~spec: openAPISpec, ~endpoints, ~outputDir): Pipeline.generationOutput => {
  let endpointsByTag = OpenAPIParser.groupByTag(endpoints)
  let moduleNames = []
  let files =
    Dict.toArray(endpointsByTag)
    ->Array.filterMap(((tag, tagEndpoints)) =>
      if Array.length(tagEndpoints) > 0 {
        let name = CodegenUtils.toPascalCase(tag)
        moduleNames->Array.push(name)
        Some({
          FileSystem.path: FileSystem.makePath(outputDir, `types/${name}.d.ts`),
          content: generateModuleDts(~moduleName=name, ~endpoints=tagEndpoints),
        })
      } else {
        None
      }
    )

  spec.components
  ->Option.flatMap(c => c.schemas)
  ->Option.forEach(schemas =>
    files->Array.push({
      path: FileSystem.makePath(outputDir, "types/ComponentSchemas.d.ts"),
      content: generateComponentSchemasDts(~schemas=schemas),
    })
  )

  files->Array.push({
    path: FileSystem.makePath(outputDir, "types/index.d.ts"),
    content: generateIndexDts(~moduleNames),
  })

  {files, warnings: []}
}