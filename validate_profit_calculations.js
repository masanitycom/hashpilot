#!/usr/bin/env node

/**
 * 紹介報酬の実際の計算検証ツール
 * 
 * 検証項目:
 * 1. 個人利益データの取得
 * 2. 紹介報酬計算（個人利益 × 報酬率）
 * 3. user_daily_profitテーブルとの照合
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase設定
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

class ProfitValidationTool {
    constructor(targetUserId = '7A9637') {
        this.targetUserId = targetUserId;
    }

    async validateProfitCalculations() {
        console.log(`💰 利益計算検証開始: ユーザー ${this.targetUserId}`);
        console.log('================================================\n');

        try {
            // 昨日の日付を取得
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayStr = yesterday.toISOString().split('T')[0];
            
            console.log(`📅 対象日: ${yesterdayStr}`);

            // 1. Level1の紹介者の個人利益を確認
            await this.checkLevel1PersonalProfits(yesterdayStr);

            // 2. Level2の紹介者の個人利益を確認  
            await this.checkLevel2PersonalProfits(yesterdayStr);

            // 3. Level3の紹介者の個人利益を確認
            await this.checkLevel3PersonalProfits(yesterdayStr);

            // 4. 実際の紹介報酬計算のシミュレーション
            await this.simulateReferralRewards(yesterdayStr);

        } catch (error) {
            console.error('❌ 検証エラー:', error);
            throw error;
        }
    }

    async checkLevel1PersonalProfits(date) {
        console.log('\n📊 Level1紹介者の個人利益確認...');
        
        const { data: level1Users } = await supabase
            .from('users')
            .select('user_id, email, has_approved_nft')
            .eq('referrer_user_id', this.targetUserId);

        let totalLevel1PersonalProfit = 0;

        for (const user of level1Users || []) {
            if (!user.has_approved_nft) continue;

            // 個人利益データを取得
            const { data: profitData, error: profitError } = await supabase
                .from('user_daily_profit')
                .select('daily_profit')
                .eq('user_id', user.user_id)
                .eq('date', date)
                .single();

            const personalProfit = profitData?.daily_profit || 0;
            totalLevel1PersonalProfit += personalProfit;

            console.log(`   ${user.user_id} (${user.email}): 個人利益 $${personalProfit}`);
        }

        const level1ReferralReward = totalLevel1PersonalProfit * 0.20; // 20%
        console.log(`   Level1合計個人利益: $${totalLevel1PersonalProfit}`);
        console.log(`   Level1紹介報酬(20%): $${level1ReferralReward.toFixed(6)}`);
        
        return { totalPersonalProfit: totalLevel1PersonalProfit, referralReward: level1ReferralReward };
    }

    async checkLevel2PersonalProfits(date) {
        console.log('\n📊 Level2紹介者の個人利益確認...');
        
        // Level1のユーザーIDを取得
        const { data: level1Users } = await supabase
            .from('users')
            .select('user_id')
            .eq('referrer_user_id', this.targetUserId)
            .eq('has_approved_nft', true);

        if (!level1Users || level1Users.length === 0) {
            console.log('   Level1ユーザーが存在しません');
            return { totalPersonalProfit: 0, referralReward: 0 };
        }

        const level1UserIds = level1Users.map(u => u.user_id);

        const { data: level2Users } = await supabase
            .from('users')
            .select('user_id, email, has_approved_nft')
            .in('referrer_user_id', level1UserIds);

        let totalLevel2PersonalProfit = 0;

        for (const user of level2Users || []) {
            if (!user.has_approved_nft) continue;

            const { data: profitData } = await supabase
                .from('user_daily_profit')
                .select('daily_profit')
                .eq('user_id', user.user_id)
                .eq('date', date)
                .single();

            const personalProfit = profitData?.daily_profit || 0;
            totalLevel2PersonalProfit += personalProfit;

            console.log(`   ${user.user_id} (${user.email}): 個人利益 $${personalProfit}`);
        }

        const level2ReferralReward = totalLevel2PersonalProfit * 0.10; // 10%
        console.log(`   Level2合計個人利益: $${totalLevel2PersonalProfit}`);
        console.log(`   Level2紹介報酬(10%): $${level2ReferralReward.toFixed(6)}`);
        
        return { totalPersonalProfit: totalLevel2PersonalProfit, referralReward: level2ReferralReward };
    }

    async checkLevel3PersonalProfits(date) {
        console.log('\n📊 Level3紹介者の個人利益確認...');
        
        // Level1, Level2のユーザーIDを取得
        const { data: level1Users } = await supabase
            .from('users')
            .select('user_id')
            .eq('referrer_user_id', this.targetUserId)
            .eq('has_approved_nft', true);

        if (!level1Users || level1Users.length === 0) {
            console.log('   Level1ユーザーが存在しません');
            return { totalPersonalProfit: 0, referralReward: 0 };
        }

        const level1UserIds = level1Users.map(u => u.user_id);

        const { data: level2Users } = await supabase
            .from('users')
            .select('user_id')
            .in('referrer_user_id', level1UserIds)
            .eq('has_approved_nft', true);

        if (!level2Users || level2Users.length === 0) {
            console.log('   Level2ユーザーが存在しません');
            return { totalPersonalProfit: 0, referralReward: 0 };
        }

        const level2UserIds = level2Users.map(u => u.user_id);

        const { data: level3Users } = await supabase
            .from('users')
            .select('user_id, email, has_approved_nft')
            .in('referrer_user_id', level2UserIds);

        let totalLevel3PersonalProfit = 0;

        for (const user of level3Users || []) {
            if (!user.has_approved_nft) continue;

            const { data: profitData } = await supabase
                .from('user_daily_profit')
                .select('daily_profit')
                .eq('user_id', user.user_id)
                .eq('date', date)
                .single();

            const personalProfit = profitData?.daily_profit || 0;
            totalLevel3PersonalProfit += personalProfit;

            console.log(`   ${user.user_id} (${user.email}): 個人利益 $${personalProfit}`);
        }

        const level3ReferralReward = totalLevel3PersonalProfit * 0.05; // 5%
        console.log(`   Level3合計個人利益: $${totalLevel3PersonalProfit}`);
        console.log(`   Level3紹介報酬(5%): $${level3ReferralReward.toFixed(6)}`);
        
        return { totalPersonalProfit: totalLevel3PersonalProfit, referralReward: level3ReferralReward };
    }

    async simulateReferralRewards(date) {
        console.log('\n🎯 紹介報酬計算シミュレーション...');
        
        const level1Result = await this.checkLevel1PersonalProfits(date);
        const level2Result = await this.checkLevel2PersonalProfits(date);
        const level3Result = await this.checkLevel3PersonalProfits(date);

        const totalReferralReward = level1Result.referralReward + level2Result.referralReward + level3Result.referralReward;

        console.log('\n📋 紹介報酬計算結果サマリー:');
        console.log(`   Level1紹介報酬: $${level1Result.referralReward.toFixed(6)}`);
        console.log(`   Level2紹介報酬: $${level2Result.referralReward.toFixed(6)}`);
        console.log(`   Level3紹介報酬: $${level3Result.referralReward.toFixed(6)}`);
        console.log(`   合計紹介報酬: $${totalReferralReward.toFixed(6)}`);

        // 計算ロジックの確認
        console.log('\n🧮 計算ロジック確認:');
        console.log('   1. 各レベルの紹介者の個人利益を合計');
        console.log('   2. 合計利益に報酬率を適用（L1:20%, L2:10%, L3:5%）');
        console.log('   3. has_approved_nft = true のユーザーのみ対象');
        console.log('   4. user_daily_profitテーブルから個人利益を取得');

        // 実際のReferralProfitCardの計算と比較するため、今月のデータも確認
        await this.checkMonthlyData();
    }

    async checkMonthlyData() {
        console.log('\n📅 今月のデータ確認...');
        
        const now = new Date();
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
        const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0];

        console.log(`   対象期間: ${monthStart} 〜 ${monthEnd}`);

        // Level1の今月累計
        const { data: level1Users } = await supabase
            .from('users')
            .select('user_id')
            .eq('referrer_user_id', this.targetUserId)
            .eq('has_approved_nft', true);

        if (level1Users && level1Users.length > 0) {
            const level1UserIds = level1Users.map(u => u.user_id);
            
            const { data: level1Profits } = await supabase
                .from('user_daily_profit')
                .select('daily_profit')
                .in('user_id', level1UserIds)
                .gte('date', monthStart)
                .lte('date', monthEnd);

            const totalLevel1Monthly = level1Profits?.reduce((sum, row) => sum + parseFloat(row.daily_profit || 0), 0) || 0;
            const level1MonthlyReward = totalLevel1Monthly * 0.20;

            console.log(`   Level1今月累計個人利益: $${totalLevel1Monthly.toFixed(6)}`);
            console.log(`   Level1今月累計紹介報酬: $${level1MonthlyReward.toFixed(6)}`);
        }
    }
}

// CLI実行
async function main() {
    const userId = process.argv[2] || '7A9637';
    
    console.log('💰 HASHPILOT 利益計算検証ツール');
    console.log('===============================\n');
    
    try {
        const validator = new ProfitValidationTool(userId);
        await validator.validateProfitCalculations();
        
        console.log('\n✅ 検証完了');
        
    } catch (error) {
        console.error('💥 検証エラー:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = ProfitValidationTool;