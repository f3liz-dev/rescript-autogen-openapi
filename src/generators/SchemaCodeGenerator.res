// SPDX-License-Identifier: MPL-2.0

// SchemaCodeGenerator.res - Generate complete Sury schema code with types

let generateTypeCodeAndSchemaCode = (name, schema: Types.jsonSchema) => {
  let (ir, _) = SchemaIRParser.parseJsonSchema(schema)
  let (typeCode, _, extractedTypes) = IRToTypeGenerator.generateNamedType(
    ~namedSchema={name: name, description: schema.description, type_: ir},
  )
  let (schemaCode, _) = IRToSuryGenerator.generateNamedSchema(
    ~namedSchema={name: `${name}Schema`, description: schema.description, type_: ir},
    ~extractedTypes,
  )
  `${typeCode}\n\n${schemaCode}`
}

let generateTypeAndSchema = (name, schema) => generateTypeCodeAndSchemaCode(name, schema)

let generateComponentSchemas = (components: option<Types.components>) =>
  components
  ->Option.flatMap(c => c.schemas)
  ->Option.mapOr("// No component schemas\n", schemas => {
    let sections =
      schemas
      ->Dict.toArray
      ->Array.map(((name, schema)) => generateTypeCodeAndSchemaCode(name, schema))
      ->Array.join("\n\n")
    `// Component Schemas\n\n${sections}`
  })

let generateOperationSchemas = (operationId, operation: Types.operation) => {
  let generatePart = (suffix, schemaOpt) =>
    schemaOpt->Option.mapOr("", schema =>
      generateTypeCodeAndSchemaCode(`${CodegenUtils.toPascalCase(operationId)}${suffix}`, schema)
    )

  let requestBodySchema =
    operation.requestBody
    ->Option.flatMap(body => body.content->Dict.get("application/json"))
    ->Option.flatMap(mediaType => mediaType.schema)

  let successResponseSchema =
    operation.responses
    ->(
      responses =>
        Dict.get(responses, "200")->Option.orElse(Dict.get(responses, "201"))
    )
    ->Option.flatMap(response => response.content)
    ->Option.flatMap(content => content->Dict.get("application/json"))
    ->Option.flatMap(mediaType => mediaType.schema)

  [
    generatePart("Request", requestBodySchema),
    generatePart("Response", successResponseSchema),
  ]
  ->Array.filter(code => code != "")
  ->Array.join("\n\n")
}

let generateEndpointModule = (path, method, operation: Types.operation) => {
  let operationId = OpenAPIParser.getOperationId(path, method, operation)
  let docComment = CodegenUtils.generateDocComment(
    ~summary=?operation.summary,
    ~description=?operation.description,
    (),
  )
  let methodStr = switch method {
  | #GET => "GET"
  | #POST => "POST"
  | #PUT => "PUT"
  | #PATCH => "PATCH"
  | #DELETE => "DELETE"
  | #HEAD => "HEAD"
  | #OPTIONS => "OPTIONS"
  }
  let schemasCode = generateOperationSchemas(operationId, operation)

  `${docComment}module ${CodegenUtils.toPascalCase(operationId)} = {
${schemasCode->CodegenUtils.indent(2)}

  let endpoint = "${path}"
  let method = #${methodStr}
}`
}
