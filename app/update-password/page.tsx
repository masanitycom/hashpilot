"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Loader2, Eye, EyeOff, Lock, CheckCircle, AlertCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

export default function UpdatePasswordPage() {
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")
  const [sessionChecked, setSessionChecked] = useState(false)
  const [hasRecoverySession, setHasRecoverySession] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkRecoverySession()
  }, [])

  const checkRecoverySession = async () => {
    try {
      const { data: { session }, error } = await supabase.auth.getSession()
      
      if (error) {
        console.error("Session check error:", error)
        setError("セッションの確認でエラーが発生しました")
        setSessionChecked(true)
        return
      }

      // URLパラメータからリセットモードをチェック
      const urlParams = new URLSearchParams(window.location.search)
      const isFromReset = urlParams.get('from') === 'reset'
      const hasToken = urlParams.get('token') !== null

      console.log("Password reset detection:", {
        isFromReset,
        hasToken,
        hasSession: !!session?.user,
        url: window.location.href
      })

      // パスワードリセット用のセッションがあるかチェック
      if (session?.user) {
        const user = session.user
        
        // より確実なリセット検出ロジック
        const isRecoverySession = (
          isFromReset ||  // URLパラメータで明示的にリセットと判定
          hasToken ||     // トークンが存在
          user.recovery_sent_at !== null || 
          user.email_change_sent_at !== null ||
          // 新しいセッションの場合（リセット直後）
          (user.aud === 'authenticated' && Date.now() - new Date(user.created_at).getTime() < 10 * 60 * 1000) // 10分以内のセッション
        )
        
        if (isRecoverySession) {
          setHasRecoverySession(true)
          console.log("Recovery session found:", user.id, {
            recovery_sent_at: user.recovery_sent_at,
            email_change_sent_at: user.email_change_sent_at,
            isFromReset: isFromReset,
            hasToken: hasToken,
            created_at: user.created_at,
            sessionAge: Date.now() - new Date(user.created_at).getTime()
          })
        } else {
          setHasRecoverySession(false)
          setError("パスワード変更セッションが見つかりません。パスワードリセットメールから再度アクセスしてください。")
          console.log("Recovery session not detected:", {
            recovery_sent_at: user.recovery_sent_at,
            email_change_sent_at: user.email_change_sent_at,
            isFromReset: isFromReset,
            hasToken: hasToken,
            sessionAge: Date.now() - new Date(user.created_at).getTime()
          })
        }
      } else {
        setHasRecoverySession(false)
        setError("パスワード変更セッションが見つかりません。パスワードリセットメールから再度アクセスしてください。")
        console.log("No session found")
      }
    } catch (error: any) {
      console.error("Recovery session check error:", error)
      setError("セッションの確認中にエラーが発生しました")
    } finally {
      setSessionChecked(true)
    }
  }

  const validatePassword = (password: string) => {
    if (password.length < 8) {
      return "パスワードは8文字以上である必要があります"
    }
    if (!/(?=.*[a-z])/.test(password)) {
      return "パスワードに小文字を含める必要があります"
    }
    if (!/(?=.*\d)/.test(password)) {
      return "パスワードに数字を含める必要があります"
    }
    return null
  }

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!hasRecoverySession) {
      setError("有効なパスワードリセットセッションがありません")
      return
    }

    // パスワードバリデーション
    const passwordError = validatePassword(password)
    if (passwordError) {
      setError(passwordError)
      return
    }

    if (password !== confirmPassword) {
      setError("パスワードが一致しません")
      return
    }

    setLoading(true)
    setError("")
    setSuccess("")

    try {
      const { data, error } = await supabase.auth.updateUser({
        password: password
      })

      if (error) {
        throw error
      }

      setSuccess("パスワードが正常に更新されました")
      
      // 即座にセッションを終了してログインページに移動
      await supabase.auth.signOut()
      
      // すぐにログインページにリダイレクト（セッション終了を待つ）
      setTimeout(() => {
        window.location.href = "/login"
      }, 1000)
      
    } catch (error: any) {
      console.error("Password update error:", error)
      setError(`パスワードの更新に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  // セッションチェック中の読み込み画面
  if (!sessionChecked) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>認証確認中...</span>
        </div>
      </div>
    )
  }

  // 有効なリカバリーセッションがない場合
  if (!hasRecoverySession) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader className="text-center">
            <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle className="w-8 h-8 text-red-600" />
            </div>
            <CardTitle className="text-2xl font-bold text-white">アクセスエラー</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-gray-300 text-center">
              有効なパスワードリセットセッションが見つかりません。
            </p>
            <p className="text-sm text-gray-400 text-center">
              パスワードリセットメールから再度アクセスしてください。
            </p>
            {error && (
              <Alert className="bg-red-900/20 border-red-700">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription className="text-red-400">{error}</AlertDescription>
              </Alert>
            )}
            <div className="flex flex-col space-y-2">
              <Link href="/reset-password">
                <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white">
                  パスワードリセットページへ
                </Button>
              </Link>
              <Link href="/login">
                <Button variant="outline" className="w-full">
                  ログインページへ
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
      <Card className="w-full max-w-md bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Lock className="w-8 h-8 text-blue-600" />
          </div>
          <CardTitle className="text-2xl font-bold text-white">新しいパスワードを設定</CardTitle>
          <p className="text-gray-400">
            アカウントのセキュリティのため、強力なパスワードを設定してください
          </p>
        </CardHeader>
        <CardContent>
          {error && (
            <Alert className="mb-4 bg-red-900/20 border-red-700">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription className="text-red-400">{error}</AlertDescription>
            </Alert>
          )}

          {success && (
            <Alert className="mb-4 bg-green-900/20 border-green-700">
              <CheckCircle className="h-4 w-4" />
              <AlertDescription className="text-green-400">
                {success}
                <br />
                <span className="text-sm">ログインページに移動します...</span>
              </AlertDescription>
            </Alert>
          )}

          <form onSubmit={handleUpdatePassword} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="password" className="text-white">新しいパスワード</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white pr-10"
                  placeholder="新しいパスワードを入力"
                  required
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="absolute right-0 top-0 h-full px-3 text-gray-400 hover:text-white"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="confirmPassword" className="text-white">パスワード確認</Label>
              <div className="relative">
                <Input
                  id="confirmPassword"
                  type={showConfirmPassword ? "text" : "password"}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white pr-10"
                  placeholder="パスワードを再入力"
                  required
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="absolute right-0 top-0 h-full px-3 text-gray-400 hover:text-white"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                >
                  {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
            </div>

            <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-3">
              <p className="text-sm text-blue-400 font-medium mb-2">パスワード要件:</p>
              <ul className="text-xs text-blue-300 space-y-1">
                <li>• 8文字以上</li>
                <li>• 小文字を含む</li>
                <li>• 数字を含む</li>
              </ul>
            </div>

            <Button
              type="submit"
              disabled={loading || !password || !confirmPassword}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  更新中...
                </>
              ) : (
                "パスワードを更新"
              )}
            </Button>
          </form>

          <div className="mt-6 text-center">
            <Link href="/login" className="text-sm text-blue-400 hover:text-blue-300">
              ログインページに戻る
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}