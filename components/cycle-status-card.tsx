"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { DollarSign, Zap, Clock, Target, TrendingUp } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface CycleStatusCardProps {
  userId: string
}

interface CycleData {
  next_action: string
  available_usdt: number
  total_nft_count: number
  auto_nft_count: number
  manual_nft_count: number
  cum_profit: number
  remaining_profit: number
}

export function CycleStatusCard({ userId }: CycleStatusCardProps) {
  const [cycleData, setCycleData] = useState<CycleData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchCycleData()
    }
  }, [userId])

  // 月間紹介報酬を計算する関数
  const calculateMonthlyReferralProfit = async (userId: string, monthStart: string, monthEnd: string): Promise<number> => {
    try {
      // 紹介報酬率の定義
      const level1Rate = 0.20 // 20%
      const level2Rate = 0.10 // 10%  
      const level3Rate = 0.05 // 5%

      // 各レベルの紹介者IDを取得
      const level1UserIds = await getDirectReferrals(userId)
      const level2UserIds = await getLevel2Referrals(userId)
      const level3UserIds = await getLevel3Referrals(userId)

      // 各レベルの紹介者の利益を取得
      const level1Profits = await getReferralProfits(level1UserIds, monthStart, monthEnd)
      const level2Profits = await getReferralProfits(level2UserIds, monthStart, monthEnd)
      const level3Profits = await getReferralProfits(level3UserIds, monthStart, monthEnd)

      // 紹介報酬計算
      const level1Reward = level1Profits * level1Rate
      const level2Reward = level2Profits * level2Rate
      const level3Reward = level3Profits * level3Rate

      return level1Reward + level2Reward + level3Reward
    } catch (error) {
      console.error('紹介報酬計算エラー:', error)
      return 0
    }
  }

  // 直接紹介者のIDを取得
  const getDirectReferrals = async (userId: string): Promise<string[]> => {
    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .eq('referrer_user_id', userId)

    if (error) return []
    return data.map(user => user.user_id)
  }

  // Level2紹介者のIDを取得
  const getLevel2Referrals = async (userId: string): Promise<string[]> => {
    const level1Ids = await getDirectReferrals(userId)
    if (level1Ids.length === 0) return []

    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .in('referrer_user_id', level1Ids)

    if (error) return []
    return data.map(user => user.user_id)
  }

  // Level3紹介者のIDを取得
  const getLevel3Referrals = async (userId: string): Promise<string[]> => {
    const level2Ids = await getLevel2Referrals(userId)
    if (level2Ids.length === 0) return []

    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .in('referrer_user_id', level2Ids)

    if (error) return []
    return data.map(user => user.user_id)
  }

  // 指定されたユーザーIDリストの利益を取得
  const getReferralProfits = async (userIds: string[], monthStart: string, monthEnd: string): Promise<number> => {
    if (userIds.length === 0) return 0

    // NFT承認済みかつ実際に運用開始しているユーザーのみフィルター
    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select(`
        user_id, 
        has_approved_nft,
        affiliate_cycle!inner(total_nft_count)
      `)
      .in('user_id', userIds)
      .eq('has_approved_nft', true)
      .gt('affiliate_cycle.total_nft_count', 0)

    if (usersError) return 0

    const eligibleUserIds = usersData.map(user => user.user_id)
    if (eligibleUserIds.length === 0) return 0

    const { data, error } = await supabase
      .from('user_daily_profit')
      .select('daily_profit')
      .in('user_id', eligibleUserIds)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) return 0
    return data.reduce((sum, row) => sum + (parseFloat(row.daily_profit) || 0), 0)
  }

  const fetchCycleData = async () => {
    try {
      setLoading(true)
      setError("")

      // 現在の月の利益データを取得（個人利益）
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (profitError && profitError.code !== 'PGRST116') throw profitError

      // affiliate_cycleから正確なNFTデータを取得
      const { data: cycleInfo, error: cycleError } = await supabase
        .from('affiliate_cycle')
        .select('total_nft_count, manual_nft_count, auto_nft_count, cum_usdt, available_usdt')
        .eq('user_id', userId)
        .single()

      if (cycleError) throw cycleError

      // 個人利益を計算
      const personalProfit = profitData?.reduce((sum, p) => sum + (parseFloat(p.daily_profit) || 0), 0) || 0

      // 紹介報酬を計算（referral-profit-card.tsxと同じロジックを使用）
      const referralProfit = await calculateMonthlyReferralProfit(userId, monthStart, monthEnd)

      // 合計利益を計算（個人+紹介報酬）
      const totalProfit = personalProfit + referralProfit

      // affiliate_cycleから正確なNFT数を取得
      const totalNfts = cycleInfo?.total_nft_count || 0
      const manualNfts = cycleInfo?.manual_nft_count || 0
      const autoNfts = cycleInfo?.auto_nft_count || 0

      // 1100ドルサイクル計算
      const cyclesCompleted = Math.floor(totalProfit / 1100)
      const remainingProfit = totalProfit % 1100
      const nextAction = cyclesCompleted % 2 === 0 ? 'usdt' : 'nft'

      setCycleData({
        next_action: nextAction,
        available_usdt: 0, // 一旦0で設定
        total_nft_count: manualNfts + autoNfts,
        auto_nft_count: autoNfts,
        manual_nft_count: manualNfts,
        cum_profit: totalProfit,
        remaining_profit: remainingProfit
      })
    } catch (err: any) {
      console.error("Cycle data fetch error:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const getPhaseInfo = (nextAction: string) => {
    if (nextAction === 'nft') {
      return {
        label: "🎯 NFT購入フェーズ",
        description: "次の1100ドルでNFT自動購入",
        color: "bg-purple-600",
        icon: <Target className="h-4 w-4" />
      }
    } else {
      return {
        label: "💰 USDT受取フェーズ", 
        description: "次の1100ドルはUSDT受取",
        color: "bg-green-600",
        icon: <DollarSign className="h-4 w-4" />
      }
    }
  }

  const getProgressPercentage = (currentProfit: number) => {
    if (currentProfit <= 0) return 0
    if (currentProfit >= 1100) return 100
    return (currentProfit / 1100) * 100
  }

  const getNextMilestone = (currentProfit: number, nextAction: string) => {
    const remaining = 1100 - currentProfit
    if (remaining <= 0) {
      return {
        target: 1100,
        label: nextAction === 'nft' ? "NFT購入準備完了" : "USDT受取準備完了",
        remaining: 0
      }
    } else {
      return {
        target: 1100,
        label: nextAction === 'nft' ? "NFT購入まで" : "USDT受取まで",
        remaining: remaining
      }
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center space-x-2">
            <div className="animate-pulse bg-gray-600 h-4 w-32 rounded"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error || !cycleData) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <p className="text-gray-400 text-sm">{error || "サイクル情報なし"}</p>
        </CardContent>
      </Card>
    )
  }

  const phaseInfo = getPhaseInfo(cycleData.next_action)
  const progress = getProgressPercentage(cycleData.remaining_profit)
  const milestone = getNextMilestone(cycleData.remaining_profit, cycleData.next_action)

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Zap className="h-4 w-4 text-blue-400" />
          NFTサイクル状況
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* 現在のフェーズ */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {phaseInfo.icon}
            <span className="text-white text-sm font-medium">{phaseInfo.label}</span>
          </div>
          <Badge className={phaseInfo.color}>
            次: {cycleData.next_action.toUpperCase()}
          </Badge>
        </div>

        <p className="text-xs text-gray-400">{phaseInfo.description}</p>

        {/* 進捗バー */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-400">次の1100ドルまでの進捗</span>
            <span className="text-white">${cycleData.remaining_profit.toFixed(2)} / $1,100</span>
          </div>
          <div className="relative">
            <div className="h-3 bg-gray-700 rounded-full overflow-hidden">
              <div 
                className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all duration-300"
                style={{ width: `${progress}%` }}
              />
            </div>
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-xs font-semibold text-white drop-shadow-lg">
                {progress.toFixed(1)}%
              </span>
            </div>
          </div>
          
          {milestone.remaining > 0 && (
            <p className="text-xs text-gray-400">
              {milestone.label}: あと${milestone.remaining.toFixed(2)}
            </p>
          )}
        </div>

        {/* NFT保有状況 */}
        <div className="grid grid-cols-3 gap-3 pt-2 border-t border-gray-700">
          <div className="text-center">
            <div className="text-lg font-bold text-blue-400">{cycleData.total_nft_count}</div>
            <div className="text-xs text-gray-400">総NFT数</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-green-400">{cycleData.manual_nft_count}</div>
            <div className="text-xs text-gray-400">🛒 手動購入</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-bold text-purple-400">{cycleData.auto_nft_count}</div>
            <div className="text-xs text-gray-400">🔄 自動購入</div>
          </div>
        </div>

        {/* 利用可能残高 */}
        {cycleData.available_usdt > 0 && (
          <div className="bg-green-900/20 border border-green-500/30 rounded-lg p-3">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-green-400" />
              <span className="text-green-400 text-sm font-medium">
                受取可能: ${cycleData.available_usdt.toFixed(2)}
              </span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

