"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { AlertCircle, ExternalLink } from "lucide-react"

export default function PreRegisterPage() {
  const [coinwUid, setCoinwUid] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [referrerId, setReferrerId] = useState("")
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const ref = searchParams.get("ref")
    if (ref) {
      setReferrerId(ref)
      // 紹介コードをストレージにも保存
      sessionStorage.setItem("referrer_id", ref)
      localStorage.setItem("referrer_id", ref)
    } else {
      // URLにrefがない場合は、ストレージから取得
      const storedRef = sessionStorage.getItem("referrer_id") || localStorage.getItem("referrer_id")
      if (storedRef) {
        setReferrerId(storedRef)
      }
    }
  }, [searchParams])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!coinwUid.trim()) {
      setError("CoinW UIDを入力してください")
      return
    }

    setLoading(true)
    setError("")

    try {
      // CoinW UIDをセッションストレージに保存
      sessionStorage.setItem("coinw_uid", coinwUid.trim())
      sessionStorage.setItem("referrer_id", referrerId)
      
      // ローカルストレージにも保存（バックアップ）
      localStorage.setItem("coinw_uid", coinwUid.trim())
      localStorage.setItem("referrer_id", referrerId)

      // 登録ページにリダイレクト（パラメータ付き）
      const params = new URLSearchParams()
      params.set("coinw", coinwUid.trim())
      if (referrerId) {
        params.set("ref", referrerId)
      }
      router.push(`/register?${params.toString()}`)
    } catch (error: any) {
      console.error("Pre-registration error:", error)
      setError("エラーが発生しました。もう一度お試しください。")
    } finally {
      setLoading(false)
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setCoinwUid(e.target.value)
    if (error) {
      setError("")
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <Card className="w-full max-w-2xl bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-4">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-12" />
          </div>
          <CardTitle className="text-2xl text-white">HASH PILOT 事前登録</CardTitle>
          <CardDescription className="text-gray-300">
            {referrerId && <span className="text-blue-400">紹介者ID: {referrerId} からの招待</span>}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* CoinW登録セクション */}
            <div className="bg-blue-900 border border-blue-700 rounded-lg p-6">
              <div className="flex items-center mb-4">
                <div className="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold mr-3">
                  1
                </div>
                <h3 className="text-xl font-semibold text-white">CoinW 無料登録</h3>
              </div>

              <p className="text-blue-200 text-sm mb-4">まずはCoinWの無料アカウントを作成してください。</p>

              <Button
                type="button"
                variant="outline"
                size="sm"
                className="mb-3 bg-blue-600 text-white border-blue-600 hover:bg-blue-700 hover:border-blue-700"
                onClick={() => window.open("https://www.coinw.com/ja_JP/register?r=3722480", "_blank")}
              >
                <ExternalLink className="w-4 h-4 mr-2" />
                CoinWで無料登録
              </Button>

              <p className="text-red-400 text-xs mb-3">
                ※既にCoinWのアカウントをお持ちの方も上記リンクから新規登録が必要になります。
              </p>

              <div className="space-y-2">
                <Label htmlFor="coinw-uid" className="text-blue-200 text-sm font-medium">
                  CoinW UID <span className="text-red-400">*</span>
                </Label>
                <Input
                  id="coinw-uid"
                  name="coinw-uid"
                  type="text"
                  value={coinwUid}
                  onChange={handleInputChange}
                  placeholder="例: 12345678"
                  className="bg-gray-700 border-gray-600 text-white placeholder-gray-400 focus:border-blue-500 focus:ring-blue-500"
                  required
                  autoComplete="off"
                />
                <p className="text-xs text-blue-300">
                  CoinWアプリ → 右下「資産」→ 右上「設定」→「アカウント情報」で確認できます
                </p>
              </div>
            </div>

            {error && (
              <div className="bg-red-900 border border-red-700 rounded-lg p-4">
                <div className="flex items-center">
                  <AlertCircle className="w-5 h-5 text-red-400 mr-2" />
                  <p className="text-red-200">{error}</p>
                </div>
              </div>
            )}

            <Button
              type="submit"
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3"
              disabled={loading}
            >
              {loading ? "処理中..." : "次へ進む"}
            </Button>
          </form>

          <div className="text-center text-gray-400 text-sm">
            <p>登録に関してご不明な点がございましたら、サポートまでお問い合わせください。</p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
