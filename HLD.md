                ┌──────────────────────────┐
                │        Customer          │
                │ Runs Log Collection      │
                │ Script                   │
                └────────────┬─────────────┘
                             │ Logs generated
                             ▼
                ┌────────────────────────────┐
                │ Log Analyzer Tool          │
                │ (Error Extractor)          │
                └─────────┬──────────────────┘
                          │ Extracted Errors
                          ▼
                ┌──────────────────────────────┐                ┌────────────────────────────────────────────────┐
                │ Issue Correlation Engine     │<-------------->|                 JIRA Summary DB                |
                │  - Search JIRA Summary DB    │                └────────────────────────────────────────────────┘
                │  - Search Known-Issues       │
                └─────────┬────────────────────┘
                          │ Matched JIRA IDs /
                          │ Known Issues
                          ▼
                ┌──────────────────────────────┐
                │ JIRA MCP Analyzer Tool       │
                │  - Fetch ticket details      │
                │  - AI summarization          │
                │  - Root cause detection      │
                │  - Solution extraction       │
                └─────────┬────────────────────┘
                          ▼
                ┌──────────────────────────────┐
                │ Final RCA Report Generator   │
                │  - Probable Cause            │
                │  - Suggested Fix             │
                └─────────┬────────────────────┘
                          ▼
                ┌──────────────────────────────┐
                │  Engineering Review Team     │
                │  - Validate RCA              │
                │  - Add insights (if needed)  │
                │  - Approve / Refine          │
                └─────────┬────────────────────┘
                          ▼
                ┌──────────────────────────────┐
                │  Final Approved RCA Report   │
                └─────────┬────────────────────┘
                          ▼
                ┌──────────────────────────┐
                │        Customer          │
                │  Receives Final RCA      │
                └──────────────────────────┘
