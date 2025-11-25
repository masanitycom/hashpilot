#!/bin/bash

echo "=== 本番データの正確な件数 ==="
echo ""

# Admins
admins=$(awk '/INSERT INTO "public"\."admins"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "Admins: $admins"

# Users
users=$(awk '/INSERT INTO "public"\."users"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "Users: $users"

# Affiliate Cycle
cycles=$(awk '/INSERT INTO "public"\."affiliate_cycle"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "Affiliate Cycle: $cycles"

# Purchases
purchases=$(awk '/INSERT INTO "public"\."purchases"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "Purchases: $purchases"

# NFT Master
nfts=$(awk '/INSERT INTO "public"\."nft_master"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "NFT Master: $nfts"

# Daily Yield Log
yields=$(awk '/INSERT INTO "public"\."daily_yield_log"/{flag=1;next} /^--/{flag=0} flag && /^\t\(/{count++} END{print count}' production-data-clean.sql)
echo "Daily Yield Log: $yields"

