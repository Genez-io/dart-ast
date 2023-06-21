import 'dart:convert';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

import 'dart:io';

class Parameter {
  String name;
  String type;
  String library;
  Parameter(this.name, this.type, this.library);
}

class Field {
  String name;
  String type;
  String library;
  Field(this.name, this.type, this.library);
}

class Method {
  String name;
  String returnType;
  String? returnTypeLibrary;
  List<Parameter> parameters;
  Method(this.name, this.returnType, this.returnTypeLibrary, this.parameters);
}

class Class {
  String library;
  String path;
  String name;
  List<Method> methods;
  List<Field> fields;
  Class(this.name, this.methods, this.fields, this.library, this.path);
}

class Enum {
  String library;
  String path;
  String name;
  List<String> values;
  Enum(this.name, this.values, this.library, this.path);
}

class TypeAlias {
  String library;
  String path;
  String name;
  String type;
  TypeAlias(this.name, this.type, this.library, this.path);
}

class Program {
  List<Class> classes;
  List<Enum> enums;
  List<TypeAlias> typeAliases;
  Map<String, List<String>> imports;

  Program(this.classes, this.enums, this.typeAliases, this.imports);

  Map<String, dynamic> toJson() => {
        'classes': classes
            .map((c) => {
                  'name': c.name,
                  "library": c.library,
                  "path": c.path,
                  'fields': c.fields
                      .map((f) => {'name': f.name, 'type': f.type, 'library': f.library})
                      .toList(),
                  'methods': c.methods
                      .map((m) => {
                            'name': m.name,
                            'returnType': m.returnType,
                            'returnTypeLibrary': m.returnTypeLibrary,
                            'parameters': m.parameters
                                .map((p) => {'name': p.name, 'type': p.type, 'library': p.library})
                                .toList()
                          })
                      .toList()
                })
            .toList(),
        'imports': imports,
        'enums':
            enums.map((e) => {'name': e.name, 'values': e.values, 'path': e.path, 'library': e.library}).toList(),
        "typeAliases":
            typeAliases.map((t) => {'name': t.name, 'type': t.type, 'path': t.path, 'library': t.library}).toList(),
      };
}

void main(List<String> args) async {
  List<String> includedPaths = args;
  AnalysisContextCollection collection =
      new AnalysisContextCollection(includedPaths: includedPaths);

  final program = Program([], [], [], {});

  for (AnalysisContext context in collection.contexts) {
    for (String filePath in context.contextRoot.analyzedFiles()) {
      AnalysisSession analysisSession = context.currentSession;

      final libraryElement = await analysisSession
          .getLibraryByUri(path.toUri(filePath).toString())
          .then((libraryResult) {
        if (libraryResult is LibraryElementResult) {
          return libraryResult.element;
        }
        return null;
      });
      if (libraryElement == null) {
        continue;
      }

      libraryElement.units[0].enums.forEach((enumElement) {
        // print("Enum is ${enumElement.name}");
        final enumType = Enum(enumElement.name, [], libraryElement.identifier, filePath);
        enumElement.fields.forEach((element) {
          if (element.name != "index" && element.name != "values")
            enumType.values.add(element.name);
        });

        program.enums.add(enumType);
      });

      libraryElement.units[0].typeAliases.forEach((typeAliasElement) {
        // print("TypeAlias is ${typeAliasElement.name}");
        // print(typeAliasElement.aliasedType);
        final typeAlias = TypeAlias(
            typeAliasElement.name, typeAliasElement.aliasedType.toString(), libraryElement.identifier, filePath);
        program.typeAliases.add(typeAlias);
      });

      for (ClassElement classElement in libraryElement.units[0].classes) {
        final classType = Class(classElement.name, [], [], libraryElement.identifier, filePath);
        // print("Class is ${classElement.name}");
        classElement.methods.forEach((method) {
          final methodType =
              Method(method.name, method.returnType.toString(), method.returnType.element?.library?.identifier, []);

          // print(method.parameters);
          method.parameters.forEach((parameter) {
            final parameterType =
                Parameter(parameter.name, parameter.type.toString(), parameter.type.element!.library!.identifier);
            methodType.parameters.add(parameterType);
          });

          classType.methods.add(methodType);
        });

        classElement.fields.forEach((field) {
          classType.fields.add(Field(field.name, field.type.toString(), field.type.element!.library!.identifier));
        });

        program.classes.add(classType);
      }
    }
  }

  print(jsonEncode(program));
}
