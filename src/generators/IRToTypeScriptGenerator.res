// SPDX-License-Identifier: MPL-2.0

// IRToTypeScriptGenerator.res - Convert SchemaIR to TypeScript types

let rec generateType = (~irType: SchemaIR.irType, ~isOptional=false) =>
  switch irType {
  | String(_) => "string"
  | Number(_)
  | Integer(_) => "number"
  | Boolean => "boolean"
  | Null => "null"
  | Unknown => "unknown"
  | Array({items}) => `${generateType(~irType=items)}[]`
  | Object({properties, additionalProperties}) =>
    generateObjectType(~properties, ~additionalProperties)
  | Literal(literal) =>
    switch literal {
    | StringLiteral(s) => `"${s}"`
    | NumberLiteral(n) => Float.toString(n)
    | BooleanLiteral(b) => b ? "true" : "false"
    | NullLiteral => "null"
    }
  | Union(types) => types->Array.map(t => generateType(~irType=t))->Array.join(" | ")
  | Intersection(types) => types->Array.map(t => generateType(~irType=t))->Array.join(" & ")
  | Reference(ref) =>
    switch String.split(ref, "/") {
    | [_, "components", "schemas", name] => `ComponentSchemas.${name}`
    | _ => ref
    }
  | Option(inner) =>
    isOptional ? generateType(~irType=inner, ~isOptional=true) : `${generateType(~irType=inner)} | undefined`
  }

and generateObjectType = (~properties, ~additionalProperties) => {
  let propertyLines = properties->Array.map(((name, fieldType, isRequired)) => {
    let (actualType, isFieldOptional) = switch fieldType {
    | SchemaIR.Option(inner) => (inner, true)
    | _ => (fieldType, !isRequired)
    }
    `  ${name}${isFieldOptional ? "?" : ""}: ${generateType(~irType=actualType, ~isOptional=true)};`
  })

  let additionalPropertiesLines =
    additionalProperties->Option.mapOr([], valueType => [
      `  [key: string]: ${generateType(~irType=valueType)};`,
    ])

  let allLines = Array.concat(propertyLines, additionalPropertiesLines)

  if allLines->Array.length == 0 {
    "Record<string, never>"
  } else {
    `{\n${allLines->Array.join("\n")}\n}`
  }
}

let generateNamedType = (~namedSchema: SchemaIR.namedSchema) => {
  let docComment = namedSchema.description->Option.mapOr("", description => `/** ${description} */\n`)
  let typeCode = generateType(~irType=namedSchema.type_)

  let declaration = switch namedSchema.type_ {
  | Object(_) => `export interface ${namedSchema.name} ${typeCode}`
  | _ => `export type ${namedSchema.name} = ${typeCode};`
  }

  docComment ++ declaration
}

let generateParameterType = (~name, ~schema: Types.jsonSchema) => {
  let (ir, _) = SchemaIRParser.parseJsonSchema(schema)
  (CodegenUtils.toCamelCase(name), generateType(~irType=ir))
}
