"use client"

import { useEffect, useState } from "react"
import { User } from "@supabase/supabase-js"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Loader2, Edit, Save, X, Copy, Check, Share2, QrCode } from "lucide-react"
import { supabase } from "@/lib/supabase"
import QRCode from "qrcode.react"

interface UserProfile {
  id: string
  user_id: string
  email: string
  full_name: string
  coinw_uid: string
  created_at: string
  total_purchases: number
  referral_count: number
  reward_address_bep20: string | null
  nft_receive_address: string | null
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
    reward_address_bep20: "",
    nft_receive_address: "",
  })
  const [showQR, setShowQR] = useState(false)

  useEffect(() => {
    fetchProfile()
  }, [])

  const fetchProfile = async () => {
    try {
      setLoading(true)
      setError("")

      const { data: { user } } = await supabase.auth.getUser()
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
          total_purchases,
          reward_address_bep20,
          nft_receive_address
        `)
        .eq("id", user.id)
        .single()

      if (userError) throw userError

      // 紹介者数を取得
      const { count: referralCount } = await supabase
        .from("users")
        .select("id", { count: "exact", head: true })
        .eq("referrer_user_id", userData.user_id)

      const profileData = {
        ...userData,
        referral_count: referralCount || 0,
      }

      setProfile(profileData)
      setEditForm({
        full_name: userData.full_name || "",
        coinw_uid: userData.coinw_uid || "",
        reward_address_bep20: userData.reward_address_bep20 || "",
        nft_receive_address: userData.nft_receive_address || "",
      })
    } catch (error: any) {
      console.error("Profile fetch error:", error)
      setError(`プロフィールの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const updateProfile = async () => {
    try {
      setSaving(true)
      setError("")
      setSuccess("")

      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setError("ログインが必要です")
        return
      }

      const { error: updateError } = await supabase
        .from("users")
        .update({
          full_name: editForm.full_name,
          coinw_uid: editForm.coinw_uid,
          reward_address_bep20: editForm.reward_address_bep20,
          nft_receive_address: editForm.nft_receive_address,
        })
        .eq("id", user.id)

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

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text)
    setSuccess(`${label}をコピーしました`)
    setTimeout(() => setSuccess(""), 2000)
  }

  const getReferralLink = () => {
    if (!profile?.user_id) return ""
    return `https://hashpilot.net/register?ref=${profile.user_id}`
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-blue-400" />
      </div>
    )
  }

  if (error && !profile) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
        <Card className="bg-red-900/20 border-red-500/50 max-w-md w-full mx-4">
          <CardContent className="p-6 text-center">
            <div className="text-red-400 mb-4">エラー</div>
            <div className="text-white mb-4">{error}</div>
            <Button onClick={fetchProfile} variant="outline" className="bg-transparent border-red-500/50 text-red-400 hover:bg-red-900/20">
              再試行
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black p-4">
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-white mb-2">プロフィール</h1>
          <p className="text-gray-400">アカウント情報を確認・編集できます</p>
        </div>

        {error && (
          <Card className="bg-red-900/20 border-red-500/50">
            <CardContent className="p-4 text-red-400 text-center">
              {error}
            </CardContent>
          </Card>
        )}

        {success && (
          <Card className="bg-green-900/20 border-green-500/50">
            <CardContent className="p-4 text-green-400 text-center">
              {success}
            </CardContent>
          </Card>
        )}

        <Card className="bg-gray-900/50 border-gray-700">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-white">基本情報</CardTitle>
            <Button
              onClick={() => editing ? setEditing(false) : setEditing(true)}
              variant="outline"
              size="sm"
              className="text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent"
            >
              {editing ? <X className="h-4 w-4" /> : <Edit className="h-4 w-4" />}
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <Label className="text-gray-300">ユーザーID</Label>
                <div className="flex items-center space-x-2 mt-1">
                  <div className="text-white font-mono">{profile?.user_id}</div>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => copyToClipboard(profile?.user_id || "", "ユーザーID")}
                    className="p-1 h-6 w-6"
                  >
                    <Copy className="h-3 w-3" />
                  </Button>
                </div>
              </div>

              <div>
                <Label className="text-gray-300">メールアドレス</Label>
                <div className="text-white mt-1">{profile?.email}</div>
              </div>

              <div>
                <Label className="text-gray-300">氏名</Label>
                {editing ? (
                  <Input
                    value={editForm.full_name}
                    onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                    className="bg-gray-800 border-gray-600 text-white"
                    placeholder="氏名を入力"
                  />
                ) : (
                  <div className="text-white mt-1">{profile?.full_name || "未設定"}</div>
                )}
              </div>

              <div>
                <Label className="text-gray-300">CoinW UID</Label>
                {editing ? (
                  <Input
                    value={editForm.coinw_uid}
                    onChange={(e) => setEditForm({ ...editForm, coinw_uid: e.target.value })}
                    className="bg-gray-800 border-gray-600 text-white"
                    placeholder="CoinW UIDを入力"
                  />
                ) : (
                  <div className="text-white mt-1">{profile?.coinw_uid || "未設定"}</div>
                )}
              </div>

              <div>
                <Label className="text-gray-300">総投資額</Label>
                <div className="text-white mt-1">${profile?.total_purchases?.toLocaleString() || "0"}</div>
              </div>

              <div>
                <Label className="text-gray-300">紹介者数</Label>
                <div className="text-white mt-1">{profile?.referral_count || 0}人</div>
              </div>

              <div>
                <Label className="text-gray-300">登録日</Label>
                <div className="text-white mt-1">
                  {profile?.created_at ? new Date(profile.created_at).toLocaleDateString('ja-JP') : "不明"}
                </div>
              </div>

              <div>
                <Label className="text-gray-300">報酬受取アドレス (USDT BEP20)</Label>
                {editing ? (
                  <Input
                    value={editForm.reward_address_bep20}
                    onChange={(e) => setEditForm({ ...editForm, reward_address_bep20: e.target.value })}
                    className="bg-gray-800 border-gray-600 text-white"
                    placeholder="0x... (BEP20アドレス)"
                  />
                ) : (
                  <div className="text-white mt-1 break-all">{profile?.reward_address_bep20 || "未設定"}</div>
                )}
              </div>

              <div>
                <Label className="text-gray-300">NFT受取アドレス</Label>
                {editing ? (
                  <Input
                    value={editForm.nft_receive_address}
                    onChange={(e) => setEditForm({ ...editForm, nft_receive_address: e.target.value })}
                    className="bg-gray-800 border-gray-600 text-white"
                    placeholder="0x... (NFT受取用アドレス)"
                  />
                ) : (
                  <div className="text-white mt-1 break-all">{profile?.nft_receive_address || "未設定"}</div>
                )}
              </div>
            </div>

            {editing && (
              <div className="flex space-x-2 pt-4">
                <Button
                  onClick={updateProfile}
                  disabled={saving}
                  className="bg-blue-600 hover:bg-blue-700 text-white"
                >
                  {saving ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Save className="h-4 w-4 mr-2" />}
                  保存
                </Button>
                <Button
                  onClick={() => setEditing(false)}
                  variant="outline"
                  className="bg-transparent border-gray-600 text-gray-300 hover:bg-gray-700"
                >
                  キャンセル
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="bg-gray-900/50 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center space-x-2">
              <Share2 className="h-5 w-5" />
              <span>紹介リンク</span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label className="text-gray-300">あなたの紹介リンク</Label>
              <div className="flex items-center space-x-2 mt-2">
                <div className="flex-1 bg-gray-800 border border-gray-600 rounded-md p-3 text-white break-all">
                  {getReferralLink()}
                </div>
                <Button
                  onClick={() => copyToClipboard(getReferralLink(), "紹介リンク")}
                  variant="outline"
                  size="sm"
                  className="text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent"
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <div className="flex justify-center">
              <Button
                onClick={() => setShowQR(!showQR)}
                variant="outline"
                className="text-gray-300 border-gray-600 hover:bg-gray-700 bg-transparent"
              >
                <QrCode className="h-4 w-4 mr-2" />
                {showQR ? "QRコードを非表示" : "QRコードを表示"}
              </Button>
            </div>

            {showQR && (
              <div className="flex justify-center mt-4">
                <div className="bg-white p-4 rounded-lg">
                  <QRCode value={getReferralLink()} size={200} />
                </div>
              </div>
            )}

            <div className="text-sm text-gray-400 text-center">
              このリンクから登録されたユーザーがあなたの紹介者となります
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}