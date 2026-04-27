# Customer Lookup Data Agent — Design Spec

**Date:** 2026-04-27
**Author:** Brian Fox
**Status:** Draft — Agent instructions finalized, pending testing

---

## Overview

A Fabric Data Agent that gives the Aftermarket Sales Manager a conversational interface to look up customer account information. The primary problem it solves is that customers are sometimes registered under different entity names (e.g., "T & J Farms" and "Tom & Jerry Corp Farms" may be the same real-world customer). The agent helps identify all related accounts by searching partial names across every name field.

---

## Problem Statement

The Aftermarket Sales Manager needs to:
1. Look up a customer by partial or approximate name and get all matching accounts back
2. Identify when multiple account records likely represent the same real-world entity
3. Quickly retrieve account numbers, contact IDs, and account standing for a customer
4. Lay groundwork for defining new CSM groups (future phase — not in scope now)

---

## Architecture

### Agent Location
- **Workspace:** RP - Service Reports
- **Item type:** Fabric Data Agent
- **Name:** Customer Lookup - Data Agent
- **Status:** Draft (to be published after testing)

### Data Source
- **Lakehouse:** LH_Master_Data (SQL analytics endpoint)
- **Table:** `dim_CustomerList` (only — no other tables needed for Phase 1)

### Why dim_CustomerList
`dim_CustomerList` is a comprehensive, fully enriched customer dimension refreshed daily through the master pipeline. It consolidates data from four raw sources (`Raw_ARMaster`, `Raw_Contact`, `Raw_ArMaster_Customer`, `Raw_ArMaster_Contact`) and includes all name variants, account identifiers, financial standing, and classification fields needed for this agent.

---

## Agent Instructions

```
You are the Customer Lookup Data Agent for South Plains Implement. Your purpose is to help users find customer account information from our customer database.

## Your Primary Job

Help users find customers by name, partial name, account number, or company name. Customers in our system are sometimes listed under different entity names — for example, a farm operation might appear as "T & J Farms" under one account and "Tom & Jerry Corp" under another. When searching, always return ALL close matches so the user can identify which accounts belong to the same real-world customer.

## How to Search

- When given a name or partial name, search broadly using partial matching against CustomerName, CompanyName, DisplayName, FirstName, and LastName
- When given an account number, match exactly on AccountNumber or CustomerNumber
- If results seem like they could be the same real-world entity, note that to the user
- Always return results even if the match is not exact — err on the side of showing more results, not fewer

## What to Include in Every Customer Result

Always show these fields:
- Account Number (AccountNumber)
- Customer Number (CustomerNumber)
- Contact ID (ContactID)
- All available name fields: DisplayName, CompanyName, CustomerName, FirstName, LastName
- Account Status (AccountStatus — Active, Inactive, Hold, or Closed)
- Customer Type (CustomerTypeDescription — Retail, Fleet, Internal, etc.)
- Is Key Customer (IsKeyCustomer)
- Payment Method (PaymentMethod)
- Account Balance (AccountBalance)

## What to Avoid

- Do not include special system accounts (AccountNumber = UNKNOWN, INTERNAL, WARRANTY, FLEET, EXCESS, POLICY, BILLING, MISC, STOCK) in results unless the user specifically asks about them
- Do not speculate about data not in the database

## Scope

You only have access to customer profile and contact information. You cannot answer questions about purchase history, invoices, parts orders, or service records — direct those questions to the appropriate report or agent.
```

---

## Key Fields in dim_CustomerList (Reference)

| Field | Purpose |
|-------|---------|
| `AccountNumber` | Primary business key — numeric, unique per account |
| `CustomerNumber` | Secondary identifier from AR system |
| `ContactID` | Contact record linkage key |
| `DisplayName` | Best display name (company if available, else Last, First) |
| `CompanyName` | Company/business name |
| `CustomerName` | Cleaned version of company or last/first name |
| `FirstName` / `LastName` | Individual name components |
| `AccountStatus` | Active, Inactive, Hold, Closed |
| `CustomerTypeDescription` | Retail, Fleet, Internal, Warranty, Policy, Billing, Excess, Misc |
| `IsKeyCustomer` | True if ContactClass = 'KEY' |
| `PaymentMethod` | Payment method on file |
| `AccountBalance` | Current AR balance |
| `CustomerTier` | Key Account, Premium, Standard, Basic (based on credit limit + key flag) |

### Excluded from Default Responses
Phone numbers, email, city/state, credit limit, aging buckets — available on request but not shown by default to keep results focused.

### Special System Accounts (Excluded from Search by Default)
AccountNumbers: UNKNOWN, INTERNAL, WARRANTY, FLEET, EXCESS, POLICY, BILLING, MISC, STOCK (CustomerKeys -1 to -9). These are system records, not real customers.

---

## Suggested Test Questions

Use these during agent testing to validate behavior:

| Test | Question to Ask | What to Verify |
|------|----------------|----------------|
| Partial name search | "Find all customers with Farm in the name" | Returns multiple matches, all name fields shown |
| Alias detection | "Show me accounts that look like they could be the same as [customer name]" | Agent surfaces similar names and flags them |
| Account number lookup | "Look up account number 12345" | Returns exact match with all required fields |
| Key customer filter | "Which of these customers are key customers?" | IsKeyCustomer = true accounts flagged |
| No-result handling | "Find customer named XYZABC123" | Agent responds gracefully, no crash |
| System account exclusion | "Find customer named UNKNOWN" | Returns nothing by default, or notes it's a system record |
| Status filter | "Show me active accounts with Smith in the name" | Filters to AccountStatus = Active |
| Balance inquiry | "What is the account balance for [customer name]?" | Returns AccountBalance field |

---

## Future Phase 2 — CSM Group Management

The Sales Manager wants to define new CSM groups similar to the "San Angelo CSM" group in Customer Anatomy. When this is built:

- Add a `dim_CSM_Groups` table to LH_Master_Data (CSV-maintained, same pattern as `lookup_UniqueCustomers_Invoice`)
- Populate with AccountNumber → CSM Group Name mappings
- Add `dim_CSM_Groups` as a second data source in this agent
- Update agent instructions to include CSM group in results

The current CSM column in Customer Anatomy V2 is a DAX calculated column with a hardcoded list of account numbers — it is NOT in the Lakehouse and therefore not queryable by this agent today.

---

## Decisions Made

| Decision | Choice | Reason |
|----------|--------|--------|
| Platform | Fabric Data Agent | Same pattern as existing SPI Service Operations Assistant |
| Data source | Lakehouse SQL endpoint (dim_CustomerList) | Rich, daily-refreshed, no additional modeling needed |
| Workspace | RP - Service Reports | Consistent with existing agent; Sales Manager already has access |
| CSM groups | Deferred to Phase 2 | Keep initial scope simple; add if needed |
| Financial fields | Available on request, AccountBalance shown by default | Balance useful for account standing; full AR detail not needed |
| Phone/email/address | Not shown by default | Not the primary use case for this agent |
