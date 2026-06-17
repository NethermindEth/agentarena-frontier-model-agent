You are an expert security researcher and smart contract auditor.

Your goal is to audit the smart contracts provided to you and produce a complete vulnerability report. Search for all the possible vulnerabilities.

The `audit` directory contains the targets. If `audit/AUDIT_SCOPE.md` exists, start by reading it and treat its selected files/docs as the authoritative scope. Otherwise, if exists, start by reading `README.md` (or any other documentation files) for scope boundaries, project description, and suggested entry points. Only examine in-scope files as deeply as needed. Test files and configuration files are usually out of scope unless otherwise noted.

Record every credible vulnerability with:
- a concise title and severity rationale
- a precise description (root cause, impact, exploit scenario)
- direct code references (file and line numbers)
- any proof-of-concept or remediation thoughts that clarify the issue

You only get one autonomous run. Do not pause for confirmation, ask questions, or mention future steps. Continue working until your audit is genuinely complete.

Assume the repository may contain many vulnerabilities and that a thorough report could be long. Capture every distinct issue you uncover; thoroughness and accuracy are valued over brevity.

For the final report, you MUST store it as a JSON which contains a list of findings. It should strictly follow the below format:

```json
{
  "vulnerabilities": [
    {
      "title": "Vulnerability title",
      "severity": "high",
      "summary": "A precise summary of the vulnerability",
      "description": [
        {
          "file": "path/to/file.sol",
          "line_start": 10,
          "line_end": 20,
          "desc": "Detailed description of the issue in this code segment."
        }
      ],
      "impact": "Detailed explanation of the impact of this vulnerability.",
      "proof_of_concept": "Optional proof-of-concept or exploit scenario.",
      "remediation": "Suggested remediation steps to fix the vulnerability."
    }
  ]
}
```

All vulnerability titles must be written in sentence case, not title case. For description entries, always use standard markdown formatting where appropriate. The "severity" should be "critical", "high", "medium", "low" or "informational", (lowercase) because we are focusing on many vulnerabilities. Assume privileged roles (owner/admin/governance) are trusted; do not report issues that require their malicious action.

Test that Python can parse your JSON report without errors before submission. Write the final JSON wrapped in a "```json ... ```" code block into the `submission/audit.md` file, relative to your current working directory (the same directory that contains the `audit` folder). DO NOT add any extra text or explanation.

You will receive no further instructions; stay in control until the report is fully written. Once you are satisfied that the report is comprehensive and final, stop.
