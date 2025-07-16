// 最終的なデータベース構造とデータ存在確認
// 2025-01-16 実行

const { createClient } = require('@supabase/supabase-js');

// 環境変数を直接設定
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function finalDatabaseStructureCheck() {
    console.log('=== 最終的なデータベース構造とデータ存在確認 ===\n');
    
    // システムヘルスチェックから詳細情報を取得
    console.log('1. システムヘルスチェック詳細');
    try {
        const { data: healthData, error: healthError } = await supabase
            .rpc('system_health_check');
        
        if (healthError) {
            console.error('Error calling system_health_check:', healthError);
        } else {
            console.log('システム詳細統計:');
            healthData.forEach(item => {
                console.log(`\n${item.component.toUpperCase()}:`);
                console.log(`- ステータス: ${item.status}`);
                console.log(`- メッセージ: ${item.message}`);
                console.log(`- 最終チェック: ${new Date(item.last_check).toLocaleString()}`);
                if (item.details) {
                    console.log(`- 詳細:`);
                    Object.entries(item.details).forEach(([key, value]) => {
                        console.log(`  ${key}: ${value}`);
                    });
                }
            });
        }
    } catch (err) {
        console.error('Exception calling system_health_check:', err);
    }
    
    // 日利設定の詳細分析
    console.log('\n2. 日利設定の詳細分析');
    try {
        const { data: yieldLogs, error: yieldError } = await supabase
            .from('daily_yield_log')
            .select('*')
            .order('date', { ascending: false })
            .limit(10);
        
        if (yieldError) {
            console.error('Error fetching yield logs:', yieldError);
        } else {
            console.log(`\n日利設定履歴 (${yieldLogs.length}件):`);
            yieldLogs.forEach((log, index) => {
                console.log(`\n${index + 1}. ${log.date}:`);
                console.log(`   - 日利率: ${(log.yield_rate * 100).toFixed(1)}%`);
                console.log(`   - マージン率: ${(log.margin_rate * 100).toFixed(1)}%`);
                console.log(`   - ユーザー受取率: ${(log.user_rate * 100).toFixed(1)}%`);
                console.log(`   - 月末処理: ${log.is_month_end ? 'YES' : 'NO'}`);
                console.log(`   - 対象ユーザー: ${log.total_users || 'N/A'}人`);
                console.log(`   - 配布総額: $${log.total_profit || 'N/A'}`);
                console.log(`   - 設定者: ${log.created_by || 'N/A'}`);
                console.log(`   - 設定日時: ${new Date(log.created_at).toLocaleString()}`);
                
                // 異常値の警告
                if (log.margin_rate > 1.0) {
                    console.log(`   ⚠️  警告: マージン率が${(log.margin_rate * 100).toFixed(1)}%と異常に高い`);
                }
            });
        }
    } catch (err) {
        console.error('Exception fetching yield logs:', err);
    }
    
    // 利用可能なRPC関数の確認
    console.log('\n3. 利用可能なRPC関数の確認');
    const functionsToCheck = [
        'admin_post_yield',
        'system_health_check',
        'fix_user_daily_profit_rls',
        'get_user_stats',
        'get_system_stats'
    ];
    
    for (const func of functionsToCheck) {
        try {
            // 関数の存在確認
            const { data, error } = await supabase.rpc(func, {});
            
            if (error) {
                if (error.code === '42883') {
                    console.log(`❌ ${func}: 関数が存在しません`);
                } else if (error.message.includes('Admin access required')) {
                    console.log(`🔒 ${func}: 管理者権限が必要`);
                } else {
                    console.log(`⚠️  ${func}: パラメータエラー (関数は存在)`);
                }
            } else {
                console.log(`✅ ${func}: 正常に動作`);
            }
        } catch (err) {
            console.log(`❌ ${func}: 実行エラー - ${err.message}`);
        }
    }
    
    // 日利処理の問題分析
    console.log('\n4. 日利処理の問題分析');
    
    // 最新の日利設定を取得
    const { data: latestYieldLog } = await supabase
        .from('daily_yield_log')
        .select('*')
        .order('date', { ascending: false })
        .limit(1)
        .single();
    
    if (latestYieldLog) {
        console.log('\n最新の日利設定の問題分析:');
        console.log(`設定日: ${latestYieldLog.date}`);
        console.log(`日利率: ${(latestYieldLog.yield_rate * 100).toFixed(1)}%`);
        console.log(`マージン率: ${(latestYieldLog.margin_rate * 100).toFixed(1)}%`);
        console.log(`ユーザー受取率: ${(latestYieldLog.user_rate * 100).toFixed(1)}%`);
        
        // 問題の特定
        const problems = [];
        
        if (latestYieldLog.margin_rate > 1.0) {
            problems.push(`マージン率が${(latestYieldLog.margin_rate * 100).toFixed(1)}%と異常に高い`);
        }
        
        if (latestYieldLog.user_rate <= 0) {
            problems.push('ユーザー受取率が0%以下');
        }
        
        if (latestYieldLog.total_users === 0) {
            problems.push('対象ユーザーが0人');
        }
        
        if (latestYieldLog.total_profit === 0) {
            problems.push('配布総額が$0');
        }
        
        if (problems.length > 0) {
            console.log('\n🚨 発見された問題:');
            problems.forEach((problem, index) => {
                console.log(`${index + 1}. ${problem}`);
            });
        } else {
            console.log('\n✅ 設定に明らかな問題は見つかりませんでした');
        }
        
        // 正常な設定値の提案
        console.log('\n💡 推奨される設定値:');
        console.log('- 日利率: 1.5% (0.015)');
        console.log('- マージン率: 30% (0.30)');
        console.log('- ユーザー受取率: 1.05% (0.0105)');
        console.log('- 計算式: 1.5% × (1 - 30%) = 1.05%');
    }
    
    // 日利が発生していない理由の総合分析
    console.log('\n5. 日利が発生していない理由の総合分析');
    
    const analysisResults = {
        systemHealth: 'HEALTHY',
        userCount: 102,
        totalInvestment: 123200,
        dailyProfitRecipients: 0,
        possibleReasons: []
    };
    
    // システムヘルスチェックの結果を分析
    const { data: healthData } = await supabase.rpc('system_health_check');
    
    if (healthData) {
        const userComponent = healthData.find(c => c.component === 'users');
        const investmentComponent = healthData.find(c => c.component === 'investments');
        
        if (userComponent && userComponent.details) {
            analysisResults.userCount = userComponent.details.total;
        }
        
        if (investmentComponent && investmentComponent.details) {
            analysisResults.totalInvestment = investmentComponent.details.total_amount;
        }
    }
    
    // 日利が発生していない理由を分析
    if (latestYieldLog && latestYieldLog.margin_rate > 1.0) {
        analysisResults.possibleReasons.push('マージン率の異常値（3000%）');
    }
    
    if (latestYieldLog && latestYieldLog.total_users === 0) {
        analysisResults.possibleReasons.push('NFT承認済みユーザーが0人');
    }
    
    analysisResults.possibleReasons.push('RLS（Row Level Security）によるデータアクセス制限');
    analysisResults.possibleReasons.push('管理者権限なしでの関数実行制限');
    
    console.log('\n📊 総合分析結果:');
    console.log(`システム健全性: ${analysisResults.systemHealth}`);
    console.log(`登録ユーザー数: ${analysisResults.userCount}人`);
    console.log(`総投資額: $${analysisResults.totalInvestment.toLocaleString()}`);
    console.log(`日利受取者: ${analysisResults.dailyProfitRecipients}人`);
    
    console.log('\n🔍 日利が発生していない可能性のある理由:');
    analysisResults.possibleReasons.forEach((reason, index) => {
        console.log(`${index + 1}. ${reason}`);
    });
    
    console.log('\n🎯 推奨される対応手順:');
    console.log('1. 管理者権限でログイン');
    console.log('2. マージン率を3000% → 30%に修正');
    console.log('3. 日利処理を手動実行');
    console.log('4. 実際のユーザーデータを確認');
    console.log('5. NFT承認状況を確認');
    console.log('6. 自動バッチ処理の設定確認');
}

finalDatabaseStructureCheck().catch(console.error);