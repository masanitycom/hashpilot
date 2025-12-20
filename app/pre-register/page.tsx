"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { AlertCircle, ExternalLink, CheckCircle, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

export default function PreRegisterPage() {
  const [coinwUid, setCoinwUid] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [referrerId, setReferrerId] = useState("")
  const [referrerIdInput, setReferrerIdInput] = useState("")
  const [hasRefParam, setHasRefParam] = useState(false)
  const [validatingReferrer, setValidatingReferrer] = useState(false)
  const [referrerValid, setReferrerValid] = useState<boolean | null>(null)
  const [referrerName, setReferrerName] = useState("")
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const ref = searchParams.get("ref")
    if (ref) {
      setReferrerId(ref)
      setHasRefParam(true)
      // 紹介コードをストレージにも保存
      sessionStorage.setItem("referrer_id", ref)
      localStorage.setItem("referrer_id", ref)
      // 紹介者IDを検証
      validateReferrerId(ref)
    } else {
      // URLにrefがない場合は、ストレージから取得
      const storedRef = sessionStorage.getItem("referrer_id") || localStorage.getItem("referrer_id")
      if (storedRef) {
        setReferrerId(storedRef)
        setReferrerIdInput(storedRef)
        setHasRefParam(true)
        validateReferrerId(storedRef)
      } else {
        setHasRefParam(false)
      }
    }
  }, [searchParams])

  const validateReferrerId = async (id: string) => {
    if (!id || id.length !== 6) {
      setReferrerValid(false)
      setReferrerName("")
      return
    }

    setValidatingReferrer(true)
    try {
      const { data, error } = await supabase
        .from("users")
        .select("user_id, full_name")
        .eq("user_id", id.toUpperCase())
        .single()

      if (error || !data) {
        setReferrerValid(false)
        setReferrerName("")
      } else {
        setReferrerValid(true)
        setReferrerName(data.full_name || "")
        setReferrerId(data.user_id)
      }
    } catch (err) {
      setReferrerValid(false)
      setReferrerName("")
    } finally {
      setValidatingReferrer(false)
    }
  }

  const handleReferrerIdChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.toUpperCase()
    setReferrerIdInput(value)
    setReferrerValid(null)
    setReferrerName("")

    // 6文字になったら検証
    if (value.length === 6) {
      validateReferrerId(value)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!coinwUid.trim()) {
      setError("CoinW UIDを入力してください")
      return
    }

    // 紹介者IDのバリデーション
    if (!hasRefParam && !referrerIdInput.trim()) {
      setError("紹介者IDを入力してください")
      return
    }

    if (!hasRefParam && referrerValid !== true) {
      setError("有効な紹介者IDを入力してください")
      return
    }

    setLoading(true)
    setError("")

    try {
      const finalReferrerId = hasRefParam ? referrerId : referrerIdInput.toUpperCase()

      // CoinW UIDをセッションストレージに保存
      sessionStorage.setItem("coinw_uid", coinwUid.trim())
      sessionStorage.setItem("referrer_id", finalReferrerId)

      // ローカルストレージにも保存（バックアップ）
      localStorage.setItem("coinw_uid", coinwUid.trim())
      localStorage.setItem("referrer_id", finalReferrerId)

      // 登録ページにリダイレクト（パラメータ付き）
      const params = new URLSearchParams()
      params.set("coinw", coinwUid.trim())
      if (finalReferrerId) {
        params.set("ref", finalReferrerId)
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
            {hasRefParam && referrerValid && (
              <span className="text-green-400">紹介者ID: {referrerId} からの招待</span>
            )}
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

            {/* 紹介者ID入力セクション（URLにrefパラメータがない場合のみ表示） */}
            {!hasRefParam && (
              <div className="bg-purple-900 border border-purple-700 rounded-lg p-6">
                <div className="flex items-center mb-4">
                  <div className="bg-purple-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold mr-3">
                    2
                  </div>
                  <h3 className="text-xl font-semibold text-white">紹介者ID入力</h3>
                </div>

                <p className="text-purple-200 text-sm mb-4">
                  紹介者から受け取った6桁のIDを入力してください。
                </p>

                <div className="space-y-2">
                  <Label htmlFor="referrer-id" className="text-purple-200 text-sm font-medium">
                    紹介者ID <span className="text-red-400">*</span>
                  </Label>
                  <div className="relative">
                    <Input
                      id="referrer-id"
                      name="referrer-id"
                      type="text"
                      value={referrerIdInput}
                      onChange={handleReferrerIdChange}
                      placeholder="例: ABC123"
                      maxLength={6}
                      className={`bg-gray-700 border-gray-600 text-white placeholder-gray-400 focus:border-purple-500 focus:ring-purple-500 uppercase ${
                        referrerValid === true ? "border-green-500" : referrerValid === false ? "border-red-500" : ""
                      }`}
                      autoComplete="off"
                    />
                    {validatingReferrer && (
                      <div className="absolute right-3 top-1/2 -translate-y-1/2">
                        <Loader2 className="w-5 h-5 text-purple-400 animate-spin" />
                      </div>
                    )}
                    {!validatingReferrer && referrerValid === true && (
                      <div className="absolute right-3 top-1/2 -translate-y-1/2">
                        <CheckCircle className="w-5 h-5 text-green-500" />
                      </div>
                    )}
                    {!validatingReferrer && referrerValid === false && referrerIdInput.length > 0 && (
                      <div className="absolute right-3 top-1/2 -translate-y-1/2">
                        <AlertCircle className="w-5 h-5 text-red-500" />
                      </div>
                    )}
                  </div>
                  {referrerValid === true && referrerName && (
                    <p className="text-xs text-green-400">
                      紹介者: {referrerName}
                    </p>
                  )}
                  {referrerValid === false && referrerIdInput.length > 0 && (
                    <p className="text-xs text-red-400">
                      この紹介者IDは存在しません。正しいIDを入力してください。
                    </p>
                  )}
                  <p className="text-xs text-purple-300">
                    紹介者からのリンクでアクセスした場合は自動入力されます
                  </p>
                </div>
              </div>
            )}

            {/* URLから紹介者IDが取得できた場合の表示 */}
            {hasRefParam && referrerValid === true && (
              <div className="bg-green-900/30 border border-green-700 rounded-lg p-4">
                <div className="flex items-center">
                  <CheckCircle className="w-5 h-5 text-green-500 mr-2" />
                  <div>
                    <p className="text-green-400 font-medium">紹介者が確認されました</p>
                    <p className="text-sm text-green-300">
                      紹介者ID: {referrerId}
                      {referrerName && ` (${referrerName})`}
                    </p>
                  </div>
                </div>
              </div>
            )}

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
