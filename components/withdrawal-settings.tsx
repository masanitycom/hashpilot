"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Wallet, CheckCircle, AlertTriangle, Info } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface WithdrawalSettings {
  id?: string
  user_id: string
  withdrawal_address: string | null
  coinw_uid: string | null
  is_active: boolean
  created_at?: string
  updated_at?: string
}

interface WithdrawalSettingsProps {
  userId: string
}

export function WithdrawalSettings({ userId }: WithdrawalSettingsProps) {
  const [settings, setSettings] = useState<WithdrawalSettings | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const [formData, setFormData] = useState({
    withdrawal_address: "",
    coinw_uid: ""
  })

  useEffect(() => {
    if (userId) {
      fetchSettings()
    }
  }, [userId])

  const fetchSettings = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase
        .from("user_withdrawal_settings")
        .select("*")
        .eq("user_id", userId)
        .single()

      if (error && error.code !== "PGRST116") {
        throw error
      }

      if (data) {
        setSettings(data)
        setFormData({
          withdrawal_address: data.withdrawal_address || "",
          coinw_uid: data.coinw_uid || ""
        })
      } else {
        // 設定が存在しない場合
        setSettings(null)
        setFormData({
          withdrawal_address: "",
          coinw_uid: ""
        })
      }
    } catch (err: any) {
      console.error("Settings fetch error:", err)
      setError("設定の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const saveSettings = async () => {
    try {
      setSaving(true)
      setError("")
      setSuccess("")

      // バリデーション
      if (!formData.withdrawal_address && !formData.coinw_uid) {
        setError("送金先アドレスまたはCoinW UIDのいずれかを入力してください")
        return
      }

      const settingsData = {
        user_id: userId,
        withdrawal_address: formData.withdrawal_address || null,
        coinw_uid: formData.coinw_uid || null,
        is_active: true,
        updated_at: new Date().toISOString()
      }

      let result
      if (settings?.id) {
        // 更新
        result = await supabase
          .from("user_withdrawal_settings")
          .update(settingsData)
          .eq("id", settings.id)
          .select()
          .single()
      } else {
        // 新規作成
        result = await supabase
          .from("user_withdrawal_settings")
          .insert({
            ...settingsData,
            created_at: new Date().toISOString()
          })
          .select()
          .single()
      }

      if (result.error) {
        throw result.error
      }

      setSettings(result.data)
      setSuccess("送金先設定を保存しました")
    } catch (err: any) {
      console.error("Settings save error:", err)
      setError("設定の保存に失敗しました: " + err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }))
    setError("")
    setSuccess("")
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-gray-400">読み込み中...</div>
        </CardContent>
      </Card>
    )
  }

  const hasValidSettings = settings && (settings.withdrawal_address || settings.coinw_uid)

  return (
    <div className="space-y-6">
      {/* 月末出金の説明 */}
      <Alert className="border-blue-700/50 bg-blue-900/20">
        <Info className="h-4 w-4" />
        <AlertDescription className="text-blue-200">
          <div className="space-y-2">
            <p className="font-medium">月末自動出金について</p>
            <ul className="text-sm space-y-1 ml-4">
              <li>• 毎月月末に自動的に報酬が出金処理されます</li>
              <li>• 送金先アドレスまたはCoinW UIDの設定が必要です</li>
              <li>• 設定がない場合は出金が保留されます</li>
              <li>• 最小出金額は$10です</li>
            </ul>
          </div>
        </AlertDescription>
      </Alert>

      {/* 現在の設定状態 */}
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader>
          <CardTitle className="text-white flex items-center space-x-2">
            <Wallet className="h-5 w-5" />
            <span>月末出金設定</span>
            {hasValidSettings ? (
              <Badge className="bg-green-600 text-white">
                <CheckCircle className="h-3 w-3 mr-1" />
                設定済み
              </Badge>
            ) : (
              <Badge className="bg-red-600 text-white">
                <AlertTriangle className="h-3 w-3 mr-1" />
                未設定
              </Badge>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* CoinW UID設定 */}
          <div className="space-y-2">
            <Label htmlFor="coinw_uid" className="text-gray-300">
              CoinW UID（推奨）
            </Label>
            <Input
              id="coinw_uid"
              type="text"
              value={formData.coinw_uid}
              onChange={(e) => handleInputChange("coinw_uid", e.target.value)}
              placeholder="CoinW UIDを入力（例: 12345678）"
              className="bg-gray-700 border-gray-600 text-white"
            />
            <p className="text-xs text-gray-400">
              CoinW UIDがある場合は最優先で使用されます
            </p>
          </div>

          {/* 送金先アドレス設定 */}
          <div className="space-y-2">
            <Label htmlFor="withdrawal_address" className="text-gray-300">
              送金先アドレス
            </Label>
            <Input
              id="withdrawal_address"
              type="text"
              value={formData.withdrawal_address}
              onChange={(e) => handleInputChange("withdrawal_address", e.target.value)}
              placeholder="USDT送金先アドレスを入力"
              className="bg-gray-700 border-gray-600 text-white"
            />
            <p className="text-xs text-gray-400">
              TRC20 USDT対応アドレスを正確に入力してください
            </p>
          </div>

          {/* 保存ボタン */}
          <Button 
            onClick={saveSettings}
            disabled={saving}
            className="w-full bg-blue-600 hover:bg-blue-700"
          >
            {saving ? "保存中..." : "設定を保存"}
          </Button>

          {/* エラー・成功メッセージ */}
          {error && (
            <Alert className="border-red-500/50 bg-red-900/20">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription className="text-red-200">{error}</AlertDescription>
            </Alert>
          )}

          {success && (
            <Alert className="border-green-500/50 bg-green-900/20">
              <CheckCircle className="h-4 w-4" />
              <AlertDescription className="text-green-200">{success}</AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* 現在の設定表示 */}
      {hasValidSettings && (
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white text-sm">現在の設定</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {settings?.coinw_uid && (
              <div className="flex items-center justify-between p-3 bg-blue-900/20 rounded-lg">
                <div>
                  <p className="text-sm font-medium text-blue-300">CoinW UID</p>
                  <p className="text-xs text-gray-400">最優先で使用されます</p>
                </div>
                <Badge className="bg-blue-600 text-white">
                  {settings.coinw_uid}
                </Badge>
              </div>
            )}

            {settings?.withdrawal_address && (
              <div className="flex items-center justify-between p-3 bg-green-900/20 rounded-lg">
                <div>
                  <p className="text-sm font-medium text-green-300">送金先アドレス</p>
                  <p className="text-xs text-gray-400 font-mono break-all">
                    {settings.withdrawal_address.slice(0, 10)}...{settings.withdrawal_address.slice(-10)}
                  </p>
                </div>
                <Badge className="bg-green-600 text-white">設定済み</Badge>
              </div>
            )}

            <div className="text-xs text-gray-400 pt-2">
              最終更新: {settings?.updated_at ? new Date(settings.updated_at).toLocaleString('ja-JP') : '未設定'}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export { WithdrawalSettings }