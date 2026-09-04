# Security Policy

## Supported Versions

The `latest` tag on `ghcr.io/jackbrenn/quakejs-rootless` and the release
tags of this repository. Older date-stamped tags are kept for reproducibility
but are not patched.

## Reporting a Vulnerability

Please report security vulnerabilities privately:

- **Email:** brennanjk@protonmail.com

Please do **not** open a public issue for a security vulnerability.

## Response

I will acknowledge receipt within 3 business days and aim to ship a fix as
soon as practicable. If a fix is released, the affected and fixed image
tags will be noted in the advisory correspondence.

## Scope Notes

- The engine code under `quakejs/build/` is vendored from
  [ioq3](https://github.com/inolen/ioq3) /
  [begleysm/ioq3](https://github.com/begleysm/ioq3) (see the header of
  `quakejs/html/ioquake3.js` for the exact provenance).
  Vulnerabilities found in the upstream engine should be reported to the
  upstream project as well.
- The Helm chart in `.helm/` is a third-party contribution and is out of
  scope for this policy.
