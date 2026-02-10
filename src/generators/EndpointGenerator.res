// SPDX-License-Identifier: MPL-2.0

// EndpointGenerator.res - Generate API endpoint functions
open Types

let getJsonSchemaFromRequestBody = (requestBody: option<requestBody>) =>
  requestBody->Option.flatMap(body =>
    Dict.toArray(body.content)->Array.get(0)->Option.flatMap(((_contentType, mediaType)) => mediaType.schema)
  )

let generateTypeCodeAndSchemaCode = (~jsonSchema, ~typeName, ~schemaName, ~modulePrefix="") => {
  let (ir, _) = SchemaIRParser.parseJsonSchema(jsonSchema)
  let (typeCode, _, extractedTypes) = IRToTypeGenerator.generateNamedType(
    ~namedSchema={name: typeName, description: jsonSchema.description, type_: ir},
    ~modulePrefix,
  )
  let (schemaCode, _) = IRToSuryGenerator.generateNamedSchema(
    ~namedSchema={name: schemaName, description: jsonSchema.description, type_: ir},
    ~modulePrefix,
    ~extractedTypes,
  )
  (typeCode, schemaCode)
}

let generateEndpointFunction = (endpoint: endpoint, ~overrideDir=?, ~moduleName=?) => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let requestTypeName = `${functionName}Request`
  let hasRequestBody = endpoint.requestBody->Option.isSome
  let requestBody = endpoint.requestBody->Option.getOr({
    content: Dict.make(),
    description: None,
    required: Some(false),
  })
  let isRequestBodyRequired = requestBody.required->Option.getOr(false)
  
  let bodyParam = hasRequestBody
    ? (isRequestBodyRequired ? `~body: ${requestTypeName}` : `~body: option<${requestTypeName}>=?`)
    : ""
  
  // Clean up function signature: handle comma between body and fetch params
  let paramSep = hasRequestBody ? ", " : ""
  
  let bodyValueConversion = hasRequestBody
    ? (
        isRequestBodyRequired
          ? `  let jsonBody = body->S.reverseConvertToJsonOrThrow(${functionName}RequestSchema)`
          : `  let jsonBody = body->Option.map(b => b->S.reverseConvertToJsonOrThrow(${functionName}RequestSchema))`
      )
    : ""
  
  let successResponse = ["200", "201", "202", "204"]
    ->Array.filterMap(code => Dict.get(endpoint.responses, code))
    ->Array.get(0)
    
  let responseHandling = successResponse->Option.mapOr("  response", response =>
    response.content->Option.mapOr("  let _ = response\n  ()", content =>
      Dict.toArray(content)->Array.length > 0
        ? `  let value = response->S.parseOrThrow(${functionName}ResponseSchema)\n  value`
        : "  response"
    )
  )

  let description = switch (overrideDir, moduleName) {
  | (Some(dir), Some(mName)) =>
    DocOverride.readOverrideWithValidation(
      dir,
      mName,
      functionName,
      DocOverride.generateEndpointHash(endpoint),
    )->(
      overrideResult =>
        switch overrideResult {
        | DocOverride.ValidOverride(v)
        | DocOverride.InvalidHash({override: v}) =>
          Some(v)
        | _ => endpoint.description
        }
    )
  | _ => endpoint.description
  }
  
  let docComment = CodegenUtils.generateDocString(
    ~summary=?endpoint.summary,
    ~description=?description,
    (),
  )
  
  let code = Handlebars.render(
    Templates.endpointFunction,
    {
      "docComment": docComment,
      "functionName": functionName,
      "bodyParam": bodyParam,
      "paramSep": paramSep,
      "fetchTypeSignature": CodegenUtils.fetchTypeSignature,
      "bodyValueConversion": bodyValueConversion,
      "path": endpoint.path,
      "methodUpper": endpoint.method->String.toUpperCase,
      "bodyArg": hasRequestBody ? "Some(jsonBody)" : "None",
      "responseHandling": responseHandling,
    },
  )
  
  code
}

let generateEndpointCode = (endpoint, ~overrideDir=?, ~moduleName=?, ~modulePrefix="") => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  
  let requestJsonSchema = getJsonSchemaFromRequestBody(endpoint.requestBody)
  
  let responseJsonSchema = ["200", "201", "202", "204"]
    ->Array.filterMap(code => Dict.get(endpoint.responses, code))
    ->Array.get(0)
    ->Option.flatMap(resp => resp.content)
    ->Option.flatMap(content =>
      Dict.toArray(content)->Array.get(0)->Option.flatMap(((_contentType, mediaType)) => mediaType.schema)
    )
  
  let requestPart = requestJsonSchema->Option.mapOr("", schema => {
    let (typeCode, schemaCode) = generateTypeCodeAndSchemaCode(
      ~jsonSchema=schema,
      ~typeName=`${functionName}Request`,
      ~schemaName=`${functionName}Request`,
      ~modulePrefix,
    )
    `${typeCode}\n\n${schemaCode}`
  })
  
  let responsePart = responseJsonSchema->Option.mapOr(`type ${functionName}Response = unit`, schema => {
    let (typeCode, schemaCode) = generateTypeCodeAndSchemaCode(
      ~jsonSchema=schema,
      ~typeName=`${functionName}Response`,
      ~schemaName=`${functionName}Response`,
      ~modulePrefix,
    )
    `${typeCode}\n\n${schemaCode}`
  })
  
  [requestPart, responsePart, generateEndpointFunction(endpoint, ~overrideDir?, ~moduleName?)]
  ->Array.filter(s => s != "")
  ->Array.join("\n\n")
}

let generateEndpointModule = (~endpoint, ~modulePrefix="") => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let header = CodegenUtils.generateFileHeader(~description=endpoint.summary->Option.getOr(`API: ${endpoint.path}`))
  Handlebars.render(
    Templates.moduleWrapped,
    {
      "header": header->String.trimEnd,
      "moduleName": CodegenUtils.toPascalCase(functionName),
      "body": generateEndpointCode(endpoint, ~modulePrefix)->CodegenUtils.indent(2),
    },
  )
}

let generateEndpointsModule = (~moduleName, ~endpoints, ~description=?, ~overrideDir=?, ~modulePrefix="") => {
  let header = CodegenUtils.generateFileHeader(~description=description->Option.getOr(`API for ${moduleName}`))
  let body =
    endpoints
    ->Array.map(ep => generateEndpointCode(ep, ~overrideDir?, ~moduleName, ~modulePrefix)->CodegenUtils.indent(2))
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

let generateEndpointSignature = (endpoint) => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let summaryPrefix = endpoint.summary->Option.mapOr("", s => `// ${s}\n`)
  let bodyParam = endpoint.requestBody->Option.isSome ? "~body: 'body, " : ""
  `${summaryPrefix}let ${functionName}: (${bodyParam}~fetch: fetchFn) => promise<${functionName}Response>`
}
