#!/bin/bash
# Example: using arb_translator_gen_z CLI to translate an ARB file

# Make sure you have a source ARB file
SOURCE_FILE="lib/l10n/app_en.arb"
 
You can now run the CLI with:
arb_translator_gen_z


dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang "ne te ug" 
— for multiple languages like Nepali Telugu Uyghur

dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang ne
— for single language like Nepali

dart run bin/arb_translator.dart --source lib/l10n/app_en.arb --lang all
— for all languages