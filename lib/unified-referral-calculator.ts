// 完璧な統一紹介計算ロジック
// ダッシュボードと管理画面の両方で使用する統一計算システム

import { supabase } from '@/lib/supabase'

export interface UnifiedReferralStats {
  // 基本統計
  totalReferrals: number          // 全紹介者数（購入有無問わず）
  purchasedReferrals: number      // 購入済み紹介者数
  unpurchasedReferrals: number    // 未購入紹介者数
  
  // 投資統計
  totalInvestment: number         // 運用額合計（購入者のみ）
  actualPurchases: number         // 実購入額合計
  
  // レベル別統計
  levelBreakdown: {
    level: number
    totalCount: number            // そのレベルの全紹介者
    purchasedCount: number        // そのレベルの購入済み紹介者
    investment: number            // そのレベルの運用額
  }[]
  
  // 詳細情報
  maxLevel: number                // 最大レベル深度
  directReferrals: number         // 直接紹介者数（Level 1）
  indirectReferrals: number       // 間接紹介者数（Level 2+）
  
  // 管理画面用の追加フィールド
  personal_purchases?: number
  subtree_total?: number
}

export interface UnifiedUser {
  user_id: string
  email: string
  total_purchases: number
  referrer_user_id: string | null
  created_at: string
  is_pegasus_exchange: boolean
  // その他必要なフィールド
}

/**
 * 完璧な統一紹介計算ロジック
 * ダッシュボードと管理画面で同じ結果を保証
 */
export class UnifiedReferralCalculator {
  private allUsers: UnifiedUser[] = []
  
  constructor() {
    // コンストラクタ
  }
  
  /**
   * 全ユーザーデータを読み込み
   */
  async loadAllUsers(): Promise<void> {
    const { data, error } = await supabase
      .from('users')
      .select('user_id, email, total_purchases, referrer_user_id, created_at, is_pegasus_exchange')
      .order('created_at', { ascending: true })

    if (error) {
      throw new Error(`ユーザーデータ取得エラー: ${error.message}`)
    }

    this.allUsers = data || []
  }
  
  /**
   * 指定ユーザーの完全な紹介統計を計算
   */
  async calculateCompleteStats(userId: string): Promise<UnifiedReferralStats> {
    if (this.allUsers.length === 0) {
      await this.loadAllUsers()
    }
    
    // 紹介ツリー構築（BFS使用で循環参照回避）
    const referralTree = this.buildReferralTree(userId)
    
    // レベル別統計計算
    const levelBreakdown = this.calculateLevelBreakdown(referralTree)
    
    // 基本統計計算
    const stats = this.calculateBasicStats(referralTree, levelBreakdown)
    
    return {
      ...stats,
      levelBreakdown,
      maxLevel: Math.max(...levelBreakdown.map(l => l.level), 0)
    }
  }
  
  /**
   * 紹介ツリー構築（幅優先探索で循環参照を回避）
   */
  private buildReferralTree(rootUserId: string): Map<number, UnifiedUser[]> {
    const tree = new Map<number, UnifiedUser[]>()
    const processed = new Set<string>([rootUserId])
    
    // Level 1: 直接紹介者
    const level1 = this.allUsers.filter(u => u.referrer_user_id === rootUserId)
    if (level1.length > 0) {
      tree.set(1, level1)
      level1.forEach(u => processed.add(u.user_id))
    }
    
    let currentLevel = 1
    const maxLevels = 100 // 安全装置（実際は25レベル程度）
    
    while (currentLevel < maxLevels) {
      const currentLevelUsers = tree.get(currentLevel)
      if (!currentLevelUsers || currentLevelUsers.length === 0) break
      
      const nextLevelUsers: UnifiedUser[] = []
      
      for (const parent of currentLevelUsers) {
        const children = this.allUsers.filter(u => 
          u.referrer_user_id === parent.user_id && 
          !processed.has(u.user_id)
        )
        
        children.forEach(child => {
          processed.add(child.user_id)
          nextLevelUsers.push(child)
        })
      }
      
      if (nextLevelUsers.length > 0) {
        tree.set(currentLevel + 1, nextLevelUsers)
      }
      
      currentLevel++
    }
    
    return tree
  }
  
  /**
   * レベル別詳細統計計算
   */
  private calculateLevelBreakdown(tree: Map<number, UnifiedUser[]>) {
    const breakdown: UnifiedReferralStats['levelBreakdown'] = []

    // ペガサス交換ユーザーの例外リスト（この3名は通常ユーザーとして扱う）
    const SPECIAL_PEGASUS_USERS = ['5A708D', '20248A', '225F87']

    for (const [level, users] of tree) {
      const purchasedUsers = users.filter(u => u.total_purchases > 0)

      // ペガサス交換ユーザーを除外（例外の3名は含める）
      const validPurchasedUsers = purchasedUsers.filter(u =>
        !u.is_pegasus_exchange || SPECIAL_PEGASUS_USERS.includes(u.user_id)
      )

      const investment = validPurchasedUsers.reduce((sum, u) =>
        sum + Math.floor(u.total_purchases / 1100) * 1000, 0
      )

      breakdown.push({
        level,
        totalCount: users.length,
        purchasedCount: purchasedUsers.length,
        investment
      })
    }

    return breakdown.sort((a, b) => a.level - b.level)
  }
  
  /**
   * 基本統計計算
   */
  private calculateBasicStats(
    tree: Map<number, UnifiedUser[]>, 
    levelBreakdown: UnifiedReferralStats['levelBreakdown']
  ) {
    // 全紹介者を平坦化
    const allReferrals: UnifiedUser[] = []
    tree.forEach(users => allReferrals.push(...users))
    
    const purchasedReferrals = allReferrals.filter(u => u.total_purchases > 0)
    
    return {
      totalReferrals: allReferrals.length,
      purchasedReferrals: purchasedReferrals.length,
      unpurchasedReferrals: allReferrals.length - purchasedReferrals.length,
      
      totalInvestment: levelBreakdown.reduce((sum, l) => sum + l.investment, 0),
      actualPurchases: purchasedReferrals.reduce((sum, u) => sum + u.total_purchases, 0),
      
      directReferrals: levelBreakdown.find(l => l.level === 1)?.totalCount || 0,
      indirectReferrals: allReferrals.length - (levelBreakdown.find(l => l.level === 1)?.totalCount || 0)
    }
  }
  
  /**
   * 指定ユーザーの統計を取得（キャッシュ対応）
   */
  static async getUnifiedStats(userId: string): Promise<UnifiedReferralStats> {
    const calculator = new UnifiedReferralCalculator()
    return await calculator.calculateCompleteStats(userId)
  }
  
  /**
   * 複数ユーザーの統計を一括取得
   */
  static async getBulkStats(userIds: string[]): Promise<Map<string, UnifiedReferralStats>> {
    const calculator = new UnifiedReferralCalculator()
    await calculator.loadAllUsers() // 一度だけ読み込み
    
    const results = new Map<string, UnifiedReferralStats>()
    
    for (const userId of userIds) {
      try {
        const stats = await calculator.calculateCompleteStats(userId)
        results.set(userId, stats)
      } catch (error) {
        console.error(`統計計算エラー (${userId}):`, error)
        // エラー時のデフォルト値
        results.set(userId, {
          totalReferrals: 0,
          purchasedReferrals: 0,
          unpurchasedReferrals: 0,
          totalInvestment: 0,
          actualPurchases: 0,
          levelBreakdown: [],
          maxLevel: 0,
          directReferrals: 0,
          indirectReferrals: 0
        })
      }
    }
    
    return results
  }
}

/**
 * 表示用フォーマット関数
 */
export function formatUnifiedStats(stats: UnifiedReferralStats) {
  return {
    // ダッシュボード用（購入者ベース）
    dashboard: {
      totalReferrals: stats.purchasedReferrals,
      totalInvestment: stats.totalInvestment, // 運用額（手数料除く）
      level4Plus: stats.levelBreakdown
        .filter(l => l.level >= 4)
        .reduce((sum, l) => sum + l.purchasedCount, 0),
      level4PlusInvestment: stats.levelBreakdown
        .filter(l => l.level >= 4)
        .reduce((sum, l) => sum + l.investment, 0)
    },
    
    // 管理画面用（全紹介者ベース）- 運用額で統一
    admin: {
      totalReferrals: stats.totalReferrals,
      totalInvestment: stats.totalInvestment, // 運用額（手数料除く）
      purchasedCount: stats.purchasedReferrals,
      unpurchasedCount: stats.unpurchasedReferrals
    },
    
    // 詳細情報
    details: {
      maxLevel: stats.maxLevel,
      levelBreakdown: stats.levelBreakdown,
      actualPurchases: stats.actualPurchases // 参考用（手数料含む）
    }
  }
}

export default UnifiedReferralCalculator