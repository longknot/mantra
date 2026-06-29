{
    This file is part of the Free Component Library

    MCP Resource strings
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.strings;

{$mode objfpc}{$H+}

interface

Resourcestring
  SErrUriCannotBeEmpty = 'Resource URI cannot be empty';
  SErrRegistryALreadyInstantiated = 'Resource registry already instantiated';
  SErrRegistryClassEmpty = 'Resource registry class may not be empty';
  SErrUnknownResource = 'Unknown resource URI %s';
  SErrInvalidResource = 'Invalid resource URI';
  SErrUnknownPrompt = 'Unknown prompt name: %s';
  SErrMissingName = 'Missing prompt name';
  SErrPromptNameRequired = 'Prompt name cannot be empty';
  SErrControllerInitialized = 'Controller already initialized';
  SErrControllerClassEmpty = 'Controller class may not be empty';
  SErrNoResourceRegistry = 'No resource registry available to look up resource';
  SErrUnknownTool = 'Unknown tool name: %s';

implementation

end.

