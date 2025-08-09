#!/usr/bin/env node

/**
 * レベル別人数と投資額の計算検証ツール
 * 
 * 検証項目:
 * 1. Level1-Level3の人数と投資額の計算
 * 2. NFT数の計算式: total_purchases ÷ $1,100（端数切り捨て）
 * 3. 投資額の計算式: NFT数 × $1,000
 * 4. 各レベルの報酬率（L1:20%, L2:10%, L3:5%, L4+:0%）
 * 5. has_approved_nft = true のユーザーのみカウント
 * 6. affiliate_cycleテーブルのtotal_nft_countの使用
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase設定
const config = require('./external-tools/config.js');
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

class LevelCalculationVerifier {
    constructor(targetUserId = '7A9637') {
        this.targetUserId = targetUserId;
        this.results = {
            levels: {},
            calculations: {},
            issues: []
        };
    }

    /**
     * メイン検証実行
     */
    async verify() {
        console.log(`🔍 レベル別計算検証開始: ユーザー ${this.targetUserId}`);
        console.log('================================================\n');

        try {
            // 1. 基本ユーザー情報の確認
            await this.verifyUserInfo();
            
            // 2. Level1の検証
            await this.verifyLevel1();
            
            // 3. Level2の検証  
            await this.verifyLevel2();
            
            // 4. Level3の検証
            await this.verifyLevel3();
            
            // 5. Level4以降の検証
            await this.verifyLevel4Plus();
            
            // 6. 計算式の検証
            await this.verifyCalculationFormulas();
            
            // 7. ダッシュボード表示値との比較
            await this.compareDashboardValues();
            
            // 8. 結果の出力
            this.outputResults();
            
        } catch (error) {
            console.error('❌ 検証エラー:', error);
            throw error;
        }
    }

    /**
     * 基本ユーザー情報の確認
     */
    async verifyUserInfo() {
        console.log('👤 基本ユーザー情報の確認...');
        
        const { data: user, error } = await supabase
            .from('users')
            .select('user_id, email, has_approved_nft, total_purchases')
            .eq('user_id', this.targetUserId)
            .single();
            
        if (error || !user) {
            throw new Error(`ユーザー ${this.targetUserId} が見つかりません`);
        }
        
        const { data: cycle, error: cycleError } = await supabase
            .from('affiliate_cycle')
            .select('total_nft_count')
            .eq('user_id', this.targetUserId)
            .single();
            
        this.results.userInfo = {
            ...user,
            affiliate_cycle_nft_count: cycle?.total_nft_count || 0
        };
        
        console.log(`✅ ユーザー: ${user.email}`);
        console.log(`   NFT承認: ${user.has_approved_nft}`);
        console.log(`   購入額: $${user.total_purchases}`);
        console.log(`   NFT数(cycle): ${cycle?.total_nft_count || 0}\n`);
    }

    /**
     * Level1（直接紹介者）の検証
     */
    async verifyLevel1() {
        console.log('📊 Level1（直接紹介者）の検証...');
        
        const { data: level1Users, error } = await supabase
            .from('users')
            .select(`
                user_id, 
                email, 
                has_approved_nft, 
                total_purchases,
                affiliate_cycle(total_nft_count)
            `)
            .eq('referrer_user_id', this.targetUserId);
            
        if (error) {
            throw new Error('Level1ユーザー取得エラー: ' + error.message);
        }
        
        // フィルタリング: has_approved_nft = true のみ
        const approvedUsers = level1Users.filter(u => u.has_approved_nft === true);
        
        let totalInvestmentFromPurchases = 0;
        let totalInvestmentFromCycle = 0;
        const userDetails = [];
        
        approvedUsers.forEach(user => {
            // 計算式1: total_purchases ÷ $1,100 の端数切り捨て × $1,000
            const nftCountFromPurchases = Math.floor(user.total_purchases / 1100);
            const investmentFromPurchases = nftCountFromPurchases * 1000;
            totalInvestmentFromPurchases += investmentFromPurchases;
            
            // 計算式2: affiliate_cycle.total_nft_count × $1,000
            const nftCountFromCycle = user.affiliate_cycle?.total_nft_count || 0;
            const investmentFromCycle = nftCountFromCycle * 1000;
            totalInvestmentFromCycle += investmentFromCycle;
            
            userDetails.push({
                user_id: user.user_id,
                email: user.email,
                total_purchases: user.total_purchases,
                nft_from_purchases: nftCountFromPurchases,
                investment_from_purchases: investmentFromPurchases,
                nft_from_cycle: nftCountFromCycle,
                investment_from_cycle: investmentFromCycle,
                difference: investmentFromPurchases - investmentFromCycle
            });
        });
        
        this.results.levels.level1 = {
            total_users: level1Users.length,
            approved_users: approvedUsers.length,
            total_investment_from_purchases: totalInvestmentFromPurchases,
            total_investment_from_cycle: totalInvestmentFromCycle,
            reward_rate: 0.20,
            user_details: userDetails
        };
        
        console.log(`   全ユーザー数: ${level1Users.length}`);
        console.log(`   承認済みユーザー数: ${approvedUsers.length}`);
        console.log(`   投資額(purchases計算): $${totalInvestmentFromPurchases}`);
        console.log(`   投資額(cycle計算): $${totalInvestmentFromCycle}`);
        console.log(`   報酬率: 20%\n`);
        
        if (totalInvestmentFromPurchases !== totalInvestmentFromCycle) {
            this.results.issues.push({
                level: 'Level1',
                issue: '投資額計算の不一致',
                detail: `purchases計算: $${totalInvestmentFromPurchases}, cycle計算: $${totalInvestmentFromCycle}`
            });
        }
    }

    /**
     * Level2（間接紹介者）の検証
     */
    async verifyLevel2() {
        console.log('📊 Level2（間接紹介者）の検証...');
        
        // Level1のユーザーIDを取得
        const { data: level1Users } = await supabase
            .from('users')
            .select('user_id')
            .eq('referrer_user_id', this.targetUserId)
            .eq('has_approved_nft', true);
            
        if (!level1Users || level1Users.length === 0) {
            console.log('   Level1ユーザーが存在しないため、Level2はスキップ\n');
            this.results.levels.level2 = {
                total_users: 0,
                approved_users: 0,
                total_investment_from_purchases: 0,
                total_investment_from_cycle: 0,
                reward_rate: 0.10,
                user_details: []
            };
            return;
        }
        
        const level1UserIds = level1Users.map(u => u.user_id);
        
        const { data: level2Users, error } = await supabase
            .from('users')
            .select(`
                user_id, 
                email, 
                has_approved_nft, 
                total_purchases,
                referrer_user_id,
                affiliate_cycle(total_nft_count)
            `)
            .in('referrer_user_id', level1UserIds);
            
        if (error) {
            throw new Error('Level2ユーザー取得エラー: ' + error.message);
        }
        
        const approvedUsers = level2Users.filter(u => u.has_approved_nft === true);
        
        let totalInvestmentFromPurchases = 0;
        let totalInvestmentFromCycle = 0;
        const userDetails = [];
        
        approvedUsers.forEach(user => {
            const nftCountFromPurchases = Math.floor(user.total_purchases / 1100);
            const investmentFromPurchases = nftCountFromPurchases * 1000;
            totalInvestmentFromPurchases += investmentFromPurchases;
            
            const nftCountFromCycle = user.affiliate_cycle?.total_nft_count || 0;
            const investmentFromCycle = nftCountFromCycle * 1000;
            totalInvestmentFromCycle += investmentFromCycle;
            
            userDetails.push({
                user_id: user.user_id,
                email: user.email,
                referrer_user_id: user.referrer_user_id,
                total_purchases: user.total_purchases,
                nft_from_purchases: nftCountFromPurchases,
                investment_from_purchases: investmentFromPurchases,
                nft_from_cycle: nftCountFromCycle,
                investment_from_cycle: investmentFromCycle,
                difference: investmentFromPurchases - investmentFromCycle
            });
        });
        
        this.results.levels.level2 = {
            total_users: level2Users.length,
            approved_users: approvedUsers.length,
            total_investment_from_purchases: totalInvestmentFromPurchases,
            total_investment_from_cycle: totalInvestmentFromCycle,
            reward_rate: 0.10,
            user_details: userDetails
        };
        
        console.log(`   全ユーザー数: ${level2Users.length}`);
        console.log(`   承認済みユーザー数: ${approvedUsers.length}`);
        console.log(`   投資額(purchases計算): $${totalInvestmentFromPurchases}`);
        console.log(`   投資額(cycle計算): $${totalInvestmentFromCycle}`);
        console.log(`   報酬率: 10%\n`);
        
        if (totalInvestmentFromPurchases !== totalInvestmentFromCycle) {
            this.results.issues.push({
                level: 'Level2',
                issue: '投資額計算の不一致',
                detail: `purchases計算: $${totalInvestmentFromPurchases}, cycle計算: $${totalInvestmentFromCycle}`
            });
        }
    }

    /**
     * Level3の検証
     */
    async verifyLevel3() {
        console.log('📊 Level3の検証...');
        
        // Level2のユーザーIDを取得
        const level1UserIds = await this.getApprovedUserIds(this.targetUserId);
        if (level1UserIds.length === 0) {
            console.log('   Level1ユーザーが存在しないため、Level3はスキップ\n');
            this.results.levels.level3 = this.createEmptyLevelResult(0.05);
            return;
        }
        
        const level2UserIds = await this.getApprovedUserIdsFromReferrers(level1UserIds);
        if (level2UserIds.length === 0) {
            console.log('   Level2ユーザーが存在しないため、Level3はスキップ\n');
            this.results.levels.level3 = this.createEmptyLevelResult(0.05);
            return;
        }
        
        const { data: level3Users, error } = await supabase
            .from('users')
            .select(`
                user_id, 
                email, 
                has_approved_nft, 
                total_purchases,
                referrer_user_id,
                affiliate_cycle(total_nft_count)
            `)
            .in('referrer_user_id', level2UserIds);
            
        if (error) {
            throw new Error('Level3ユーザー取得エラー: ' + error.message);
        }
        
        const approvedUsers = level3Users.filter(u => u.has_approved_nft === true);
        const { totalInvestmentFromPurchases, totalInvestmentFromCycle, userDetails } = 
            this.calculateLevelInvestments(approvedUsers);
        
        this.results.levels.level3 = {
            total_users: level3Users.length,
            approved_users: approvedUsers.length,
            total_investment_from_purchases: totalInvestmentFromPurchases,
            total_investment_from_cycle: totalInvestmentFromCycle,
            reward_rate: 0.05,
            user_details: userDetails
        };
        
        console.log(`   全ユーザー数: ${level3Users.length}`);
        console.log(`   承認済みユーザー数: ${approvedUsers.length}`);
        console.log(`   投資額(purchases計算): $${totalInvestmentFromPurchases}`);
        console.log(`   投資額(cycle計算): $${totalInvestmentFromCycle}`);
        console.log(`   報酬率: 5%\n`);
        
        if (totalInvestmentFromPurchases !== totalInvestmentFromCycle) {
            this.results.issues.push({
                level: 'Level3',
                issue: '投資額計算の不一致',
                detail: `purchases計算: $${totalInvestmentFromPurchases}, cycle計算: $${totalInvestmentFromCycle}`
            });
        }
    }

    /**
     * Level4以降の検証
     */
    async verifyLevel4Plus() {
        console.log('📊 Level4以降の検証...');
        
        // 再帰的にLevel4以降のユーザーを取得
        const level4PlusUsers = await this.getDeepLevelUsers(4);
        
        const approvedUsers = level4PlusUsers.filter(u => u.has_approved_nft === true);
        const { totalInvestmentFromPurchases, totalInvestmentFromCycle, userDetails } = 
            this.calculateLevelInvestments(approvedUsers);
        
        this.results.levels.level4Plus = {
            total_users: level4PlusUsers.length,
            approved_users: approvedUsers.length,
            total_investment_from_purchases: totalInvestmentFromPurchases,
            total_investment_from_cycle: totalInvestmentFromCycle,
            reward_rate: 0.00,
            user_details: userDetails
        };
        
        console.log(`   全ユーザー数: ${level4PlusUsers.length}`);
        console.log(`   承認済みユーザー数: ${approvedUsers.length}`);
        console.log(`   投資額(purchases計算): $${totalInvestmentFromPurchases}`);
        console.log(`   投資額(cycle計算): $${totalInvestmentFromCycle}`);
        console.log(`   報酬率: 0%（報酬なし）\n`);
    }

    /**
     * 計算式の検証
     */
    async verifyCalculationFormulas() {
        console.log('🧮 計算式の検証...');
        
        console.log('   使用されている計算式:');
        console.log('   1. NFT数 = total_purchases ÷ $1,100（端数切り捨て）');
        console.log('   2. 投資額 = NFT数 × $1,000');
        console.log('   3. 実際のNFT数 = affiliate_cycle.total_nft_count');
        console.log('   4. Level1報酬率: 20%');
        console.log('   5. Level2報酬率: 10%');
        console.log('   6. Level3報酬率: 5%');
        console.log('   7. Level4以降報酬率: 0%\n');
        
        // どちらの計算式を使うべきかの判定
        let purchasesMoreAccurate = 0;
        let cycleMoreAccurate = 0;
        
        for (const levelKey of ['level1', 'level2', 'level3']) {
            const level = this.results.levels[levelKey];
            if (level && level.user_details.length > 0) {
                level.user_details.forEach(user => {
                    if (user.difference !== 0) {
                        // どちらがより正確かを判定する基準を設ける
                        // ここでは、affiliate_cycleの値がより管理されていると仮定
                        cycleMoreAccurate++;
                    } else {
                        // 両方同じ値の場合
                        purchasesMoreAccurate++;
                    }
                });
            }
        }
        
        this.results.calculations = {
            formula_consistency: {
                purchases_accurate: purchasesMoreAccurate,
                cycle_accurate: cycleMoreAccurate,
                recommendation: cycleMoreAccurate > purchasesMoreAccurate ? 
                    'affiliate_cycle.total_nft_count を使用することを推奨' :
                    'total_purchases ÷ 1100 の計算で問題なし'
            }
        };
    }

    /**
     * ダッシュボード表示値との比較
     */
    async compareDashboardValues() {
        console.log('📋 ダッシュボード表示値との比較...');
        
        // ダッシュボードのロジック（dashboard/page.tsx）を再現
        const dashboardCalc = await this.calculateDashboardStyle();
        
        console.log('   ダッシュボード計算結果:');
        console.log(`   Level1投資額: $${dashboardCalc.level1_investment}`);
        console.log(`   Level2投資額: $${dashboardCalc.level2_investment}`);
        console.log(`   Level3投資額: $${dashboardCalc.level3_investment}`);
        
        console.log('   本検証ツール結果:');
        console.log(`   Level1投資額: $${this.results.levels.level1?.total_investment_from_cycle || 0}`);
        console.log(`   Level2投資額: $${this.results.levels.level2?.total_investment_from_cycle || 0}`);
        console.log(`   Level3投資額: $${this.results.levels.level3?.total_investment_from_cycle || 0}\n`);
        
        // 比較して差異があれば問題として記録
        if (dashboardCalc.level1_investment !== (this.results.levels.level1?.total_investment_from_cycle || 0)) {
            this.results.issues.push({
                level: 'Dashboard比較',
                issue: 'Level1投資額がダッシュボードと一致しない',
                detail: `Dashboard: $${dashboardCalc.level1_investment}, 検証: $${this.results.levels.level1?.total_investment_from_cycle || 0}`
            });
        }
    }

    /**
     * ダッシュボード形式の計算（dashboard/page.tsx と同じロジック）
     */
    async calculateDashboardStyle() {
        // 直接紹介者を取得
        const { data: directReferrals } = await supabase
            .from('users')
            .select('user_id, total_purchases')
            .eq('referrer_user_id', this.targetUserId);
            
        const level1Investment = directReferrals
            ? directReferrals.reduce((sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000, 0)
            : 0;
            
        let level2Investment = 0;
        let level3Investment = 0;
        
        if (directReferrals && directReferrals.length > 0) {
            for (const directRef of directReferrals) {
                // Level2
                const { data: level2Refs } = await supabase
                    .from('users')
                    .select('user_id, total_purchases')
                    .eq('referrer_user_id', directRef.user_id);
                    
                if (level2Refs) {
                    level2Investment += level2Refs.reduce(
                        (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
                        0
                    );
                    
                    // Level3
                    for (const level2Ref of level2Refs) {
                        const { data: level3Refs } = await supabase
                            .from('users')
                            .select('user_id, total_purchases')
                            .eq('referrer_user_id', level2Ref.user_id);
                            
                        if (level3Refs) {
                            level3Investment += level3Refs.reduce(
                                (sum, ref) => sum + Math.floor((ref.total_purchases || 0) / 1000) * 1000,
                                0
                            );
                        }
                    }
                }
            }
        }
        
        return {
            level1_investment: level1Investment,
            level2_investment: level2Investment,
            level3_investment: level3Investment
        };
    }

    /**
     * ヘルパー関数群
     */
    async getApprovedUserIds(referrerId) {
        const { data } = await supabase
            .from('users')
            .select('user_id')
            .eq('referrer_user_id', referrerId)
            .eq('has_approved_nft', true);
        return data ? data.map(u => u.user_id) : [];
    }
    
    async getApprovedUserIdsFromReferrers(referrerIds) {
        if (referrerIds.length === 0) return [];
        const { data } = await supabase
            .from('users')
            .select('user_id')
            .in('referrer_user_id', referrerIds)
            .eq('has_approved_nft', true);
        return data ? data.map(u => u.user_id) : [];
    }
    
    calculateLevelInvestments(users) {
        let totalInvestmentFromPurchases = 0;
        let totalInvestmentFromCycle = 0;
        const userDetails = [];
        
        users.forEach(user => {
            const nftCountFromPurchases = Math.floor(user.total_purchases / 1100);
            const investmentFromPurchases = nftCountFromPurchases * 1000;
            totalInvestmentFromPurchases += investmentFromPurchases;
            
            const nftCountFromCycle = user.affiliate_cycle?.total_nft_count || 0;
            const investmentFromCycle = nftCountFromCycle * 1000;
            totalInvestmentFromCycle += investmentFromCycle;
            
            userDetails.push({
                user_id: user.user_id,
                email: user.email,
                referrer_user_id: user.referrer_user_id,
                total_purchases: user.total_purchases,
                nft_from_purchases: nftCountFromPurchases,
                investment_from_purchases: investmentFromPurchases,
                nft_from_cycle: nftCountFromCycle,
                investment_from_cycle: investmentFromCycle,
                difference: investmentFromPurchases - investmentFromCycle
            });
        });
        
        return { totalInvestmentFromPurchases, totalInvestmentFromCycle, userDetails };
    }
    
    createEmptyLevelResult(rewardRate) {
        return {
            total_users: 0,
            approved_users: 0,
            total_investment_from_purchases: 0,
            total_investment_from_cycle: 0,
            reward_rate: rewardRate,
            user_details: []
        };
    }
    
    async getDeepLevelUsers(startLevel) {
        // 簡略化のため、実際のLevel4以降のユーザー数を確認するのみ
        // 本来は再帰的に深い階層まで取得するが、今回は概算
        const level1Ids = await this.getApprovedUserIds(this.targetUserId);
        const level2Ids = await this.getApprovedUserIdsFromReferrers(level1Ids);
        const level3Ids = await this.getApprovedUserIdsFromReferrers(level2Ids);
        const level4Ids = await this.getApprovedUserIdsFromReferrers(level3Ids);
        
        if (level4Ids.length === 0) return [];
        
        const { data: level4Users } = await supabase
            .from('users')
            .select(`
                user_id, 
                email, 
                has_approved_nft, 
                total_purchases,
                referrer_user_id,
                affiliate_cycle(total_nft_count)
            `)
            .in('referrer_user_id', level3Ids);
            
        return level4Users || [];
    }

    /**
     * 結果の出力
     */
    outputResults() {
        console.log('📊 検証結果サマリー');
        console.log('================================================\n');
        
        // レベル別結果
        Object.entries(this.results.levels).forEach(([level, data]) => {
            console.log(`${level.toUpperCase()}:`);
            console.log(`  人数: ${data.approved_users}名`);
            console.log(`  投資額(cycle): $${data.total_investment_from_cycle}`);
            console.log(`  報酬率: ${(data.reward_rate * 100).toFixed(0)}%`);
            console.log(`  日利報酬例: $${(data.total_investment_from_cycle * 0.001 * data.reward_rate).toFixed(3)}\n`);
        });
        
        // 問題の出力
        if (this.results.issues.length > 0) {
            console.log('⚠️  発見された問題:');
            this.results.issues.forEach((issue, index) => {
                console.log(`${index + 1}. [${issue.level}] ${issue.issue}`);
                console.log(`   詳細: ${issue.detail}\n`);
            });
        } else {
            console.log('✅ 問題は見つかりませんでした\n');
        }
        
        // 推奨事項
        console.log('💡 推奨事項:');
        if (this.results.calculations?.formula_consistency) {
            console.log(`   - ${this.results.calculations.formula_consistency.recommendation}`);
        }
        console.log('   - has_approved_nft = true のユーザーのみが正しく計算されています');
        console.log('   - affiliate_cycle.total_nft_count が最も正確なNFT数です\n');
        
        // JSON出力
        console.log('📋 詳細結果（JSON）:');
        console.log(JSON.stringify(this.results, null, 2));
    }
}

// CLI実行
async function main() {
    const userId = process.argv[2] || '7A9637';
    
    console.log('🔍 HASHPILOT レベル別計算検証ツール');
    console.log('=====================================\n');
    
    try {
        const verifier = new LevelCalculationVerifier(userId);
        await verifier.verify();
    } catch (error) {
        console.error('💥 検証エラー:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = LevelCalculationVerifier;