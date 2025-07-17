#!/usr/bin/env node

/**
 * 🚨 HASHPILOT デバッグ版利益計算ツール
 * データベース接続とアクセス権限の確認
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase設定
const config = require('./config.js');
const SUPABASE_URL = process.env.SUPABASE_URL || config.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || config.SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function debugDatabaseAccess() {
    console.log('🔍 HASHPILOT データベースアクセス確認');
    console.log('=====================================\n');

    try {
        // 1. 接続確認
        console.log('🌐 Supabase接続確認...');
        console.log(`URL: ${SUPABASE_URL}`);
        console.log(`APIキー: ${SUPABASE_KEY.substring(0, 20)}...`);

        // 2. usersテーブルの確認
        console.log('\n📊 usersテーブル確認...');
        const { data: usersData, error: usersError } = await supabase
            .from('users')
            .select('user_id, total_purchases')
            .limit(5);

        if (usersError) {
            console.log('❌ usersテーブルエラー:', usersError);
        } else {
            console.log('✅ usersテーブルアクセス成功');
            console.log('📋 取得したユーザー:');
            usersData.forEach(user => {
                console.log(`  - ${user.user_id}: $${user.total_purchases}`);
            });
        }

        // 3. 特定ユーザー確認
        console.log('\n🎯 User 7A9637 確認...');
        const { data: specificUser, error: specificError } = await supabase
            .from('users')
            .select('user_id, total_purchases, has_approved_nft')
            .eq('user_id', '7A9637');

        if (specificError) {
            console.log('❌ 特定ユーザーエラー:', specificError);
        } else if (!specificUser || specificUser.length === 0) {
            console.log('⚠️ User 7A9637 が見つかりません');
            console.log('📋 利用可能なユーザーID一覧:');
            
            // 全ユーザーID取得
            const { data: allUsers, error: allError } = await supabase
                .from('users')
                .select('user_id')
                .limit(20);

            if (!allError && allUsers) {
                allUsers.forEach(user => console.log(`  - ${user.user_id}`));
            }
        } else {
            console.log('✅ User 7A9637 見つかりました:');
            console.log(`  投資額: $${specificUser[0].total_purchases}`);
            console.log(`  NFT承認: ${specificUser[0].has_approved_nft}`);
        }

        // 4. affiliate_cycleテーブル確認
        console.log('\n🔄 affiliate_cycleテーブル確認...');
        const { data: cycleData, error: cycleError } = await supabase
            .from('affiliate_cycle')
            .select('user_id, total_nft_count, cum_usdt')
            .eq('user_id', '7A9637');

        if (cycleError) {
            console.log('❌ affiliate_cycleエラー:', cycleError);
        } else if (!cycleData || cycleData.length === 0) {
            console.log('⚠️ 7A9637のaffiliate_cycleデータなし');
        } else {
            console.log('✅ affiliate_cycleデータ見つかりました:');
            console.log(`  NFT数: ${cycleData[0].total_nft_count}`);
            console.log(`  累積USDT: $${cycleData[0].cum_usdt}`);
        }

        // 5. daily_yield_logテーブル確認
        console.log('\n📈 daily_yield_logテーブル確認...');
        const { data: yieldData, error: yieldError } = await supabase
            .from('daily_yield_log')
            .select('date, yield_rate, user_rate')
            .order('date', { ascending: false })
            .limit(3);

        if (yieldError) {
            console.log('❌ daily_yield_logエラー:', yieldError);
        } else {
            console.log('✅ 日利設定データ:');
            yieldData.forEach(day => {
                console.log(`  ${day.date}: ${(day.yield_rate * 100).toFixed(3)}% → ${(day.user_rate * 100).toFixed(3)}%`);
            });
        }

        // 6. user_daily_profitテーブル確認
        console.log('\n💰 user_daily_profitテーブル確認...');
        const { data: profitData, error: profitError } = await supabase
            .from('user_daily_profit')
            .select('user_id, date, daily_profit')
            .limit(5);

        if (profitError) {
            console.log('❌ user_daily_profitエラー:', profitError);
        } else {
            console.log('✅ 利益データサンプル:');
            profitData.forEach(profit => {
                console.log(`  ${profit.user_id} ${profit.date}: $${profit.daily_profit}`);
            });
        }

        // 7. 推奨ユーザーID
        console.log('\n🎯 計算可能なユーザーID推奨:');
        if (usersData && usersData.length > 0) {
            const recommendedUser = usersData.find(u => parseFloat(u.total_purchases) > 0) || usersData[0];
            console.log(`推奨: ${recommendedUser.user_id}`);
            console.log('\n🚀 実行コマンド:');
            console.log(`node profit-calculator.js ${recommendedUser.user_id}`);
        }

    } catch (error) {
        console.error('💥 デバッグ実行エラー:', error);
    }
}

// 実行
debugDatabaseAccess();