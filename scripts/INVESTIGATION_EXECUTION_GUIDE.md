# 🔍 Profit Investigation Script Execution Guide

## Overview
The script `/mnt/d/HASHPILOT/scripts/thorough-profit-investigation.sql` needs to be executed to investigate why user 2BF53B has only $1.25 in profits despite being operational since 7/2/2025.

## How to Execute

### Option 1: Supabase Dashboard SQL Editor
1. Go to your Supabase project dashboard: https://app.supabase.com/project/soghqozaxfswtxxbgeer
2. Navigate to the SQL Editor
3. Copy and paste the entire content of the investigation script
4. Execute each section one by one or run the entire script

### Option 2: Local Database Connection
If you have database connection tools available:
```bash
# Using psql (if available)
psql "postgresql://postgres:[password]@db.soghqozaxfswtxxbgeer.supabase.co:5432/postgres" -f /mnt/d/HASHPILOT/scripts/thorough-profit-investigation.sql

# Using Supabase CLI (if available)
supabase db reset
supabase db push
```

## What the Script Investigates

### 1. 2BF53B's Detailed Profit Records
- Shows all daily profit entries for user 2BF53B
- Includes yield rates, user rates, base amounts, and phases
- Calculates days from approval (2025-06-17) and operation start (2025-07-02)

### 2. Profit vs Daily Yield Settings Comparison
- Compares recorded profit rates with system-wide daily yield settings
- Identifies any rate mismatches or missing settings
- Flags inconsistencies in profit calculations

### 3. Other Operational Users' Profit Status
- Lists all users who should be operational (approved + 15 days passed)
- Shows their total NFT count, cumulative USDT, and calculated profits
- Identifies users with similar profit calculation issues

### 4. July 2nd Profit Generation Investigation
- Examines why profits started specifically on 7/2/2025
- Shows the daily yield settings active on that date
- Confirms if this aligns with the 15-day delay rule

### 5. Daily Yield Settings Timeline
- Shows all daily yield configurations from 7/2 onwards
- Helps identify any gaps or inconsistencies in settings
- Confirms rate continuity

### 6. Zero-Profit Users Analysis
- Identifies users who should have profits but show $0
- Categorizes the type of problem (missing affiliate_cycle, zero NFT count, etc.)
- Focuses on users past their 15-day operation start date

### 7. Same-Period User Comparison
- Compares 2BF53B with users approved around the same time (6/15-6/25)
- Shows relative profit performance
- Identifies if the issue is user-specific or systemic

### 8. System Log Analysis
- Reviews recent system logs related to profit processing
- Shows any errors or warnings during daily yield calculations
- Helps identify processing failures

## Expected Findings

Based on the investigation scope, we expect to find:
1. **Root cause** of 2BF53B's low profits ($1.25 vs expected ~$180+)
2. **Other affected users** with similar profit calculation issues
3. **System-wide issues** in profit processing or daily yield application
4. **Timeline inconsistencies** in when profits should have started
5. **Configuration problems** in daily yield settings

## Key Questions to Answer
1. Why does 2BF53B have only $1.25 in profits since 7/2?
2. Are there gaps in daily yield processing?
3. Are other users affected by the same issue?
4. Is the 15-day delay rule being properly applied?
5. Are there errors in the profit calculation functions?

## Next Steps After Execution
1. Review all output sections
2. Identify patterns in profit calculation failures
3. Check if specific dates/periods are missing profits
4. Verify daily yield settings continuity
5. Plan corrective actions based on findings

## Database Connection Details
- Project URL: https://soghqozaxfswtxxbgeer.supabase.co
- Use the environment variables from `.env.local` for connection
- Execute as admin/service role for full access to all tables