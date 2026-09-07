# Security policy

## Reporting a vulnerability

Please report suspected security vulnerabilities privately. Use [GitHub's private vulnerability report form](https://github.com/Nucs/FinanceSharp/security/advisories/new) when it is available for this repository.

If private reporting is not enabled or the form is unavailable, open an [issue](https://github.com/Nucs/FinanceSharp/issues) that only asks for a private security contact. Do not include vulnerability details, exploit code, credentials, or affected users' data in that issue. Wait for a private channel before sharing the report. This fallback follows [GitHub's guidance for private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately).

In the private report, include:

- The affected FinanceSharp version or commit, .NET version, and operating system.
- The affected component and the conditions needed to trigger the issue.
- A minimal reproduction using synthetic data, and the expected and actual behavior.
- The potential impact and any mitigation or proposed fix you have identified.

Coordinate disclosure with the maintainers through the private report. Acknowledgement and fix dates depend on maintainer availability and the issue; this repository does not promise a response deadline or a vulnerability bounty.

## Versions and scope

FinanceSharp is under active development and does not publish a long-term security support schedule. Report the exact release or commit you tested, including older versions, so the affected versions can be assessed. Do not assume that an older release receives security backports.

Crashes involving memory safety, unsafe data handling, unintended access to data, and compromised build or package dependencies may be security issues. Ordinary indicator correctness, rounding, or API behavior reports can use the public bug form when they do not reveal a vulnerability or private data.
