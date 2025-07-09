"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Copy, Edit, Save, X, QrCode, Link, Wallet, TrendingUp, Users, DollarSign } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface UserProfile {
  id: string
  user_id: string
  email: string
  full_name: string
  coinw_uid: string
  btc_address: string
  eth_address: string
  usdt_address: string
  created_at: string
  total_purchases: number
  nft_count: number
  referral_count: number
  referrer_id: string
}

export default function ProfilePage() {
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const [editForm, setEditForm] = useState({
    full_name: "",
    coinw_uid: "",
  })

  useEffect(() => {
    fetchProfile()
  }, [])

  const fetchProfile = async () => {
    try {
      setLoading(true)
      setError("")

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        setError("ログインが必要です")
        return
      }

      const { data: userData, error: userError } = await supabase
        .from("users")
        .select(`
          id,
          user_id,
          email,
          full_name,
          coinw_uid,
          created_at,
          total_purchases
        `)
        .eq("user_id", user.id)
        .single()

      if (userError) throw userError

      // 紹介者数を取得
      const { count: referralCount } = await supabase
        .from("users")
        .select("*", { count: "exact", head: true })
        .eq("referrer_id", userData.user_id)

      setProfile({
        ...userData,
        referral_count: referralCount || 0,
      })

      setEditForm({
        full_name: userData.full_name || "",
        btc_address: userData.btc_address || "",
        eth_address: userData.eth_address || "",
        usdt_address: userData.usdt_address || "",
      })
    } catch (error: any) {
      setError(`プロフィールの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    try {
      setSaving(true)
      setError("")
      setSuccess("")

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        setError("ログインが必要です")
        return
      }

      const { error: updateError } = await supabase
        .from("users")
        .update({
          full_name: editForm.full_name,
          coinw_uid: editForm.coinw_uid,
        })
        .eq("user_id", user.id)

      if (updateError) throw updateError

      setSuccess("プロフィールを更新しました")
      setEditing(false)
      await fetchProfile()
    } catch (error: any) {
      setError(`更新に失敗しました: ${error.message}`)
    } finally {
      setSaving(false)
    }
  }

  const copyToClipboard = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      setSuccess(`${label}をコピーしました`)
      setTimeout(() => setSuccess(""), 3000)
    } catch (error) {
      setError("コピーに失敗しました")
    }
  }

  const getReferralLink = () => {
    if (!profile) return ""
    return `${window.location.origin}/register?ref=${profile.user_id}`
  }

  const getQRCodeUrl = () => {
    const referralLink = getReferralLink()
    return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(referralLink)}`
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-white">読み込み中...</div>
      </div>
    )
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-red-400">プロフィールが見つかりません</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-4xl mx-auto space-y-6">
        {/* ヘッダー */}
        <div className="text-center">
          <h1 className="text-3xl font-bold text-white mb-2">プロフィール</h1>
          <p className="text-gray-400">アカウント情報と設定を管理</p>
        </div>

        {/* アラート */}
        {error && (
          <Alert className="bg-red-900 border-red-700">
            <AlertDescription className="text-red-200">{error}</AlertDescription>
          </Alert>
        )}

        {success && (
          <Alert className="bg-green-900 border-green-700">
            <AlertDescription className="text-green-200">{success}</AlertDescription>
          </Alert>
        )}

        {/* 統計カード */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <DollarSign className="h-5 w-5 text-green-400" />
                <div>
                  <div className="text-2xl font-bold text-green-400">${profile.total_purchases.toLocaleString()}</div>
                  <div className="text-xs text-gray-400">総投資額</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <QrCode className="h-5 w-5 text-blue-400" />
                <div>
                  <div className="text-2xl font-bold text-blue-400">{profile.nft_count}</div>
                  <div className="text-xs text-gray-400">NFT保有数</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <Users className="h-5 w-5 text-purple-400" />
                <div>
                  <div className="text-2xl font-bold text-purple-400">{profile.referral_count}</div>
                  <div className="text-xs text-gray-400">紹介者数</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center space-x-2">
                <TrendingUp className="h-5 w-5 text-orange-400" />
                <div>
                  <div className="text-2xl font-bold text-orange-400">
                    {profile.total_purchases > 0
                      ? Math.round((profile.total_purchases / profile.nft_count) * 100) / 100
                      : 0}
                    %
                  </div>
                  <div className="text-xs text-gray-400">投資効率</div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 基本情報 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle className="text-white">基本情報</CardTitle>
              <CardDescription className="text-gray-400">アカウントの基本情報</CardDescription>
            </div>
            {!editing ? (
              <Button
                onClick={() => setEditing(true)}
                variant="outline"
                size="sm"
                className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
              >
                <Edit className="w-4 h-4 mr-2" />
                編集
              </Button>
            ) : (
              <div className="flex space-x-2">
                <Button onClick={handleSave} disabled={saving} size="sm" className="bg-blue-600 hover:bg-blue-700">
                  <Save className="w-4 h-4 mr-2" />
                  {saving ? "保存中..." : "保存"}
                </Button>
                <Button
                  onClick={() => {
                    setEditing(false)
                    setEditForm({
                      full_name: profile.full_name || "",
                      btc_address: profile.btc_address || "",
                      eth_address: profile.eth_address || "",
                      usdt_address: profile.usdt_address || "",
                    })
                  }}
                  variant="outline"
                  size="sm"
                  className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                >
                  <X className="w-4 h-4 mr-2" />
                  キャンセル
                </Button>
              </div>
            )}
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="text-gray-300">ユーザーID</Label>
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono">
                    {profile.user_id}
                  </div>
                  <Button
                    onClick={() => copyToClipboard(profile.user_id, "ユーザーID")}
                    variant="outline"
                    size="sm"
                    className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                  >
                    <Copy className="w-4 h-4" />
                  </Button>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-gray-300">メールアドレス</Label>
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white">
                    {profile.email}
                  </div>
                  <Button
                    onClick={() => copyToClipboard(profile.email, "メールアドレス")}
                    variant="outline"
                    size="sm"
                    className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                  >
                    <Copy className="w-4 h-4" />
                  </Button>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-gray-300">氏名</Label>
                {editing ? (
                  <Input
                    value={editForm.full_name}
                    onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white"
                    placeholder="氏名を入力"
                  />
                ) : (
                  <div className="p-2 bg-gray-700 rounded border border-gray-600 text-white">
                    {profile.full_name || "未設定"}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label className="text-gray-300">CoinW UID</Label>
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono">
                    {profile.coinw_uid || "未設定"}
                  </div>
                  {profile.coinw_uid && (
                    <Button
                      onClick={() => copyToClipboard(profile.coinw_uid, "CoinW UID")}
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-gray-300">登録日</Label>
                <div className="p-2 bg-gray-700 rounded border border-gray-600 text-white">
                  {new Date(profile.created_at).toLocaleDateString("ja-JP")}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* ウォレットアドレス */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Wallet className="w-5 h-5 mr-2" />
              ウォレットアドレス
            </CardTitle>
            <CardDescription className="text-gray-400">暗号通貨の受取アドレスを管理</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label className="text-gray-300">Bitcoin (BTC)</Label>
              {editing ? (
                <Input
                  value={editForm.btc_address}
                  onChange={(e) => setEditForm({ ...editForm, btc_address: e.target.value })}
                  className="bg-gray-700 border-gray-600 text-white font-mono"
                  placeholder="BTCアドレスを入力"
                />
              ) : (
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono text-sm">
                    {profile.btc_address || "未設定"}
                  </div>
                  {profile.btc_address && (
                    <Button
                      onClick={() => copyToClipboard(profile.btc_address, "BTCアドレス")}
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              )}
            </div>

            <div className="space-y-2">
              <Label className="text-gray-300">Ethereum (ETH)</Label>
              {editing ? (
                <Input
                  value={editForm.eth_address}
                  onChange={(e) => setEditForm({ ...editForm, eth_address: e.target.value })}
                  className="bg-gray-700 border-gray-600 text-white font-mono"
                  placeholder="ETHアドレスを入力"
                />
              ) : (
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono text-sm">
                    {profile.eth_address || "未設定"}
                  </div>
                  {profile.eth_address && (
                    <Button
                      onClick={() => copyToClipboard(profile.eth_address, "ETHアドレス")}
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              )}
            </div>

            <div className="space-y-2">
              <Label className="text-gray-300">Tether (USDT)</Label>
              {editing ? (
                <Input
                  value={editForm.usdt_address}
                  onChange={(e) => setEditForm({ ...editForm, usdt_address: e.target.value })}
                  className="bg-gray-700 border-gray-600 text-white font-mono"
                  placeholder="USDTアドレスを入力"
                />
              ) : (
                <div className="flex items-center space-x-2">
                  <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono text-sm">
                    {profile.usdt_address || "未設定"}
                  </div>
                  {profile.usdt_address && (
                    <Button
                      onClick={() => copyToClipboard(profile.usdt_address, "USDTアドレス")}
                      variant="outline"
                      size="sm"
                      className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* 紹介システム */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Link className="w-5 w-5 mr-2" />
              紹介システム
            </CardTitle>
            <CardDescription className="text-gray-400">あなたの紹介リンクとコード</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label className="text-gray-300">紹介コード</Label>
              <div className="flex items-center space-x-2">
                <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white font-mono text-lg font-bold">
                  {profile.user_id}
                </div>
                <Button
                  onClick={() => copyToClipboard(profile.user_id, "紹介コード")}
                  variant="outline"
                  size="sm"
                  className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                >
                  <Copy className="w-4 h-4" />
                </Button>
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-gray-300">紹介リンク</Label>
              <div className="flex items-center space-x-2">
                <div className="flex-1 p-2 bg-gray-700 rounded border border-gray-600 text-white text-sm break-all">
                  {getReferralLink()}
                </div>
                <Button
                  onClick={() => copyToClipboard(getReferralLink(), "紹介リンク")}
                  variant="outline"
                  size="sm"
                  className="border-gray-600 text-white hover:bg-gray-700 bg-transparent"
                >
                  <Copy className="w-4 h-4" />
                </Button>
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-gray-300">QRコード</Label>
              <div className="flex items-center justify-center p-4 bg-white rounded">
                <img src={getQRCodeUrl() || "/placeholder.svg"} alt="紹介リンクQRコード" className="w-48 h-48" />
              </div>
              <p className="text-xs text-gray-400 text-center">このQRコードをスキャンして紹介リンクにアクセス</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
