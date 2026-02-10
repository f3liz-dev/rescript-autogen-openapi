// SPDX-License-Identifier: MPL-2.0

// CodegenUtils.res - Utility functions for code generation

// Convert a string to PascalCase
@module("js-convert-case") external toPascalCase: string => string = "toPascalCase"

// Convert a string to camelCase
@module("js-convert-case") external toCamelCase: string => string = "toCamelCase"

// Sanitize identifier (remove special characters, ensure valid ReScript identifier)
let sanitizeIdentifier = (str: string): string =>
  str
  ->String.replaceAll("{", "")->String.replaceAll("}", "")
  ->String.replaceAll("[", "")->String.replaceAll("]", "")
  ->String.replaceAll(".", "_")->String.replaceAll("-", "_")
  ->String.replaceAll("/", "_")->String.replaceAll(" ", "_")

// Generate type name from path and method
let generateTypeName = (~prefix="", path: string, suffix: string): string => {
  let cleaned = path
    ->String.replaceAll("/", "_")
    ->sanitizeIdentifier
    ->String.split("_")
    ->Array.filter(part => part != "")
    ->Array.map(toPascalCase)
    ->Array.join("")
  
  prefix ++ cleaned ++ suffix
}

// Generate operation name from operationId or path + method
let generateOperationName = (operationId: option<string>, path: string, method: string): string =>
  switch operationId {
  | Some(id) => toCamelCase(sanitizeIdentifier(id))
  | None =>
      method->String.toLowerCase ++ path
        ->String.split("/")
        ->Array.filter(part => part != "" && !(part->String.startsWith("{")))
        ->Array.map(toCamelCase)
        ->Array.join("")
  }

// Escape ReScript string
let escapeString = (str: string): string =>
  str
  ->String.replaceAll("\\", "\\\\")->String.replaceAll("\"", "\\\"")
  ->String.replaceAll("\n", "\\n")->String.replaceAll("\r", "\\r")
  ->String.replaceAll("\t", "\\t")

// Escape Regex Pattern for ReScript 12 regex literals
// With /.../ syntax, forward slashes don't need escaping inside character classes
// Only fix hyphen placement in character classes for clarity
let escapeRegexPattern = (str: string): string => {
  // Move escaped hyphens (\-) to the end of character classes for clarity
  %raw(`
    function(s) {
      return s.replace(/\[([^\]]+)\]/g, function(match) {
        let content = match.slice(1, -1);
        let chars = [];
        let hyphenCount = 0;
        let i = 0;
        
        while (i < content.length) {
          if (content[i] === '\\\\' && i + 1 < content.length) {
            if (content[i + 1] === '-') {
              // Escaped hyphen - count it and skip
              hyphenCount++;
              i += 2;
            } else {
              // Other escaped char - keep as is
              chars.push(content[i]);
              chars.push(content[i + 1]);
              i += 2;
            }
          } else if (content[i] === '-' && i > 0 && i < content.length - 1) {
            // Check if this hyphen is part of a valid range
            let prevChar = chars[chars.length - 1];
            let nextChar = content[i + 1];
            // If previous char is a backslash, this can't be a range
            if (chars.length >= 2 && chars[chars.length - 2] === '\\\\') {
              // Previous was escaped, so this hyphen is literal
              hyphenCount++;
              i++;
            } else if (nextChar === '\\\\') {
              // Next is escape sequence, hyphen is literal
              hyphenCount++;
              i++;
            } else if (prevChar && nextChar && prevChar.charCodeAt(0) < nextChar.charCodeAt(0)) {
              // Valid range (e.g., a-z), keep the hyphen
              chars.push('-');
              i++;
            } else {
              // Invalid or ambiguous, move to end
              hyphenCount++;
              i++;
            }
          } else {
            // Regular character or hyphen at start/end
            chars.push(content[i]);
            i++;
          }
        }
        
        // Add collected hyphens at the end
        let result = chars.join('');
        if (hyphenCount > 0) {
          result += '-'.repeat(hyphenCount);
        }
        return '[' + result + ']';
      });
    }
  `)(str)
}

// Generate file header
let generateFileHeader = (~description: string): string =>
  Handlebars.render(Templates.fileHeader, {"description": description})

// Indent code
let indent = (code: string, level: int): string => {
  let spaces = "  "->String.repeat(level)
  code
  ->String.split("\n")
  ->Array.map(line => line->String.trim == "" ? "" : spaces ++ line)
  ->Array.join("\n")
}

// ReScript keywords that need to be escaped
let rescriptKeywords = [
  "and", "as", "assert", "async", "await", "catch", "class", "constraint",
  "do", "done", "downto", "else", "end", "exception", "external", "false",
  "for", "fun", "function", "functor", "if", "in", "include", "inherit",
  "initializer", "lazy", "let", "method", "module", "mutable", "new",
  "nonrec", "object", "of", "open", "or", "private", "rec", "sig", "struct",
  "switch", "then", "to", "true", "try", "type", "val", "virtual", "when",
  "while", "with"
]

// Escape ReScript keywords by adding underscore suffix
let escapeKeyword = (name: string): string => rescriptKeywords->Array.includes(name) ? name ++ "_" : name

// Generate documentation comment (single-line comments)
let generateDocComment = (~summary=?, ~description=?, ()): string =>
  Handlebars.render(
    Templates.docComment,
    {"summary": summary->Null.fromOption, "description": description->Null.fromOption},
  )

// Generate DocString comment (multi-line /** ... */ format) from markdown
let generateDocString = (~summary=?, ~description=?, ()): string => {
  let content = switch (summary, description) {
  | (None, None) => None
  | (Some(s), None) => Some(s)
  | (None, Some(d)) => Some(d)
  | (Some(s), Some(d)) => Some(s == d ? s : s ++ "\n\n" ++ d)
  }
  
  content->Option.map(text => {
    let lines = text->String.trim->String.split("\n")->Array.map(String.trim)
    switch lines {
    | [] => ""
    | [line] =>
      Handlebars.render(Templates.docCommentSingle, {"content": line})
    | lines =>
      Handlebars.render(Templates.docCommentMulti, {"lines": lines})
    }
  })->Option.getOr("")
}

// Shared type signature for the fetch function used in generated code
let fetchTypeSignature = "(~url: string, ~method_: string, ~body: option<JSON.t>) => Promise.t<JSON.t>"

// Generate variant constructor name from an IR type
let rec variantConstructorName = (irType: SchemaIR.irType): string => {
  switch irType {
  | String(_) => "String"
  | Number(_) => "Float"
  | Integer(_) => "Int"
  | Boolean => "Bool"
  | Null => "Null"
  | Array(_) => "Array"
  | Object(_) => "Object"
  | Reference(ref) =>
    let name = if ref->String.includes("/") {
      ref->String.split("/")->Array.get(ref->String.split("/")->Array.length - 1)->Option.getOr("Ref")
    } else {
      ref
    }
    toPascalCase(name)
  | Literal(StringLiteral(s)) => toPascalCase(s)
  | Literal(NumberLiteral(_)) => "Number"
  | Literal(BooleanLiteral(_)) => "Bool"
  | Literal(NullLiteral) => "Null"
  | Option(inner) => variantConstructorName(inner)
  | Intersection(_) => "Intersection"
  | Union(_) => "Union"
  | Unknown => "Unknown"
  }
}

// Deduplicate variant constructor names by appending counter suffix
let deduplicateNames = (names: array<string>): array<string> => {
  let counts: Dict.t<int> = Dict.make()
  let result: array<string> = []
  names->Array.forEach(name => {
    let count = counts->Dict.get(name)->Option.getOr(0)
    counts->Dict.set(name, count + 1)
  })
  let seen: Dict.t<int> = Dict.make()
  names->Array.forEach(name => {
    let total = counts->Dict.get(name)->Option.getOr(1)
    if total > 1 {
      let idx = seen->Dict.get(name)->Option.getOr(0) + 1
      seen->Dict.set(name, idx)
      result->Array.push(`${name}${Int.toString(idx)}`)
    } else {
      result->Array.push(name)
    }
  })
  result
}
