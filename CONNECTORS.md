# Connectors

This plugin works best with the following data sources connected. Configure them in `.mcp.json` or through your organization's MCP setup.

## Required

| Connector | Purpose | Default |
|-----------|---------|---------|
| **~~project-tracker~~** | Issue tracking, status transitions, label management | [Linear](https://mcp.linear.app/mcp) |
| **~~version-control~~** | Pull requests, code review, spec file management | [GitHub](https://api.githubcopilot.com/mcp/) |

## Recommended

| Connector | Purpose | Examples |
|-----------|---------|----------|
| **~~ci-cd~~** | Automated spec review triggers, deployment checks | GitHub Actions |
| **~~deployment~~** | Preview deployments, production verification | Vercel, Netlify, Railway |
| **~~analytics~~** | Data-informed spec drafting, post-launch verification | PostHog, Amplitude, Mixpanel |

## Optional

| Connector | Purpose | Examples |
|-----------|---------|----------|
| **~~research-library~~** | Literature grounding for research-based features | Zotero |
| **~~communication~~** | Stakeholder notifications, decision tracking | Slack |
| **~~design~~** | Visual prototyping handoff | Figma, v0 |

## Customization

Replace `~~placeholder~~` values with your team's specific tools. The plugin's methodology is tool-agnostic -- it works with any project tracker, version control system, or CI/CD platform that has MCP support.

To customize, edit `.mcp.json` and update the server URLs to match your organization's tools.
