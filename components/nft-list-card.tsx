"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { supabase } from "@/lib/supabase"
import { Loader2, Package, Calendar, Clock } from "lucide-react"

interface NftListCardProps {
  userId: string
}

interface NftItem {
  id: string
  nft_type: 'manual' | 'auto'
  nft_value: number
  acquired_date: string
  operation_start_date: string | null
  nft_sequence: number
}

export function NftListCard({ userId }: NftListCardProps) {
  const [nfts, setNfts] = useState<NftItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchNfts()
  }, [userId])

  const fetchNfts = async () => {
    try {
      setLoading(true)
      setError(null)

      const { data, error: fetchError } = await supabase
        .from("nft_master")
        .select("id, nft_type, nft_value, acquired_date, operation_start_date, nft_sequence")
        .eq("user_id", userId)
        .is("buyback_date", null)
        .order("acquired_date", { ascending: true })

      if (fetchError) throw fetchError

      setNfts(data || [])
    } catch (err: any) {
      console.error("Error fetching NFTs:", err)
      setError(err.message || "NFT情報の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return "未設定"
    return new Date(dateString).toLocaleDateString("ja-JP", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    })
  }

  const isOperating = (operationStartDate: string | null) => {
    if (!operationStartDate) return false
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const startDate = new Date(operationStartDate)
    startDate.setHours(0, 0, 0, 0)
    return startDate <= today
  }

  const getDaysUntilOperation = (operationStartDate: string | null) => {
    if (!operationStartDate) return null
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const startDate = new Date(operationStartDate)
    startDate.setHours(0, 0, 0, 0)
    const diffTime = startDate.getTime() - today.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays > 0 ? diffDays : 0
  }

  if (loading) {
    return (
      <Card className="bg-gray-900/50 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-900/50 border-gray-700">
        <CardContent className="p-6">
          <div className="text-red-400 text-center">{error}</div>
        </CardContent>
      </Card>
    )
  }

  if (nfts.length === 0) {
    return null
  }

  const operatingCount = nfts.filter(nft => isOperating(nft.operation_start_date)).length
  const waitingCount = nfts.length - operatingCount

  return (
    <Card className="bg-gray-900/50 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-white flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Package className="h-5 w-5 text-blue-400" />
            <span>保有NFT一覧</span>
          </div>
          <div className="flex items-center space-x-3 text-sm font-normal">
            <span className="text-green-400">{operatingCount}個 運用中</span>
            {waitingCount > 0 && (
              <span className="text-yellow-400">{waitingCount}個 待機中</span>
            )}
          </div>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="text-left p-2 text-gray-400">NFT</th>
                <th className="text-left p-2 text-gray-400">種類</th>
                <th className="text-left p-2 text-gray-400">承認日</th>
                <th className="text-left p-2 text-gray-400">運用開始日</th>
                <th className="text-left p-2 text-gray-400">状態</th>
              </tr>
            </thead>
            <tbody>
              {nfts.map((nft, index) => {
                const operating = isOperating(nft.operation_start_date)
                const daysUntil = getDaysUntilOperation(nft.operation_start_date)

                return (
                  <tr key={nft.id} className="border-b border-gray-800 hover:bg-gray-800/30">
                    <td className="p-2 text-white">
                      <div className="flex items-center space-x-2">
                        <span className="font-mono text-xs text-gray-500">#{index + 1}</span>
                      </div>
                    </td>
                    <td className="p-2">
                      <Badge
                        variant="secondary"
                        className={nft.nft_type === 'manual'
                          ? "bg-blue-900/30 text-blue-300"
                          : "bg-purple-900/30 text-purple-300"
                        }
                      >
                        {nft.nft_type === 'manual' ? '手動購入' : '自動付与'}
                      </Badge>
                    </td>
                    <td className="p-2 text-gray-300">
                      <div className="flex items-center space-x-1">
                        <Calendar className="h-3 w-3 text-gray-500" />
                        <span>{formatDate(nft.acquired_date)}</span>
                      </div>
                    </td>
                    <td className="p-2 text-gray-300">
                      <div className="flex items-center space-x-1">
                        <Clock className="h-3 w-3 text-gray-500" />
                        <span>{formatDate(nft.operation_start_date)}</span>
                      </div>
                    </td>
                    <td className="p-2">
                      {operating ? (
                        <Badge className="bg-green-600 text-white">運用中</Badge>
                      ) : (
                        <Badge variant="secondary" className="bg-yellow-900/30 text-yellow-300">
                          あと{daysUntil}日
                        </Badge>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <div className="mt-4 p-3 bg-gray-800/50 rounded-lg text-xs text-gray-400">
          <p className="mb-1">運用開始日のルール:</p>
          <ul className="list-disc list-inside space-y-1 ml-2">
            <li>毎月5日までに承認 → 当月15日より運用開始</li>
            <li>毎月6日～20日に承認 → 翌月1日より運用開始</li>
            <li>毎月21日～月末に承認 → 翌月15日より運用開始</li>
          </ul>
        </div>
      </CardContent>
    </Card>
  )
}
