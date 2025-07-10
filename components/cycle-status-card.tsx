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
  phase: string
  cum_usdt: number
  available_usdt: number
  total_nft_count: number
  auto_nft_count: number
  manual_nft_count: number
  cycle_number: number
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

  const fetchCycleData = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error: cycleError } = await supabase
        .from('affiliate_cycle')
        .select('*')
        .eq('user_id', userId)
        .single()

      if (cycleError) {
        if (cycleError.code === 'PGRST116') {
          setError("サイクルデータがありません")
        } else {
          throw cycleError
        }
      } else {
        setCycleData(data)
      }
    } catch (err: any) {
      console.error("Cycle data fetch error:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const getPhaseInfo = (phase: string, cumUsdt: number) => {
    if (phase === 'HOLD' || cumUsdt >= 1100) {
      return {
        label: "🔒 HOLD フェーズ",
        description: "2200 USDT到達で自動NFT購入",
        color: "bg-orange-600",
        icon: <Clock className="h-4 w-4" />
      }
    } else {
      return {
        label: "💰 USDT フェーズ", 
        description: "利益は即時受け取り可能",
        color: "bg-green-600",
        icon: <DollarSign className="h-4 w-4" />
      }
    }
  }

  const getProgressPercentage = (cumUsdt: number) => {
    if (cumUsdt >= 2200) return 100
    return (cumUsdt / 2200) * 100
  }

  const getNextMilestone = (cumUsdt: number) => {
    if (cumUsdt < 1100) {
      return {
        target: 1100,
        label: "HOLDフェーズまで",
        remaining: 1100 - cumUsdt
      }
    } else if (cumUsdt < 2200) {
      return {
        target: 2200,
        label: "自動NFT購入まで",
        remaining: 2200 - cumUsdt
      }
    } else {
      return {
        target: 2200,
        label: "自動NFT購入準備完了",
        remaining: 0
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

  const phaseInfo = getPhaseInfo(cycleData.phase, cycleData.cum_usdt)
  const progress = getProgressPercentage(cycleData.cum_usdt)
  const milestone = getNextMilestone(cycleData.cum_usdt)

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
            サイクル {cycleData.cycle_number}
          </Badge>
        </div>

        <p className="text-xs text-gray-400">{phaseInfo.description}</p>

        {/* 進捗バー */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs">
            <span className="text-gray-400">累積額進捗</span>
            <span className="text-white">${cycleData.cum_usdt.toFixed(2)} / $2,200</span>
          </div>
          <Progress value={progress} className="h-2 bg-gray-700">
            <div 
              className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all"
              style={{ width: `${progress}%` }}
            />
          </Progress>
          
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

export default CycleStatusCard