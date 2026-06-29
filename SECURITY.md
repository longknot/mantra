# Security Policy

## Alpha Status

Mantra is experimental alpha software. It has not received a security audit and
should not be treated as a hardened sandbox.

Do not use Mantra to execute untrusted programs or expose the runtime, HTTP
server, or MCP server directly to untrusted networks. Run it with the minimum
filesystem, process, and network permissions required for your use case.

## Supported Versions

Security fixes are provided only for the current development version on the
default branch. Older commits, binaries, and pre-release snapshots are not
supported.

## Reporting a Vulnerability

Use GitHub's private vulnerability reporting feature for this repository:

1. Open the repository's **Security** tab.
2. Select **Report a vulnerability**.
3. Include reproduction steps, affected components, impact, and any suggested
   mitigation.

If private vulnerability reporting is unavailable, contact the repository
maintainer privately through the contact information on their GitHub profile.
Do not open a public issue containing exploit details or sensitive information.

Reports will be acknowledged when practical. Because this is an alpha project,
no fixed response or remediation timeline is guaranteed.

## Scope

Reports are especially relevant when they involve:

- memory corruption or crashes caused by crafted input;
- unexpected filesystem, process, or network access;
- path traversal or unsafe package/module loading;
- HTTP or MCP server exposure and request handling;
- disclosure of data outside the requested input or workspace;
- denial-of-service behavior that is disproportionate to the supplied input.

Ordinary language bugs, semantic inconsistencies, and expected resource use for
large proof searches should be reported as regular issues unless they create a
clear security impact.

## Disclosure

Please allow time for investigation and mitigation before public disclosure.
Once a fix is available, the project may publish an advisory describing the
affected versions, impact, and remediation.

