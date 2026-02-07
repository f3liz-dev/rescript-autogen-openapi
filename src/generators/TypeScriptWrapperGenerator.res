// SPDX-License-Identifier: MPL-2.0

// TypeScriptWrapperGenerator.res - Generate TypeScript/JavaScript wrapper
open Types

let misskeyClientJsCode = `
  |export class MisskeyClient {
  |  constructor(baseUrl, token) {
  |    this.baseUrl = baseUrl;
  |    this.token = token;
  |  }
  |
  |  async _fetch(url, method, body) {
  |    const headers = { 'Content-Type': 'application/json' };
  |    if (this.token) {
  |      headers['Authorization'] = \`Bearer \${this.token}\`;
  |    }
  |    const response = await fetch(this.baseUrl + url, {
  |      method,
  |      headers,
  |      body: body ? JSON.stringify(body) : undefined,
  |    });
  |    return response.json();
  |  }
  |}`->CodegenUtils.trimMargin

let generateWrapperMjs = (~endpoints, ~generatedModulePath) => {
  let endpointsByTag = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(endpointsByTag)

  let imports =
    tags
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
      `import * as ${moduleName} from '${generatedModulePath}/${moduleName}.mjs';`
    })
    ->Array.join("\n")

  let wrappers =
    tags
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
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
          let bodyArg = hasRequestBody ? "body: request, " : ""
          `
            |  async ${functionName}(client${hasRequestBody ? ", request" : ""}) {
            |    return ${moduleName}.${functionName}({
            |      ${bodyArg}fetch: (url, method, body) => client._fetch(url, method, body)
            |    });
            |  },`
        })
        ->Array.join("\n")
      `
        |export const ${moduleName} = {
        |${methods}
        |};`
    })
    ->Array.join("\n\n")

  `
    |// Generated wrapper
    |${imports}
    |
    |${misskeyClientJsCode}
    |
    |${wrappers}
    |`->CodegenUtils.trimMargin
}

let generateWrapperDts = (~endpoints) => {
  let endpointsByTag = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(endpointsByTag)

  let imports =
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
      `import type {
${typesToImport}
} from '../types/${moduleName}.d.ts';`
    })
    ->Array.join("\n")

  let namespaces =
    tags
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
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
          let docComment = endpoint.summary->Option.mapOr("", summary => {
            let descriptionPart = endpoint.description->Option.mapOr("", description =>
              description == summary ? "" : " - " ++ description
            )
            `  /** ${summary}${descriptionPart} */\n`
          })
          let requestParam = endpoint.requestBody->Option.isSome ? `, request: ${pascalName}Request` : ""
          `${docComment}  export function ${functionName}(client: MisskeyClient${requestParam}): Promise<${pascalName}Response>;`
        })
        ->Array.join("\n")
      `
        |export namespace ${moduleName} {
        |${functions}
        |}`
    })
    ->Array.join("\n\n")

  `
    |// Generated TypeScript definitions for wrapper
    |${imports}
    |
    |export class MisskeyClient {
    |  constructor(baseUrl: string, token?: string);
    |  readonly baseUrl: string;
    |  readonly token?: string;
    |}
    |
    |${namespaces}
    |`->CodegenUtils.trimMargin
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