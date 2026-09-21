# Positions, assistants and committees — plan

Status as of 2026-09-21. Items marked **Done** are live on the Inuka West server.

## Principles

- **Two people per office.** Every elected office has a holder and an assistant with the same permissions. One can then check the other's work (maker-checker), and the work continues when one is away.
- **Positions are configuration, not code.** Admin creates, fills and empties positions from the app. A position's powers come from its permissions, never from its name.
- **Only verified members hold office.** New members on probation can't be given a position.
- **Every change is audited:** who assigned or removed whom, when, and from which device.

## Offices

| Office | Assistant | Holders | Main powers | Screens |
|---|---|---|---|---|
| Chairperson | Vice Chairperson | 1 + 1 | Approve new members and welfare cases; chair meetings; all reports (read) | **Done** (Approvals, Meetings, Reports, Finance read) |
| Secretary | Assistant Secretary | 1 + 1 | Register members, approve profile changes, meetings, inactivity | **Done** |
| Treasurer | Assistant Treasurer | 1 + 1 | All finance, journals, reports, registration fees | **Done** |
| Welfare Manager | Assistant Welfare Manager | 1 + 1 | Welfare cases, payments, payouts | **Done** |
| Organizing Secretary | Assistant Organizing Secretary | 1 + 1 | Schedule meetings, agendas, registers | **Done** (uses Meetings) |
| Disciplinary Chair | Disciplinary Members (up to 4) | 1 + 4 | Disciplinary cases, hearings, fines | Roles **done**; module in phase 2 |
| IT Administrator | (2 holders) | 2 | Password resets, disable logins, audit log | **Done** (Admin tab) |
| Credit Committee, Board | no limit | — | Existing | **Done** |
| Custom (e.g. Youth Rep) | optional | set by Admin | Copy permissions from any role | **Done** (Positions → New position) |

## Phase 2 — Disciplinary module

1. **Offence types (constitution rules).** For example: late to a meeting = 100, absent without apology = X, misconduct = hearing. Each has a fine amount set per SACCO.
2. **Cases.**
   - Opened by a disciplinary member, approved by the Disciplinary Chair. Nobody approves their own case.
   - The member is notified by SMS and can respond in the app.
3. **Fines.**
   - Owed, then paid (as decided earlier), and counted as SACCO income.
   - Posted as a receivable when charged and cleared when paid: at the counter, by M-Pesa, or deducted from the next contribution if the SACCO allows.
   - Journal entries balance at every step.
4. **Automatic fines from meetings.** When the register is closed, members marked "Late" or "Absent" without an apology get a proposed fine. The Disciplinary Chair confirms it; it is not charged automatically.
5. **Reports.** Fines register, outstanding fines and case history, all exportable for auditors.

## Phase 3 — Terms and elections

- **Terms of office.** Each assignment gets a start and end date (e.g. AGM to AGM), with a reminder before a term ends and access that expires automatically. Handover notes go from the outgoing holder to the incoming one.
- **Election results.** The AGM records who was elected to which office, and positions are filled from the results. Only verified members appear on the ballot, and probation members can't vote.
- **Permission editor.** Admin can tick or untick individual permissions per position. Today a position copies another role's permissions; fine-grained editing will be audited, with a SuperAdmin-only list of sensitive permissions.
- **Other offices to consider:** Internal Auditor (the Supervisory Committee, read-only everything, as required by SASRA), Education/Training Officer, Investments Committee, and a Women and Youth representative.

## Open questions for the committee

1. Fine amounts for each offence, and whether fines may be deducted from savings (needs the member's consent under the by-laws).
2. The term length for each office, and whether an assistant takes over automatically if the holder leaves.
3. Whether the Supervisory Committee should be separate from the external Auditor role.
