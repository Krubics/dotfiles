---
name: project-picksbt
description: "PicksBT portfolio backtesting app — stack, deployment, and key architectural decisions"
metadata: 
  node_type: memory
  type: project
  originSessionId: fb2b3c96-6133-4c53-ad42-501b0b853bc3
---

PicksBT is a React frontend for portfolio backtesting at /home/krubics/Projects/PicksBT.

**Stack:** Vite 5 + React 18 + TypeScript, Radix Themes (accentColor=orange, grayColor=sand, light mode), Tailwind CSS v3 (preflight:false, utilities only), recharts, react-day-picker@8, @radix-ui/react-popover, JetBrains Mono font.

**Deployment:** Auto-deploys to Vercel preview after every Write/Edit via PostToolUse hook in `.claude/settings.local.json`. Hook runs `vercel --yes` async and emits preview URL as systemMessage.

**Key architectural facts:**
- Path alias `@/` → `./src` in vite.config.ts and tsconfig.app.json
- Radix CSS vars scoped to `.radix-themes` div — Popover.Portal renders at body level so popover content uses hardcoded colors (background: "white", border: "1px solid #e8e5e0")
- Tailwind used only for responsive grid layouts (grid-cols-*)
- `vercel.json` sets outputDirectory: "dist" (Vite default, not Vercel's assumed "build/")
- Node constraint is 18.19.1 — must use Vite 5, not 9+

**Components:**
- App.tsx: root with Theme wrapper, sticky header, PortfolioSetup + CsvImport + MetricsSection
- PortfolioSetup.tsx: cash input, add position form (ticker/dates/mode/value), positions table
- CsvImport.tsx: drag-and-drop CSV (Ticker, Start Date, End Date format), preview table
- MetricsSection.tsx: 6-section metrics layout + recharts equity curve AreaChart
- ui/DatePicker.tsx: Popover + DayPicker, styled to match Radix TextField

**MetricsSection BacktestMetrics interface fields (as of last rewrite):**
Returns: cagr, realReturn, timeWeightedReturn, moneyWeightedReturn
Risk: maxDrawdown, volatility
Risk-Adjusted: sharpeRatio, sortinoRatio, calmarRatio
Trade Performance: winRate, profitFactor, expectancy
Robustness: inSampleReturn, outOfSampleReturn, walkForwardStability, parameterSensitivity, monteCarloP5, monteCarloMedian, monteCarloP95
Execution: transactionCosts, slippage, turnover

**Why:** User loves the design, metrics restructure was the last completed task. Backend integration is the likely next step.
**How to apply:** When backend is integrated, wire computed metrics into the BacktestMetrics object passed to MetricsSection. The interface is already defined with all fields.
