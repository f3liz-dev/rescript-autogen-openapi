// SPDX-License-Identifier: MPL-2.0

// SchemaRefResolver.res - Bindings to @readme/openapi-parser

// Parser options type
type parserOptions = {
  timeoutMs?: int,
}

// External bindings to @readme/openapi-parser v5.x
@module("@readme/openapi-parser")
external parse: (string, ~options: parserOptions=?) => promise<JSON.t> = "parse"

@module("@readme/openapi-parser")
external bundle: (string, ~options: parserOptions=?) => promise<JSON.t> = "bundle"

@module("@readme/openapi-parser")
external dereference: (string, ~options: parserOptions=?) => promise<JSON.t> = "dereference"

@module("@readme/openapi-parser")
external validate: (string, ~options: parserOptions=?) => promise<JSON.t> = "validate"

// Helper to convert JSON to OpenAPISpec
let jsonToSpec = (json: JSON.t): result<Types.openAPISpec, string> => {
  switch json->JSON.Decode.object {
  | Some(obj) => {
      // Convert to our OpenAPISpec type
      let pathsDict = obj
        ->Dict.get("paths")
        ->Option.flatMap(JSON.Decode.object)
        ->Option.getOr(Dict.make())
      
      let openAPISpec: Types.openAPISpec = {
        openapi: obj
          ->Dict.get("openapi")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("3.1.0"),
        info: {
          let infoObj = obj
            ->Dict.get("info")
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())
          {
            title: infoObj
              ->Dict.get("title")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("Untitled API"),
            version: infoObj
              ->Dict.get("version")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("0.0.0"),
            description: infoObj
              ->Dict.get("description")
              ->Option.flatMap(JSON.Decode.string),
          }
        },
        paths: pathsDict
          ->Dict.toArray
          ->Array.map(((key, _value)) => (key, Obj.magic(_value)))
          ->Dict.fromArray,
        components: obj
          ->Dict.get("components")
          ->Option.map(_comp => ({
            schemas: _comp
              ->JSON.Decode.object
              ->Option.flatMap(c => c->Dict.get("schemas"))
              ->Option.flatMap(JSON.Decode.object)
              ->Option.map(schemas => 
                schemas
                ->Dict.toArray
                ->Array.map(((key, value)) => (key, Obj.magic(value)))
                ->Dict.fromArray
              ),
          }: Types.components)),
      }
      
      Ok(openAPISpec)
    }
  | None => Error("Invalid OpenAPI spec: root is not an object")
  }
}

// Resolve a spec from source
let resolve = async (source: string, ~timeout: option<int>=?): result<Types.openAPISpec, string> => {
  try {
    // Use bundle to combine all external refs while keeping internal $refs intact
    let options = {timeoutMs: timeout->Option.getOr(60000)}
    let resolved = await bundle(source, ~options)
    
    jsonToSpec(resolved)
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Option.getOr("Unknown error resolving spec")
      Error(`Failed to resolve spec: ${message}`)
    }
  | _ => Error("Unknown error resolving spec")
  }
}

// Parse an OpenAPI spec without dereferencing
let parseOnly = async (source: string, ~timeout: option<int>=?): result<Types.openAPISpec, string> => {
  try {
    let options = {timeoutMs: timeout->Option.getOr(60000)}
    let parsed = await parse(source, ~options)
    jsonToSpec(parsed)
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Option.getOr("Unknown error parsing spec")
      Error(`Failed to parse spec: ${message}`)
    }
  | _ => Error("Unknown error parsing spec")
  }
}

// Bundle an OpenAPI spec (combines all external references into a single file)
let bundleSpec = async (source: string, ~timeout: option<int>=?): result<JSON.t, string> => {
  try {
    let options = {timeoutMs: timeout->Option.getOr(60000)}
    let bundled = await bundle(source, ~options)
    Ok(bundled)
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Option.getOr("Unknown error bundling spec")
      Error(`Failed to bundle spec: ${message}`)
    }
  | _ => Error("Unknown error bundling spec")
  }
}

// Validate an OpenAPI spec
let validateSpec = async (source: string, ~timeout: option<int>=?): result<Types.openAPISpec, string> => {
  try {
    let options = {timeoutMs: timeout->Option.getOr(60000)}
    let validated = await validate(source, ~options)
    jsonToSpec(validated)
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Option.getOr("Unknown error validating spec")
      Error(`Failed to validate spec: ${message}`)
    }
  | _ => Error("Unknown error validating spec")
  }
}
