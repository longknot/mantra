# MCP

MCP is a Free Pascal implementation of the [Model Context Protocol](https://modelcontextprotocol.io/specification/2025-06-18)
It offers classes to implement a MCP server as well as a MCP client.

It also offers the start of a MCP tool server that will allow an AI agent to control Lazarus, and a MCP server that allows a LLM to execute queries on a database.
Any database supported by FPC's SQLDB is supported.

## License
This code is licensed with the usual FPC LGPL with linking exception license.

## Repo layout

The [docs](docs) directory contains a presentation of the framework given at
the Pascal AI workshop organized by Blaise Pascal Magazine on 2025-07-12.
* [mcp.lpg](mcp.lpg) This is the project group containing all 
* [Src/Base](Src/Base) contains the source code for all classes to create a
  MCP server
* [Src/Client](Src/IDE) Contains the units with classes to create a MCP client. 
* [Src/IDE](Src/IDE) Contains the packages for Lazarus IDE integration
* [Src/proxy](Src/proxy) Contains the MCP proxy (using the private socket protocol)
* [demo](demo) Contains a demo project. Simulates a weather service
* [dbconnector](dbconnector) Contains a MCP server allowing to execute SQL statements on a database/

## Installation

* Open the Src/Base/mcpbase.lpk package in the lazarus IDE.
* Open the Src/Client/mcpclient.lpk package in the lazarus IDE.
* Open the Src/Base/mcpdesign.lpk package in the lazarus IDE and install it.
  This will install 4 components on the component palette on tab MCP. 
* if you wish to allow an LLM to control the lazarus IDE, compile and install Src/IDE/mcplazcontrol.lpk
  to actually allow the LLM to control the IDE, you must use the mcpproxy.

## Compiling the programs:

After you have opened the mcpbase.lpk package; you can compile all three sample programs:
* demo/client/mcpclient.lpi (a generic MCP client)
* demo/client/mockserver.pp (a small mock MCP server, to be used for testing)
* demo/weather.lpi (small demo)
* demo/search/mcpsearch.lpi (MCP server to execute web searches using Tavily)
* src/proxy/mcpproxy.lpi (StdIO to Socket transport proxy)
* dbconnector/mcpdbconnector.lpi
