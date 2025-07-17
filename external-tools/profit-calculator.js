#!/usr/bin/env node

/**
 * 🚨 HASHPILOT 緊急利益計算ツール
 * 本番環境での正確な利益表示のための外部ツール
 * SQLを使わず、直接データベースから計算
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase設定（本番環境）
const config = require('./config.js');
const SUPABASE_URL = process.env.SUPABASE_URL || config.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || config.SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

class ProfitCalculator {
    constructor() {
        this.userId = null;
        this.userNFTCount = 0;
        this.referralTree = {
            level1: [],
            level2: [],
            level3: []
        };
        this.dailyYieldSettings = {};
    }

    /**
     * 🔍 ユーザーの基本情報を取得
     */
    async getUserBasicInfo(userId) {
        try {
            const { data: userData, error: userError } = await supabase
                .from('users')
                .select('user_id, total_purchases')
                .eq('user_id', userId)
                .single();

            if (userError) throw userError;

            const { data: cycleData, error: cycleError } = await supabase
                .from('affiliate_cycle')
                .select('total_nft_count, cum_usdt, available_usdt')
                .eq('user_id', userId)
                .single();

            if (cycleError) throw cycleError;

            return {
                userId: userData.user_id,
                totalPurchases: parseFloat(userData.total_purchases),
                nftCount: cycleData.total_nft_count,
                cumUsdt: parseFloat(cycleData.cum_usdt),
                availableUsdt: parseFloat(cycleData.available_usdt)
            };
        } catch (error) {
            console.error('❌ ユーザー基本情報取得エラー:', error);
            throw error;
        }
    }

    /**
     * 🌳 紹介ツリーを構築
     */
    async buildReferralTree(userId) {
        try {
            // Level1: 直接紹介者
            const { data: level1Users, error: l1Error } = await supabase
                .from('users')
                .select('user_id, total_purchases')
                .eq('referrer_user_id', userId);

            if (l1Error) throw l1Error;

            this.referralTree.level1 = level1Users || [];

            // Level2: Level1の紹介者
            if (level1Users && level1Users.length > 0) {
                const level1Ids = level1Users.map(u => u.user_id);
                const { data: level2Users, error: l2Error } = await supabase
                    .from('users')
                    .select('user_id, total_purchases, referrer_user_id')
                    .in('referrer_user_id', level1Ids);

                if (l2Error) throw l2Error;
                this.referralTree.level2 = level2Users || [];

                // Level3: Level2の紹介者
                if (level2Users && level2Users.length > 0) {
                    const level2Ids = level2Users.map(u => u.user_id);
                    const { data: level3Users, error: l3Error } = await supabase
                        .from('users')
                        .select('user_id, total_purchases, referrer_user_id')
                        .in('referrer_user_id', level2Ids);

                    if (l3Error) throw l3Error;
                    this.referralTree.level3 = level3Users || [];
                }
            }

            console.log('✅ 紹介ツリー構築完了:');
            console.log(`  Level1: ${this.referralTree.level1.length}名`);
            console.log(`  Level2: ${this.referralTree.level2.length}名`);
            console.log(`  Level3: ${this.referralTree.level3.length}名`);

            return this.referralTree;
        } catch (error) {
            console.error('❌ 紹介ツリー構築エラー:', error);
            throw error;
        }
    }

    /**
     * 📊 日利設定を取得
     */
    async getDailyYieldSettings() {
        try {
            const { data: yieldData, error } = await supabase
                .from('daily_yield_log')
                .select('date, yield_rate, margin_rate, user_rate')
                .order('date', { ascending: false })
                .limit(30);

            if (error) throw error;

            this.dailyYieldSettings = {};
            yieldData.forEach(row => {
                this.dailyYieldSettings[row.date] = {
                    yieldRate: parseFloat(row.yield_rate),
                    marginRate: parseFloat(row.margin_rate),
                    userRate: parseFloat(row.user_rate)
                };
            });

            console.log(`✅ 日利設定取得: ${Object.keys(this.dailyYieldSettings).length}日分`);
            return this.dailyYieldSettings;
        } catch (error) {
            console.error('❌ 日利設定取得エラー:', error);
            throw error;
        }
    }

    /**
     * 🔢 個人利益を計算
     */
    calculatePersonalProfit(nftCount, date) {
        const setting = this.dailyYieldSettings[date];
        if (!setting) return 0;

        const baseAmount = nftCount * 1000; // NFT1個 = $1000運用
        const dailyProfit = baseAmount * setting.userRate;
        
        return {
            baseAmount,
            dailyProfit,
            yieldRate: setting.yieldRate,
            userRate: setting.userRate
        };
    }

    /**
     * 🎯 紹介報酬を計算
     */
    async calculateReferralProfits(date) {
        try {
            const referralProfits = {
                level1: { yesterday: 0, monthly: 0, users: [] },
                level2: { yesterday: 0, monthly: 0, users: [] },
                level3: { yesterday: 0, monthly: 0, users: [] }
            };

            // 各レベルの紹介者の利益を計算
            for (const [level, users] of Object.entries(this.referralTree)) {
                const levelNum = parseInt(level.replace('level', ''));
                const commissionRate = levelNum === 1 ? 0.20 : levelNum === 2 ? 0.10 : 0.05;

                for (const user of users) {
                    // ユーザーのNFT数を取得
                    const { data: cycleData, error } = await supabase
                        .from('affiliate_cycle')
                        .select('total_nft_count')
                        .eq('user_id', user.user_id)
                        .single();

                    if (error || !cycleData) continue;

                    const nftCount = cycleData.total_nft_count;
                    if (nftCount === 0) continue;

                    // NFT承認日と運用開始日確認
                    const { data: purchaseData, error: purchaseError } = await supabase
                        .from('purchases')
                        .select('admin_approved_at')
                        .eq('user_id', user.user_id)
                        .eq('admin_approved', true)
                        .order('admin_approved_at', { ascending: true })
                        .limit(1);

                    if (purchaseError || !purchaseData || purchaseData.length === 0) continue;

                    const approvedDate = new Date(purchaseData[0].admin_approved_at);
                    const operationStartDate = new Date(approvedDate);
                    operationStartDate.setDate(operationStartDate.getDate() + 15);

                    const targetDate = new Date(date);
                    if (operationStartDate > targetDate) continue; // 運用開始前

                    // 個人利益を計算
                    const personalProfit = this.calculatePersonalProfit(nftCount, date);
                    const referralReward = personalProfit.dailyProfit * commissionRate;

                    referralProfits[level].yesterday += referralReward;
                    referralProfits[level].users.push({
                        userId: user.user_id,
                        nftCount,
                        personalProfit: personalProfit.dailyProfit,
                        referralReward,
                        commissionRate
                    });
                }
            }

            return referralProfits;
        } catch (error) {
            console.error('❌ 紹介報酬計算エラー:', error);
            throw error;
        }
    }

    /**
     * 📅 月間利益を計算
     */
    async calculateMonthlyProfits(userId, year, month) {
        try {
            const monthStart = `${year}-${month.toString().padStart(2, '0')}-01`;
            const monthEnd = new Date(year, month, 0).toISOString().split('T')[0];

            let totalPersonal = 0;
            let totalReferral = { level1: 0, level2: 0, level3: 0 };

            // 各日の利益を計算
            for (const [date, setting] of Object.entries(this.dailyYieldSettings)) {
                if (date >= monthStart && date <= monthEnd) {
                    // 個人利益
                    const userInfo = await this.getUserBasicInfo(userId);
                    const personalProfit = this.calculatePersonalProfit(userInfo.nftCount, date);
                    totalPersonal += personalProfit.dailyProfit;

                    // 紹介報酬
                    const referralProfits = await this.calculateReferralProfits(date);
                    totalReferral.level1 += referralProfits.level1.yesterday;
                    totalReferral.level2 += referralProfits.level2.yesterday;
                    totalReferral.level3 += referralProfits.level3.yesterday;
                }
            }

            return { totalPersonal, totalReferral };
        } catch (error) {
            console.error('❌ 月間利益計算エラー:', error);
            throw error;
        }
    }

    /**
     * 🎯 メイン計算実行
     */
    async calculateAll(userId, targetDate = null) {
        try {
            console.log(`🚀 利益計算開始: ユーザー ${userId}`);
            
            // 昨日の日付（targetDateが指定されていない場合）
            const yesterday = targetDate || new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayStr = yesterday.toISOString().split('T')[0];

            this.userId = userId;

            // 1. ユーザー基本情報取得
            const userInfo = await this.getUserBasicInfo(userId);
            console.log(`💰 投資額: $${userInfo.totalPurchases}, NFT: ${userInfo.nftCount}個`);

            // 2. 紹介ツリー構築
            await this.buildReferralTree(userId);

            // 3. 日利設定取得
            await this.getDailyYieldSettings();

            // 4. 昨日の個人利益計算
            const personalProfit = this.calculatePersonalProfit(userInfo.nftCount, yesterdayStr);
            console.log(`📊 昨日の個人利益: $${personalProfit.dailyProfit.toFixed(3)}`);

            // 5. 昨日の紹介報酬計算
            const referralProfits = await this.calculateReferralProfits(yesterdayStr);
            console.log('🎯 昨日の紹介報酬:');
            console.log(`  Level1 (20%): $${referralProfits.level1.yesterday.toFixed(3)}`);
            console.log(`  Level2 (10%): $${referralProfits.level2.yesterday.toFixed(3)}`);
            console.log(`  Level3 (5%):  $${referralProfits.level3.yesterday.toFixed(3)}`);

            // 6. 今月の累計計算
            const currentMonth = new Date().getMonth() + 1;
            const currentYear = new Date().getFullYear();
            const monthlyProfits = await this.calculateMonthlyProfits(userId, currentYear, currentMonth);

            // 7. 結果出力
            const results = {
                userId,
                userInfo,
                yesterday: {
                    date: yesterdayStr,
                    personal: personalProfit.dailyProfit,
                    referral: {
                        level1: referralProfits.level1.yesterday,
                        level2: referralProfits.level2.yesterday,
                        level3: referralProfits.level3.yesterday,
                        total: referralProfits.level1.yesterday + referralProfits.level2.yesterday + referralProfits.level3.yesterday
                    },
                    total: personalProfit.dailyProfit + referralProfits.level1.yesterday + referralProfits.level2.yesterday + referralProfits.level3.yesterday
                },
                monthly: {
                    personal: monthlyProfits.totalPersonal,
                    referral: monthlyProfits.totalReferral,
                    total: monthlyProfits.totalPersonal + monthlyProfits.totalReferral.level1 + monthlyProfits.totalReferral.level2 + monthlyProfits.totalReferral.level3
                },
                referralTree: this.referralTree,
                detailedReferrals: referralProfits
            };

            console.log('\n✅ 計算完了 - 結果サマリー:');
            console.log(`昨日合計: $${results.yesterday.total.toFixed(3)}`);
            console.log(`今月合計: $${results.monthly.total.toFixed(3)}`);

            return results;

        } catch (error) {
            console.error('❌ 計算処理エラー:', error);
            throw error;
        }
    }
}

// CLI実行
async function main() {
    const userId = process.argv[2] || '7A9637';
    const targetDate = process.argv[3] || null;

    console.log('🚨 HASHPILOT 緊急利益計算ツール 🚨');
    console.log('=====================================\n');

    try {
        const calculator = new ProfitCalculator();
        const results = await calculator.calculateAll(userId, targetDate);
        
        console.log('\n📋 JSON出力:');
        console.log(JSON.stringify(results, null, 2));
        
    } catch (error) {
        console.error('💥 実行エラー:', error);
        process.exit(1);
    }
}

// モジュールとしても使用可能
if (require.main === module) {
    main();
}

module.exports = ProfitCalculator;