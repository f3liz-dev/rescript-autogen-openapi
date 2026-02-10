// SPDX-License-Identifier: MPL-2.0

// Handlebars.res - Minimal Handlebars binding via %raw

@module("module") external createRequire: string => string => 'a = "createRequire"
@val @scope("import.meta") external importMetaUrl: string = "url"

let _require = createRequire(importMetaUrl)

// Internal: render with untyped data (JSON.t used as universal type at boundary)
let _render: (string, JSON.t) => string = {
  let handlebars: 'a = _require("handlebars")
  let convert: 'a = _require("js-convert-case")

  %raw(`
    (function(Handlebars, convert) {
      var instance = Handlebars.create();

      instance.registerHelper('indent', function(content, level) {
        if (typeof content !== 'string') return '';
        var spaces = '  '.repeat(typeof level === 'number' ? level : 1);
        return content.split('\n').map(function(line) {
          return line.trim() === '' ? '' : spaces + line;
        }).join('\n');
      });
      instance.registerHelper('pascalCase', function(s) { return typeof s === 'string' ? convert.toPascalCase(s) : ''; });
      instance.registerHelper('camelCase', function(s) { return typeof s === 'string' ? convert.toCamelCase(s) : ''; });
      instance.registerHelper('upperCase', function(s) { return typeof s === 'string' ? s.toUpperCase() : ''; });
      instance.registerHelper('eq', function(a, b) { return a === b; });
      instance.registerHelper('ne', function(a, b) { return a !== b; });

      var cache = {};
      return function render(template, data) {
        if (!cache[template]) cache[template] = instance.compile(template, { noEscape: true });
        return cache[template](data);
      };
    })
  `)(handlebars, convert)
}

// Public render: accepts any ReScript record/object via Obj.magic
let render = (template: string, data: 'a): string =>
  _render(template, Obj.magic(data))
