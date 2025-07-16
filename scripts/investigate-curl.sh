#!/bin/bash

# HASHPILOT 日利状況緊急調査 - cURL版
# Supabase REST API を使用した直接調査

SUPABASE_URL="https://soghqozaxfswtxxbgeer.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8"

echo "=== HASHPILOT 日利状況緊急調査 ==="
echo ""

echo "1. ユーザー「7A9637」の基本情報"
curl -s -X GET "${SUPABASE_URL}/rest/v1/users?user_id=eq.7A9637" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "2. ユーザー「7A9637」の日利記録"
curl -s -X GET "${SUPABASE_URL}/rest/v1/user_daily_profit?user_id=eq.7A9637&order=date.desc" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "3. ユーザー「7A9637」のNFT購入状況"
curl -s -X GET "${SUPABASE_URL}/rest/v1/purchases?user_id=eq.7A9637&order=created_at.desc" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "4. ユーザー「7A9637」のサイクル状況"
curl -s -X GET "${SUPABASE_URL}/rest/v1/affiliate_cycle?user_id=eq.7A9637" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "5. ユーザー「2BF53B」の基本情報"
curl -s -X GET "${SUPABASE_URL}/rest/v1/users?user_id=eq.2BF53B" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "6. ユーザー「2BF53B」の日利記録"
curl -s -X GET "${SUPABASE_URL}/rest/v1/user_daily_profit?user_id=eq.2BF53B&order=date.desc" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "7. ユーザー「2BF53B」のNFT購入状況"
curl -s -X GET "${SUPABASE_URL}/rest/v1/purchases?user_id=eq.2BF53B&order=created_at.desc" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "8. ユーザー「2BF53B」のサイクル状況"
curl -s -X GET "${SUPABASE_URL}/rest/v1/affiliate_cycle?user_id=eq.2BF53B" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "9. 承認済みユーザー一覧（has_approved_nft=true）"
curl -s -X GET "${SUPABASE_URL}/rest/v1/users?has_approved_nft=eq.true&order=created_at.desc&select=user_id,email,full_name,total_purchases,has_approved_nft,created_at" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "10. 最新の日利記録全体（最新20件）"
curl -s -X GET "${SUPABASE_URL}/rest/v1/user_daily_profit?order=date.desc,created_at.desc&limit=20" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "11. 最新の日利設定ログ"
curl -s -X GET "${SUPABASE_URL}/rest/v1/daily_yield_log?order=date.desc&limit=10" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "12. 承認済み購入記録"
curl -s -X GET "${SUPABASE_URL}/rest/v1/purchases?admin_approved=eq.true&order=created_at.desc&select=user_id,created_at,admin_approved,nft_quantity,amount_usd" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "13. 最新のシステムログ（日利関連）"
curl -s -X GET "${SUPABASE_URL}/rest/v1/system_logs?or=(operation.ilike.*yield*,operation.ilike.*profit*,operation.ilike.*batch*)&order=created_at.desc&limit=10" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json"
echo ""

echo "=== 調査完了 ==="