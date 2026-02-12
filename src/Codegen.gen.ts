/* TypeScript file generated from Codegen.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as CodegenJS from './Codegen.mjs';

import type {codegenError as Types_codegenError} from './Types.gen';

import type {forkSpec as Types_forkSpec} from './Types.gen';

import type {generationConfig as Types_generationConfig} from './Types.gen';

import type {generationResult as Types_generationResult} from './Types.gen';

import type {openAPISpec as Types_openAPISpec} from './Types.gen';

import type {specDiff as Types_specDiff} from './Types.gen';

import type {t as Pipeline_t} from '../src/core/Pipeline.gen';

export const generateSingleSpecPure: (spec:Types_openAPISpec, config:Types_generationConfig) => 
    { TAG: "Ok"; _0: Pipeline_t }
  | { TAG: "Error"; _0: Types_codegenError } = CodegenJS.generateSingleSpecPure as any;

export const generateSingleSpec: (spec:Types_openAPISpec, config:Types_generationConfig) => Promise<Types_generationResult> = CodegenJS.generateSingleSpec as any;

export const generateMultiSpecPure: (baseSpec:Types_openAPISpec, forkSpecs:Types_forkSpec[], config:Types_generationConfig) => 
    { TAG: "Ok"; _0: Pipeline_t }
  | { TAG: "Error"; _0: Types_codegenError } = CodegenJS.generateMultiSpecPure as any;

export const generateMultiSpec: (baseSpec:Types_openAPISpec, forkSpecs:Types_forkSpec[], config:Types_generationConfig) => Promise<Types_generationResult> = CodegenJS.generateMultiSpec as any;

export const compareSpecs: (baseSpec:Types_openAPISpec, forkSpec:Types_openAPISpec, baseName:(undefined | string), forkName:(undefined | string), outputPath:(undefined | string)) => Promise<Types_specDiff> = CodegenJS.compareSpecs as any;

export const generate: (config:Types_generationConfig) => Promise<Types_generationResult> = CodegenJS.generate as any;

export const createDefaultConfig: (url:string, outputDir:string) => Types_generationConfig = CodegenJS.createDefaultConfig as any;

export const generateFromUrl: (url:string, outputDir:string, config:(undefined | Types_generationConfig)) => Promise<Types_generationResult> = CodegenJS.generateFromUrl as any;

export const generateFromFile: (filePath:string, outputDir:string, config:(undefined | Types_generationConfig)) => Promise<Types_generationResult> = CodegenJS.generateFromFile as any;
