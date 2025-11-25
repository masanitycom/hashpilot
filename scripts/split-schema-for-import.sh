#!/bin/bash

# スキーマファイルを3つに分割する
# 1. テーブル定義のみ
# 2. RPC関数のみ
# 3. RLSポリシーとその他

cd /mnt/d/HASHPILOT

echo "📋 スキーマを3つのファイルに分割中..."

# 1. テーブル定義のみ抽出（CREATE TABLEからALTER TABLEまで）
echo "   1. テーブル定義を抽出中..."
grep -n "^CREATE TABLE" production-schema-clean.sql | while IFS=: read -r line_num rest; do
    # 次のALTER TABLE または CREATE の行番号を見つける
    next_line=$(tail -n +$((line_num + 1)) production-schema-clean.sql | grep -n "^CREATE\|^ALTER" | head -1 | cut -d: -f1)
    if [ -n "$next_line" ]; then
        sed -n "${line_num},$((line_num + next_line - 1))p" production-schema-clean.sql
    fi
done > schema-part1-tables.sql

# 2. RPC関数のみ抽出
echo "   2. RPC関数を抽出中..."
sed -n '/^CREATE OR REPLACE FUNCTION/,/^\$\$/p' production-schema-clean.sql > schema-part2-functions.sql

# 3. RLSポリシー抽出
echo "   3. RLSポリシーを抽出中..."
sed -n '/^ALTER TABLE.*ENABLE ROW LEVEL SECURITY/,/^CREATE POLICY/p' production-schema-clean.sql > schema-part3-rls.sql

echo "✅ 分割完了！"
echo "   📄 schema-part1-tables.sql"
echo "   📄 schema-part2-functions.sql"
echo "   📄 schema-part3-rls.sql"
