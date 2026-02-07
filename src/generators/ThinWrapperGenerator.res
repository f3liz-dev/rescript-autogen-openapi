// SPDX-License-Identifier: MPL-2.0

// ThinWrapperGenerator.res - Generate ReScript thin wrappers with pipe-first ergonomics
open Types

let clientTypeCode = `
  |type client = {
  |  baseUrl: string,
  |  token: option<string>,
  |  fetch: ${CodegenUtils.fetchTypeSignature},
  |}
  |`->CodegenUtils.trimMargin

let generateConnectFunction = (title) =>
  `
    |/** Create a client for ${title} */
    |let connect = (~baseUrl: string, ~token: option<string>=?, ~fetch: ${CodegenUtils.fetchTypeSignature}, ()): client => {
    |  baseUrl,
    |  token,
    |  fetch,
    |}
    |`->CodegenUtils.trimMargin

let generateWrapperFunction = (~endpoint: endpoint, ~generatedModuleName: string) => {
  let operationName = CodegenUtils.generateOperationName(
    endpoint.operationId,
    endpoint.path,
    endpoint.method,
  )
  let hasRequestBody = endpoint.requestBody->Option.isSome
  let docComment = endpoint.summary->Option.mapOr("", summary => {
    let descriptionPart = endpoint.description->Option.mapOr("", description =>
      description == summary ? "" : " - " ++ description
    )
    `  /** ${summary}${descriptionPart} */\n`
  })

  let signature = hasRequestBody
    ? `let ${operationName} = (request: ${generatedModuleName}.${operationName}Request, ~client: client)`
    : `let ${operationName} = (~client: client)`

  let callArguments = hasRequestBody ? "~body=request, " : ""

  `${docComment}  ${signature}: promise<${generatedModuleName}.${operationName}Response> => 
    ${generatedModuleName}.${operationName}(${callArguments}~fetch=client.fetch)`
}

let generateWrapper = (
  ~spec: openAPISpec,
  ~endpoints,
  ~extensionEndpoints=[],
  ~outputDir,
  ~wrapperModuleName="Wrapper",
  ~generatedModulePrefix="",
  ~baseModulePrefix="",
) => {
  let extensionOperationIds =
    extensionEndpoints->Array.reduce(Dict.make(), (acc, endpoint) => {
      let name = CodegenUtils.generateOperationName(
        endpoint.operationId,
        endpoint.path,
        endpoint.method,
      )
      Dict.set(acc, name, true)
      acc
    })

  let hasExtensions = Array.length(extensionEndpoints) > 0

  let allEndpoints = Array.concat(
    hasExtensions
      ? endpoints->Array.filter(endpoint => {
          let name = CodegenUtils.generateOperationName(
            endpoint.operationId,
            endpoint.path,
            endpoint.method,
          )
          !Dict.has(extensionOperationIds, name)
        })
      : endpoints,
    extensionEndpoints,
  )

  let endpointsByTag = OpenAPIParser.groupByTag(allEndpoints)

  let modulesCode =
    Dict.keysToArray(endpointsByTag)
    ->Array.map(tag => {
      let moduleName = CodegenUtils.toPascalCase(tag)
      let wrapperFunctions =
        Dict.get(endpointsByTag, tag)
        ->Option.getOr([])
        ->Array.map(endpoint => {
          let operationName = CodegenUtils.generateOperationName(
            endpoint.operationId,
            endpoint.path,
            endpoint.method,
          )
          let isExtension = hasExtensions && Dict.has(extensionOperationIds, operationName)
          let prefix =
            (!isExtension && baseModulePrefix != "") ? baseModulePrefix : generatedModulePrefix

          let targetModuleName = prefix != "" ? `${prefix}${moduleName}` : moduleName
          generateWrapperFunction(~endpoint, ~generatedModuleName=targetModuleName)
        })
        ->Array.join("\n\n")

      `module ${moduleName} = {\n${wrapperFunctions}\n}`
    })
    ->Array.join("\n\n")

  let fileContent = `// Generated thin wrapper

${clientTypeCode}

${generateConnectFunction(spec.info.title)}

${modulesCode}`

  Pipeline.fromFilesAndWarnings(
    [{path: FileSystem.makePath(outputDir, `${wrapperModuleName}.res`), content: fileContent}],
    [],
  )
}