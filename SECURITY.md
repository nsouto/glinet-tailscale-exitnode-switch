# Security Policy

## Supported Versions

This project targets GL.iNet router firmware where `/usr/bin/gl_tailscale` exists (typically 4.x series). Older/newer versions may work but are not guaranteed.

## Reporting a Vulnerability

If you believe you have found a security issue in this repository (for example, a command injection risk in the installer):

1. **Do NOT open a public issue** for security vulnerabilities
2. Instead, please report privately by emailing the maintainer or using [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
3. Include:
   - A clear description of the issue
   - Steps to reproduce
   - Suggested mitigation if you have one

**Important**: Do not post sensitive router credentials, private keys, or exploit details in public issues.

## Response Timeline

We aim to acknowledge security reports within 48 hours and provide a fix or mitigation plan within 7 days for confirmed vulnerabilities.

## Scope

This project modifies router scripts and startup behavior. It is not responsible for vulnerabilities in GL.iNet firmware, OpenWrt, or Tailscale itself.
