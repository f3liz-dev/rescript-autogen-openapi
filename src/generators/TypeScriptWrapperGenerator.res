// SPDX-License-Identifier: MPL-2.0

// TypeScriptWrapperGenerator.res - Generate TypeScript/JavaScript wrapper
open Types

let misskeyClientJsCode = {
  let body: string = %raw(`
    "export class MisskeyClient {\n  constructor(baseUrl, token) {\n    this.baseUrl = baseUrl;\n    this.token = token;\n  }\n\n  async _fetch(url, method, body) {\n    const headers = { 'Content-Type': 'application/json' };\n    if (this.token) {\n      headers['Authorization'] = \x60Bearer \x24{this.token}\x60;\n    }\n    const response = await fetch(this.baseUrl + url, {\n      method,\n      headers,\n      body: body ? JSON.stringify(body) : undefined,\n    });\n    return response.json();\n  }\n}"
  `)
  body
}

let generateWrapperMjs = (~endpoints, ~generatedModulePath) => {
  let endpointsByTag = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(endpointsByTag)

  let tagData =
    tags
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
      let importLine = `import * as ${moduleName} from '${generatedModulePath}/${moduleName}.mjs';`
      let methods =
        Dict.get(endpointsByTag, tag)
        ->Option.getOr([])
        ->Array.map(endpoint => {
          let functionName = CodegenUtils.generateOperationName(
            endpoint.operationId,
            endpoint.path,
            endpoint.method,
          )
          let hasRequestBody = endpoint.requestBody->Option.isSome
          Handlebars.render(
            Templates.wrapperMjsMethod,
            {
              "functionName": functionName,
              "moduleName": moduleName,
              "requestArg": hasRequestBody ? ", request" : "",
              "bodyArg": hasRequestBody ? "body: request, " : "",
            },
          )
        })
        ->Array.join("\n")

      let namespace = Handlebars.render(
        Templates.wrapperMjsNamespace,
        {"moduleName": moduleName, "methods": methods},
      )
      {"importLine": importLine, "namespace": namespace}
    })

  Handlebars.render(
    Templates.wrapperMjs,
    {"tags": tagData, "clientCode": misskeyClientJsCode},
  )
}

let generateWrapperDts = (~endpoints) => {
  let endpointsByTag = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(endpointsByTag)

  let tagData =
    tags
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
      let typesToImport =
        Dict.get(endpointsByTag, tag)
        ->Option.getOr([])
        ->Array.flatMap(endpoint => {
          let pascalName = CodegenUtils.toPascalCase(
            CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method),
          )
          if endpoint.requestBody->Option.isSome {
            [`  ${pascalName}Request,`, `  ${pascalName}Response,`]
          } else {
            [`  ${pascalName}Response,`]
          }
        })
        ->Array.join("\n")
      let importBlock = `import type {\n${typesToImport}\n} from '../types/${moduleName}.d.ts';`

      let functions =
        Dict.get(endpointsByTag, tag)
        ->Option.getOr([])
        ->Array.map(endpoint => {
          let functionName = CodegenUtils.generateOperationName(
            endpoint.operationId,
            endpoint.path,
            endpoint.method,
          )
          let pascalName = CodegenUtils.toPascalCase(functionName)
          let docComment = switch (endpoint.summary, endpoint.description) {
          | (None, None) => ""
          | (Some(summary), None) => `  /** ${summary} */\n`
          | (None, Some(desc)) => {
              let lines = desc->String.split("\n")->Array.map(line => line == "" ? "   *" : `   * ${line}`)
              `  /**\n${lines->Array.join("\n")}\n   */\n`
            }
          | (Some(summary), Some(desc)) if summary == desc => `  /** ${summary} */\n`
          | (Some(summary), Some(desc)) => {
              let descLines = desc->String.split("\n")->Array.map(line => line == "" ? "   *" : `   * ${line}`)
              `  /**\n   * ${summary}\n   *\n${descLines->Array.join("\n")}\n   */\n`
            }
          }
          let requestParam = endpoint.requestBody->Option.isSome ? `, request: ${pascalName}Request` : ""
          Handlebars.render(
            Templates.wrapperDtsFunction,
            {
              "docComment": docComment,
              "functionName": functionName,
              "requestParam": requestParam,
              "pascalName": pascalName,
            },
          )
        })
        ->Array.join("\n")

      let namespace = Handlebars.render(
        Templates.wrapperDtsNamespace,
        {"moduleName": moduleName, "functions": functions},
      )
      {"importBlock": importBlock, "namespace": namespace}
    })

  Handlebars.render(Templates.wrapperDts, {"tags": tagData})
}

let generate = (~endpoints, ~outputDir, ~generatedModulePath="../generated") => {
  Pipeline.fromFilesAndWarnings(
    [
      {
        FileSystem.path: FileSystem.makePath(outputDir, "wrapper/index.mjs"),
        content: generateWrapperMjs(~endpoints, ~generatedModulePath),
      },
      {
        path: FileSystem.makePath(outputDir, "wrapper/index.d.ts"),
        content: generateWrapperDts(~endpoints),
      },
    ],
    [],
  )
}