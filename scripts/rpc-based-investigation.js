// RPC関数を使用した日利ユーザー調査
// 2025-01-16 実行

const { createClient } = require('@supabase/supabase-js');

// 環境変数を直接設定
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function rpcBasedInvestigation() {
    console.log('=== RPC関数を使用した日利ユーザー調査 ===\n');
    
    // 1. システムヘルスチェック
    console.log('1. システムヘルスチェック');
    try {
        const { data: healthData, error: healthError } = await supabase
            .rpc('system_health_check');
        
        if (healthError) {
            console.error('Error calling system_health_check:', healthError);
        } else {
            console.log('システム状況:');
            healthData.forEach(item => {
                console.log(`- ${item.component}: ${item.status} - ${item.message}`);
                if (item.details) {
                    console.log(`  詳細: ${JSON.stringify(item.details)}`);
                }
            });
        }
    } catch (err) {
        console.error('Exception calling system_health_check:', err);
    }
    
    // 2. 日利処理のテスト実行（テストモード）
    console.log('\n2. 日利処理のテスト実行');
    try {
        const today = new Date().toISOString().split('T')[0];
        const { data: testResult, error: testError } = await supabase
            .rpc('process_daily_yield_with_cycles', {
                p_date: today,
                p_yield_rate: 0.015,
                p_margin_rate: 30,
                p_is_test_mode: true,
                p_is_month_end: false
            });
        
        if (testError) {
            console.error('Error calling process_daily_yield_with_cycles:', testError);
        } else {
            console.log('テストモード日利処理結果:');
            console.log(`- 処理対象ユーザー: ${testResult.affected_users}人`);
            console.log(`- 配布予定日利総額: $${testResult.total_distributed.toFixed(2)}`);
            console.log(`- 自動NFT購入: ${testResult.auto_purchases}件`);
            console.log(`- 処理ステータス: ${testResult.status}`);
            
            if (testResult.user_details && testResult.user_details.length > 0) {
                console.log('\n処理対象ユーザーの詳細:');
                testResult.user_details.slice(0, 10).forEach((user, index) => {
                    console.log(`${index + 1}. User ${user.user_id}: $${user.daily_profit} (NFT: ${user.nft_count}個)`);
                });
            }
        }
    } catch (err) {
        console.error('Exception calling process_daily_yield_with_cycles:', err);
    }
    
    // 3. 昨日の日利処理結果確認
    console.log('\n3. 昨日の日利処理結果確認');
    try {
        const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        const { data: yesterdayResult, error: yesterdayError } = await supabase
            .rpc('process_daily_yield_with_cycles', {
                p_date: yesterday,
                p_yield_rate: 0.015,
                p_margin_rate: 30,
                p_is_test_mode: true,
                p_is_month_end: false
            });
        
        if (yesterdayError) {
            console.error('Error calling process_daily_yield_with_cycles for yesterday:', yesterdayError);
        } else {
            console.log('昨日の日利処理結果:');
            console.log(`- 処理対象ユーザー: ${yesterdayResult.affected_users}人`);
            console.log(`- 配布予定日利総額: $${yesterdayResult.total_distributed.toFixed(2)}`);
            console.log(`- 自動NFT購入: ${yesterdayResult.auto_purchases}件`);
            console.log(`- 処理ステータス: ${yesterdayResult.status}`);
        }
    } catch (err) {
        console.error('Exception calling process_daily_yield_with_cycles for yesterday:', err);
    }
    
    // 4. 実際の日利処理を実行（警告付き）
    console.log('\n4. 実際の日利処理実行の確認');
    console.log('注意: 実際の日利処理は本番環境に影響を与えるため、ここではテストモードのみ実行します。');
    console.log('本番実行が必要な場合は、管理者画面の日利設定ページから実行してください。');
    
    // 5. 利用可能な他のRPC関数を確認
    console.log('\n5. 利用可能な関数の確認');
    const rpcFunctions = [
        'create_withdrawal_request',
        'process_withdrawal_request',
        'log_system_event',
        'execute_daily_batch'
    ];
    
    for (const func of rpcFunctions) {
        try {
            console.log(`\n関数: ${func}`);
            // 関数の存在確認のため、無効なパラメータで呼び出し
            const { data, error } = await supabase.rpc(func, {});
            
            if (error) {
                if (error.code === '42883') {
                    console.log(`- 関数が存在しません`);
                } else {
                    console.log(`- 関数は存在します（パラメータエラー: ${error.message}）`);
                }
            } else {
                console.log(`- 関数は存在し、空パラメータでも動作しました`);
            }
        } catch (err) {
            console.log(`- 関数確認エラー: ${err.message}`);
        }
    }
    
    // 6. 日利処理の実行履歴を確認
    console.log('\n6. 自動バッチ処理の実行');
    try {
        const today = new Date().toISOString().split('T')[0];
        const { data: batchResult, error: batchError } = await supabase
            .rpc('execute_daily_batch', {
                p_date: today,
                p_default_yield_rate: 0.015,
                p_default_margin_rate: 30
            });
        
        if (batchError) {
            console.error('Error calling execute_daily_batch:', batchError);
        } else {
            console.log('自動バッチ処理結果:');
            console.log(`- 実行ステータス: ${batchResult.status}`);
            console.log(`- 実行メッセージ: ${batchResult.message}`);
            if (batchResult.details) {
                console.log(`- 詳細: ${JSON.stringify(batchResult.details)}`);
            }
        }
    } catch (err) {
        console.error('Exception calling execute_daily_batch:', err);
    }
}

rpcBasedInvestigation().catch(console.error);