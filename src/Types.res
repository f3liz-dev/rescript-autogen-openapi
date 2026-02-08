// SPDX-License-Identifier: MPL-2.0

// Types.res - Core OpenAPI and generation types (refactored & compact)

// ============= JSON Schema Types =============
@genType
type rec jsonSchemaType =
  | String
  | Number
  | Integer
  | Boolean
  | Array(jsonSchemaType)
  | Object
  | Null
  | Unknown

@genType
and jsonSchema = {
  @as("type") type_: option<jsonSchemaType>,
  properties: option<dict<jsonSchema>>,
  items: option<jsonSchema>,
  required: option<array<string>>,
  enum: option<array<JSON.t>>,
  @as("$ref") ref: option<string>,
  allOf: option<array<jsonSchema>>,
  oneOf: option<array<jsonSchema>>,
  anyOf: option<array<jsonSchema>>,
  description: option<string>,
  format: option<string>,
  minLength: option<int>,
  maxLength: option<int>,
  minimum: option<float>,
  maximum: option<float>,
  pattern: option<string>,
  nullable: option<bool>,
}

// ============= OpenAPI 3.1 Types =============
@genType
type httpMethod = [#GET | #POST | #PUT | #PATCH | #DELETE | #HEAD | #OPTIONS]

@genType
type mediaType = {
  schema: option<jsonSchema>,
  example: option<JSON.t>,
  examples: option<dict<JSON.t>>,
}

@genType
type requestBody = {
  description: option<string>,
  content: dict<mediaType>,
  required: option<bool>,
}

@genType
type response = {
  description: string,
  content: option<dict<mediaType>>,
}

@genType
type parameter = {
  name: string,
  @as("in") in_: string,
  description: option<string>,
  required: option<bool>,
  schema: option<jsonSchema>,
}

@genType
type operation = {
  operationId: option<string>,
  summary: option<string>,
  description: option<string>,
  tags: option<array<string>>,
  requestBody: option<requestBody>,
  responses: dict<response>,
  parameters: option<array<parameter>>,
}

@genType
type endpoint = {
  path: string,
  method: string,
  operationId: option<string>,
  summary: option<string>,
  description: option<string>,
  tags: option<array<string>>,
  requestBody: option<requestBody>,
  responses: dict<response>,
  parameters: option<array<parameter>>,
}

@genType
type pathItem = {
  get: option<operation>,
  post: option<operation>,
  put: option<operation>,
  patch: option<operation>,
  delete: option<operation>,
  head: option<operation>,
  options: option<operation>,
  parameters: option<array<parameter>>,
}

@genType
type components = {schemas: option<dict<jsonSchema>>}

@genType
type info = {
  title: string,
  version: string,
  description: option<string>,
}

@genType
type openAPISpec = {
  openapi: string,
  info: info,
  paths: dict<pathItem>,
  components: option<components>,
}

// ============= Re-exports from focused modules =============
// Config types
@genType
type generationStrategy = Config.generationStrategy =
  | Separate
  | SharedBase

@genType
type breakingChangeHandling = Config.breakingChangeHandling = | Error | Warn | Ignore
@genType
type forkSpecConfig = Config.forkSpecConfig = {name: string, specPath: string}
@genType
type generationTargets = Config.generationTargets = {
  rescriptApi: bool,
  rescriptWrapper: bool,
  typescriptDts: bool,
  typescriptWrapper: bool,
}
@genType
type generationConfig = Config.t

@genType
type forkSpec = {
  name: string,
  spec: openAPISpec,
}

// Error types - use `=` syntax to re-export constructors
@genType
type errorContext = CodegenError.context = {
  path: string,
  operation: string,
  schema: option<JSON.t>,
}

@genType
type codegenError = CodegenError.t =
  | SpecResolutionError({url: string, message: string})
  | SchemaParseError({context: errorContext, reason: string})
  | ReferenceError({ref: string, context: errorContext})
  | ValidationError({schema: string, input: JSON.t, issues: array<string>})
  | CircularSchemaError({ref: string, depth: int, path: string})
  | FileWriteError({filePath: string, message: string})
  | InvalidConfigError({field: string, message: string})
  | UnknownError({message: string, context: option<errorContext>})

@genType
type warning = CodegenError.Warning.t =
  | FallbackToJson({reason: string, context: errorContext})
  | UnsupportedFeature({feature: string, fallback: string, location: string})
  | DepthLimitReached({depth: int, path: string})
  | MissingSchema({ref: string, location: string})
  | IntersectionNotFullySupported({location: string, note: string})
  | ComplexUnionSimplified({location: string, types: string})

// ============= Diff Types =============
@genType
type endpointDiff = {
  path: string,
  method: string,
  requestBodyChanged: bool,
  responseChanged: bool,
  breakingChange: bool,
}

@genType
type schemaDiff = {
  name: string,
  breakingChange: bool,
}

@genType
type specDiff = {
  addedEndpoints: array<endpoint>,
  removedEndpoints: array<endpoint>,
  modifiedEndpoints: array<endpointDiff>,
  addedSchemas: array<string>,
  removedSchemas: array<string>,
  modifiedSchemas: array<schemaDiff>,
}

// ============= Generation Result Types =============
@genType
type generationSuccess = {
  generatedFiles: array<string>,
  diff: option<specDiff>,
  warnings: array<warning>,
}

@genType
type generationResult = result<generationSuccess, codegenError>

// ============= Re-export helper modules =============
module CodegenError = CodegenError

module Warning = {
  include CodegenError.Warning
}
