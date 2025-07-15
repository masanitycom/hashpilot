"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase } from "@/lib/supabase"
import { Loader2, DollarSign, AlertCircle, CheckCircle, XCircle } from "lucide-react"

interface NftBuybackRequestProps {
  userId: string
}

interface NftData {
  manual_nft_count: number
  auto_nft_count: number
  total_nft_count: number
}

interface BuybackHistory {
  id: string
  request_date: string
  manual_nft_count: number
  auto_nft_count: number
  total_buyback_amount: number
  status: string
  wallet_address: string
}

export function NftBuybackRequest({ userId }: NftBuybackRequestProps) {
  const [nftData, setNftData] = useState<NftData | null>(null)
  const [manualCount, setManualCount] = useState(0)
  const [autoCount, setAutoCount] = useState(0)
  const [walletAddress, setWalletAddress] = useState("")
  const [loading, setLoading] = useState(false)
  const [calculating, setCalculating] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)
  const [buybackAmount, setBuybackAmount] = useState({ manual: 0, auto: 0, total: 0 })
  const [history, setHistory] = useState<BuybackHistory[]>([])
  const [userProfit, setUserProfit] = useState(0)
  const [cancellingId, setCancellingId] = useState<string | null>(null)

  useEffect(() => {
    fetchNftData()
    fetchBuybackHistory()
    fetchUserProfit()
    fetchUserWallet()
  }, [userId])

  useEffect(() => {
    if (manualCount || autoCount) {
      calculateBuybackAmount()
    }
  }, [manualCount, autoCount, userProfit])

  const fetchNftData = async () => {
    try {
      const { data, error } = await supabase
        .from("affiliate_cycle")
        .select("manual_nft_count, auto_nft_count, total_nft_count")
        .eq("user_id", userId)
        .single()

      if (error) throw error
      setNftData(data)
    } catch (error) {
      console.error("Error fetching NFT data:", error)
    }
  }

  const fetchUserProfit = async () => {
    try {
      const { data, error } = await supabase
        .from("user_daily_profit")
        .select("daily_profit")
        .eq("user_id", userId)

      if (error) throw error
      
      const totalProfit = data.reduce((sum, record) => sum + (record.daily_profit || 0), 0)
      setUserProfit(totalProfit)
    } catch (error) {
      console.error("Error fetching user profit:", error)
    }
  }

  const fetchUserWallet = async () => {
    try {
      const { data, error } = await supabase
        .from("users")
        .select("reward_address_bep20")
        .eq("user_id", userId)
        .single()

      if (error) throw error
      if (data?.reward_address_bep20) {
        setWalletAddress(data.reward_address_bep20)
      }
    } catch (error) {
      console.error("Error fetching user wallet:", error)
    }
  }

  const fetchBuybackHistory = async () => {
    try {
      const { data, error } = await supabase.rpc("get_buyback_requests", {
        p_user_id: userId
      })

      if (error) throw error
      setHistory(data || [])
    } catch (error) {
      console.error("Error fetching buyback history:", error)
    }
  }

  const calculateBuybackAmount = () => {
    if (!nftData) return

    // 手動NFTの買い取り額計算
    const profitPerNft = nftData.manual_nft_count > 0 ? userProfit / nftData.manual_nft_count : 0
    const manualBuyback = Math.max(0, (1000 * manualCount) - (profitPerNft * manualCount))
    
    // 自動NFTの買い取り額計算（500ドル-利益額）
    const autoProfitPerNft = nftData.auto_nft_count > 0 ? userProfit / nftData.auto_nft_count : 0
    const autoBuyback = Math.max(0, (500 * autoCount) - (autoProfitPerNft * autoCount))
    
    setBuybackAmount({
      manual: manualBuyback,
      auto: autoBuyback,
      total: manualBuyback + autoBuyback
    })
  }

  const handleSubmit = async () => {
    if (!walletAddress) {
      setMessage({ type: "error", text: "ウォレットアドレスを入力してください" })
      return
    }

    if (manualCount === 0 && autoCount === 0) {
      setMessage({ type: "error", text: "買い取り数量を入力してください" })
      return
    }

    // 保有数を超えていないかチェック
    if (manualCount > (nftData?.manual_nft_count || 0)) {
      setMessage({ type: "error", text: `手動購入NFTの保有数は${nftData?.manual_nft_count}枚です` })
      return
    }

    if (autoCount > (nftData?.auto_nft_count || 0)) {
      setMessage({ type: "error", text: `自動購入NFTの保有数は${nftData?.auto_nft_count}枚です` })
      return
    }

    setLoading(true)
    setMessage(null)

    try {
      const { data, error } = await supabase.rpc("create_buyback_request", {
        p_user_id: userId,
        p_manual_nft_count: manualCount,
        p_auto_nft_count: autoCount,
        p_wallet_address: walletAddress,
        p_wallet_type: "USDT-BEP20"
      })

      if (error) throw error

      if (data && data[0]?.success) {
        setMessage({ 
          type: "success", 
          text: `買い取り申請が完了しました。買い取り額: $${data[0].total_amount}` 
        })
        
        // フォームをリセット
        setManualCount(0)
        setAutoCount(0)
        
        // データを再取得
        fetchNftData()
        fetchBuybackHistory()
      } else {
        throw new Error(data?.[0]?.message || "申請に失敗しました")
      }
    } catch (error: any) {
      setMessage({ type: "error", text: error.message || "申請中にエラーが発生しました" })
    } finally {
      setLoading(false)
    }
  }

  const handleCancel = async (requestId: string) => {
    if (!confirm("管理者にキャンセル依頼を送信しますか？")) {
      return
    }

    setCancellingId(requestId)
    setMessage(null)

    try {
      // システムログにキャンセル依頼を記録
      const { error: logError } = await supabase
        .from("system_logs")
        .insert({
          log_type: "INFO",
          operation: "buyback_cancel_request",
          user_id: userId,
          message: `ユーザー${userId}が買い取り申請のキャンセルを依頼しました`,
          details: {
            request_id: requestId,
            requested_at: new Date().toISOString()
          }
        })

      if (logError) {
        console.warn("Log insert failed:", logError)
      }

      setMessage({ 
        type: "success", 
        text: "キャンセル依頼を送信しました。管理者が確認してキャンセル処理を行います。" 
      })
      
    } catch (error: any) {
      setMessage({ type: "error", text: "キャンセル依頼の送信に失敗しました" })
    } finally {
      setCancellingId(null)
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return <span className="text-yellow-400">申請中</span>
      case "processing":
        return <span className="text-blue-400">処理中</span>
      case "completed":
        return <span className="text-green-400">完了</span>
      case "cancelled":
        return <span className="text-red-400">キャンセル</span>
      default:
        return <span className="text-gray-400">{status}</span>
    }
  }

  if (!nftData) {
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

  return (
    <div className="space-y-6">
      <Card className="bg-gray-900/50 border-gray-700">
        <CardHeader>
          <CardTitle className="text-white flex items-center space-x-2">
            <DollarSign className="h-5 w-5" />
            <span>NFT買い取り申請</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* 現在の保有状況 */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-gray-800/50 rounded-lg p-4">
              <div className="text-sm text-gray-400">手動購入NFT</div>
              <div className="text-2xl font-bold text-white">{nftData.manual_nft_count}枚</div>
              <div className="text-xs text-gray-500">買い取り額: 1000 - 利益</div>
            </div>
            <div className="bg-gray-800/50 rounded-lg p-4">
              <div className="text-sm text-gray-400">自動購入NFT</div>
              <div className="text-2xl font-bold text-white">{nftData.auto_nft_count}枚</div>
              <div className="text-xs text-gray-500">買い取り額: 500ドル-利益額</div>
            </div>
            <div className="bg-gray-800/50 rounded-lg p-4">
              <div className="text-sm text-gray-400">累計利益</div>
              <div className="text-2xl font-bold text-yellow-400">${userProfit.toFixed(2)}</div>
              <div className="text-xs text-gray-500">手動NFTから差引</div>
            </div>
          </div>

          {/* 申請フォーム */}
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <Label htmlFor="manual" className="text-white">手動購入NFT買い取り数</Label>
                <Input
                  id="manual"
                  type="number"
                  min="0"
                  max={nftData.manual_nft_count}
                  value={manualCount}
                  onChange={(e) => {
                    const value = Number(e.target.value)
                    setManualCount(Math.min(Math.max(0, value), nftData.manual_nft_count))
                  }}
                  className="bg-gray-800 border-gray-700 text-white"
                />
                <div className="text-xs text-gray-400 mt-1">
                  最大: {nftData.manual_nft_count}枚
                </div>
              </div>
              <div>
                <Label htmlFor="auto" className="text-white">自動購入NFT買い取り数</Label>
                <Input
                  id="auto"
                  type="number"
                  min="0"
                  max={nftData.auto_nft_count}
                  value={autoCount}
                  onChange={(e) => {
                    const value = Number(e.target.value)
                    setAutoCount(Math.min(Math.max(0, value), nftData.auto_nft_count))
                  }}
                  className="bg-gray-800 border-gray-700 text-white"
                />
                <div className="text-xs text-gray-400 mt-1">
                  最大: {nftData.auto_nft_count}枚
                </div>
              </div>
            </div>

            <div>
              <Label htmlFor="wallet" className="text-white">送金先ウォレットアドレス</Label>
              <Input
                id="wallet"
                type="text"
                value={walletAddress}
                onChange={(e) => setWalletAddress(e.target.value)}
                placeholder="USDT BEP20アドレス"
                className="bg-gray-800 border-gray-700 text-white"
              />
            </div>

            {/* 買い取り額計算 */}
            {(manualCount > 0 || autoCount > 0) && (
              <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4">
                <div className="text-sm text-blue-400 mb-2">買い取り額計算</div>
                <div className="space-y-1 text-white">
                  <div className="flex justify-between">
                    <span>手動NFT ({manualCount}枚)</span>
                    <span>${buybackAmount.manual.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>自動NFT ({autoCount}枚)</span>
                    <span>${buybackAmount.auto.toFixed(2)}</span>
                  </div>
                  <div className="border-t border-gray-700 pt-1 mt-2">
                    <div className="flex justify-between font-bold text-yellow-400">
                      <span>合計</span>
                      <span>${buybackAmount.total.toFixed(2)}</span>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {message && (
              <Alert className={message.type === "error" ? "bg-red-900/20 border-red-700" : "bg-green-900/20 border-green-700"}>
                <AlertDescription className={message.type === "error" ? "text-red-400" : "text-green-400"}>
                  {message.type === "error" ? <AlertCircle className="h-4 w-4 inline mr-2" /> : <CheckCircle className="h-4 w-4 inline mr-2" />}
                  {message.text}
                </AlertDescription>
              </Alert>
            )}

            <Button
              onClick={handleSubmit}
              disabled={loading || (manualCount === 0 && autoCount === 0)}
              className="w-full bg-gradient-to-r from-yellow-600 to-yellow-700 hover:from-yellow-700 hover:to-yellow-800 text-white"
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  処理中...
                </>
              ) : (
                "買い取り申請"
              )}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* 申請履歴 */}
      {history.length > 0 && (
        <Card className="bg-gray-900/50 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">買い取り申請履歴</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left p-2 text-gray-400">申請日</th>
                    <th className="text-left p-2 text-gray-400">手動NFT</th>
                    <th className="text-left p-2 text-gray-400">自動NFT</th>
                    <th className="text-left p-2 text-gray-400">買い取り額</th>
                    <th className="text-left p-2 text-gray-400">ステータス</th>
                    <th className="text-center p-2 text-gray-400">アクション</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((request) => (
                    <tr key={request.id} className="border-b border-gray-800">
                      <td className="p-2 text-white">
                        {new Date(request.request_date).toLocaleDateString()}
                      </td>
                      <td className="p-2 text-white">{request.manual_nft_count}枚</td>
                      <td className="p-2 text-white">{request.auto_nft_count}枚</td>
                      <td className="p-2 text-yellow-400">${request.total_buyback_amount}</td>
                      <td className="p-2">{getStatusBadge(request.status)}</td>
                      <td className="p-2 text-center">
                        {request.status === "pending" && (
                          <Button
                            onClick={() => handleCancel(request.id)}
                            disabled={cancellingId === request.id}
                            variant="outline"
                            size="sm"
                            className="text-red-400 border-red-600 hover:bg-red-900/20"
                          >
                            {cancellingId === request.id ? (
                              <Loader2 className="h-3 w-3 animate-spin" />
                            ) : (
                              <>
                                <XCircle className="h-3 w-3 mr-1" />
                                キャンセル依頼
                              </>
                            )}
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}