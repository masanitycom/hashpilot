"use client"

import React, { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  Shield,
  AlertTriangle,
  Search,
  RefreshCw,
  Download,
  Clock,
  TrendingUp,
  Users,
  Activity,
  Database
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface DailyYieldLogData {
  date: string
  yield_rate: number
  margin_rate: number
  user_rate: number
  is_month_end: boolean
  created_at: string
  created_by: string | null
  admin_user_id: string | null
  notes: string | null
}

interface SystemLogData {
  id: string
  log_type: string
  operation: string
  user_id: string | null
  message: string
  details: any
  created_at: string
}

interface AdminData {
  user_id: string
  email: string
  role: string
  created_at: string
}

interface CreatorAnalysis {
  created_by: string | null
  admin_user_id: string | null
  creation_count: number
  avg_margin_rate: number
  max_margin_rate: number
  first_creation: string
  last_creation: string
}

export default function EmergencyInvestigationPage() {
  const [dailyYieldLogs, setDailyYieldLogs] = useState<DailyYieldLogData[]>([])
  const [systemLogs, setSystemLogs] = useState<SystemLogData[]>([])
  const [adminUsers, setAdminUsers] = useState<AdminData[]>([])
  const [creatorAnalysis, setCreatorAnalysis] = useState<CreatorAnalysis[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)
      
      // 緊急対応: 管理者チェック
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await investigate()
        return
      }

      // 通常の管理者チェック
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        setError("管理者権限がありません")
        router.push("/admin")
        return
      }

      setIsAdmin(true)
      await investigate()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const investigate = async () => {
    try {
      setLoading(true)
      
      // 1. daily_yield_logの全履歴を取得
      const { data: yieldLogs, error: yieldError } = await supabase
        .from("daily_yield_log")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(50)

      if (yieldError) {
        console.error("Daily yield logs error:", yieldError)
      } else {
        setDailyYieldLogs(yieldLogs || [])
      }

      // 2. 関連するシステムログを取得
      const { data: sysLogs, error: sysError } = await supabase
        .from("system_logs")
        .select("*")
        .or("operation.ilike.%yield%,operation.ilike.%margin%,message.ilike.%3000%,message.ilike.%daily%")
        .order("created_at", { ascending: false })
        .limit(50)

      if (sysError) {
        console.error("System logs error:", sysError)
      } else {
        setSystemLogs(sysLogs || [])
      }

      // 3. 管理者アカウント一覧を取得
      const { data: admins, error: adminError } = await supabase
        .from("admins")
        .select("user_id, email, role, created_at")
        .order("created_at", { ascending: false })

      if (adminError) {
        console.error("Admins error:", adminError)
      } else {
        setAdminUsers(admins || [])
      }

      // 4. 作成者別分析のための集計
      if (yieldLogs && yieldLogs.length > 0) {
        const analysis = analyzeCreators(yieldLogs)
        setCreatorAnalysis(analysis)
      }

    } catch (error) {
      console.error("Investigation error:", error)
      setError("調査中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const analyzeCreators = (logs: DailyYieldLogData[]): CreatorAnalysis[] => {
    const creatorMap = new Map<string, {
      created_by: string | null
      admin_user_id: string | null
      creation_count: number
      margin_rates: number[]
      first_creation: string
      last_creation: string
    }>()

    logs.forEach(log => {
      const key = `${log.created_by || 'NULL'}-${log.admin_user_id || 'NULL'}`
      
      if (!creatorMap.has(key)) {
        creatorMap.set(key, {
          created_by: log.created_by,
          admin_user_id: log.admin_user_id,
          creation_count: 0,
          margin_rates: [],
          first_creation: log.created_at,
          last_creation: log.created_at
        })
      }

      const creator = creatorMap.get(key)!
      creator.creation_count++
      creator.margin_rates.push(log.margin_rate)
      
      if (log.created_at < creator.first_creation) {
        creator.first_creation = log.created_at
      }
      if (log.created_at > creator.last_creation) {
        creator.last_creation = log.created_at
      }
    })

    return Array.from(creatorMap.values()).map(creator => ({
      created_by: creator.created_by,
      admin_user_id: creator.admin_user_id,
      creation_count: creator.creation_count,
      avg_margin_rate: creator.margin_rates.reduce((a, b) => a + b, 0) / creator.margin_rates.length,
      max_margin_rate: Math.max(...creator.margin_rates),
      first_creation: creator.first_creation,
      last_creation: creator.last_creation
    })).sort((a, b) => b.creation_count - a.creation_count)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("ja-JP", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    })
  }

  const exportInvestigationData = () => {
    const csvContent = [
      "=== DAILY YIELD LOG INVESTIGATION ===",
      "",
      "Date,Yield Rate,Margin Rate,User Rate,Month End,Created At,Created By,Admin User ID,Notes",
      ...dailyYieldLogs.map(log => [
        log.date,
        log.yield_rate,
        log.margin_rate,
        log.user_rate,
        log.is_month_end,
        log.created_at,
        log.created_by || "",
        log.admin_user_id || "",
        log.notes || ""
      ].join(",")),
      "",
      "=== CREATOR ANALYSIS ===",
      "",
      "Created By,Admin User ID,Creation Count,Avg Margin Rate,Max Margin Rate,First Creation,Last Creation",
      ...creatorAnalysis.map(analysis => [
        analysis.created_by || "NULL",
        analysis.admin_user_id || "NULL",
        analysis.creation_count,
        analysis.avg_margin_rate.toFixed(2),
        analysis.max_margin_rate,
        analysis.first_creation,
        analysis.last_creation
      ].join(",")),
      "",
      "=== SYSTEM LOGS ===",
      "",
      "Type,Operation,User ID,Message,Created At",
      ...systemLogs.map(log => [
        log.log_type,
        log.operation,
        log.user_id || "",
        `"${log.message.replace(/"/g, '""')}"`,
        log.created_at
      ].join(","))
    ].join("\n")

    // BOM（Byte Order Mark）を追加してExcelで文字化けを防ぐ
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF])
    const blob = new Blob([bom, csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    const url = URL.createObjectURL(blob)
    link.setAttribute("href", url)
    link.setAttribute("download", `emergency_investigation_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>管理者権限が必要です。</p>
            <Button
              onClick={() => router.push("/admin")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              管理者ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  const anomalyLogs = dailyYieldLogs.filter(log => log.margin_rate > 100)
  const normalLogs = dailyYieldLogs.filter(log => log.margin_rate <= 100)

  return (
    <div className="min-h-screen bg-black">
      <div className="max-w-7xl mx-auto p-4 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <AlertTriangle className="h-6 w-6 text-red-400" />
              緊急調査: 異常設定分析
            </h1>
          </div>
          <div className="flex items-center gap-2">
            <Button
              onClick={exportInvestigationData}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <Download className="w-4 h-4 mr-2" />
              調査結果出力
            </Button>
            <Button
              onClick={investigate}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <RefreshCw className="w-4 h-4 mr-2" />
              再調査
            </Button>
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
            >
              管理者ダッシュボード
            </Button>
          </div>
        </div>

        {/* 異常値統計 */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card className="bg-gradient-to-br from-red-900 to-red-800 border-red-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-red-100">
                <AlertTriangle className="h-4 w-4" />
                異常設定
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{anomalyLogs.length}件</div>
              <p className="text-xs text-red-200">マージン率100%超</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                <Database className="h-4 w-4" />
                正常設定
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{normalLogs.length}件</div>
              <p className="text-xs text-green-200">マージン率100%以下</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-900 to-blue-800 border-blue-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-blue-100">
                <Users className="h-4 w-4" />
                作成者数
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{creatorAnalysis.length}人</div>
              <p className="text-xs text-blue-200">設定作成者</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-900 to-purple-800 border-purple-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-purple-100">
                <Activity className="h-4 w-4" />
                関連ログ
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{systemLogs.length}件</div>
              <p className="text-xs text-purple-200">システムログ</p>
            </CardContent>
          </Card>
        </div>

        {/* 異常設定の詳細 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-red-400" />
              異常なマージン率設定（100%超）
            </CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8">
                <div className="text-white">調査中...</div>
              </div>
            ) : anomalyLogs.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-green-400">異常設定は見つかりませんでした</p>
              </div>
            ) : (
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {anomalyLogs.map((log, index) => (
                  <div
                    key={index}
                    className="bg-red-900/20 border border-red-700 rounded-lg p-3 space-y-2"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <Badge className="bg-red-600 text-white">
                          {log.margin_rate}%
                        </Badge>
                        <Badge variant="outline" className="border-gray-500 text-gray-300">
                          {log.date}
                        </Badge>
                        <Badge variant="outline" className="border-blue-500 text-blue-300">
                          利率: {log.yield_rate}%
                        </Badge>
                      </div>
                      <span className="text-gray-400 text-sm">
                        {formatDate(log.created_at)}
                      </span>
                    </div>

                    <div className="text-white text-sm">
                      作成者: {log.created_by || "不明"} | 
                      管理者ID: {log.admin_user_id || "不明"}
                      {log.notes && ` | 備考: ${log.notes}`}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* 作成者別分析 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Users className="h-5 w-5 text-blue-400" />
              作成者別分析
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {creatorAnalysis.map((analysis, index) => (
                <div
                  key={index}
                  className={`border rounded-lg p-3 space-y-2 ${
                    analysis.max_margin_rate > 100 
                      ? 'bg-red-900/20 border-red-700' 
                      : 'bg-gray-700/50 border-gray-600'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Badge className={analysis.max_margin_rate > 100 ? "bg-red-600" : "bg-green-600"}>
                        最大: {analysis.max_margin_rate}%
                      </Badge>
                      <Badge variant="outline" className="border-gray-500 text-gray-300">
                        {analysis.creation_count}件作成
                      </Badge>
                      <Badge variant="outline" className="border-blue-500 text-blue-300">
                        平均: {analysis.avg_margin_rate.toFixed(1)}%
                      </Badge>
                    </div>
                  </div>

                  <div className="text-white text-sm">
                    作成者: {analysis.created_by || "不明"} | 
                    管理者ID: {analysis.admin_user_id || "不明"}
                  </div>
                  
                  <div className="text-gray-400 text-xs">
                    期間: {formatDate(analysis.first_creation)} 〜 {formatDate(analysis.last_creation)}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* 管理者アカウント一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Shield className="h-5 w-5 text-purple-400" />
              管理者アカウント一覧
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {adminUsers.map((admin, index) => (
                <div
                  key={index}
                  className="bg-gray-700/50 border border-gray-600 rounded-lg p-3 flex items-center justify-between"
                >
                  <div className="flex items-center gap-3">
                    <Badge className="bg-purple-600">
                      {admin.role}
                    </Badge>
                    <span className="text-white">{admin.email}</span>
                    <span className="text-gray-400 text-sm">ID: {admin.user_id}</span>
                  </div>
                  <span className="text-gray-400 text-sm">
                    {formatDate(admin.created_at)}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* 関連システムログ */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Activity className="h-5 w-5 text-yellow-400" />
              関連システムログ
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {systemLogs.map((log, index) => (
                <div
                  key={index}
                  className="bg-gray-700/50 border border-gray-600 rounded-lg p-3 space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Badge className={
                        log.log_type === "ERROR" ? "bg-red-600" :
                        log.log_type === "WARNING" ? "bg-yellow-600" :
                        log.log_type === "SUCCESS" ? "bg-green-600" :
                        "bg-blue-600"
                      }>
                        {log.log_type}
                      </Badge>
                      <Badge variant="outline" className="border-gray-500 text-gray-300">
                        {log.operation}
                      </Badge>
                      {log.user_id && (
                        <Badge variant="outline" className="border-blue-500 text-blue-300">
                          {log.user_id}
                        </Badge>
                      )}
                    </div>
                    <span className="text-gray-400 text-sm">
                      {formatDate(log.created_at)}
                    </span>
                  </div>

                  <div className="text-white text-sm">
                    {log.message}
                  </div>

                  {log.details && Object.keys(log.details).length > 0 && (
                    <details className="text-xs">
                      <summary className="text-gray-400 cursor-pointer hover:text-white">
                        詳細情報
                      </summary>
                      <pre className="text-gray-300 mt-1 bg-gray-800 p-2 rounded overflow-x-auto">
                        {JSON.stringify(log.details, null, 2)}
                      </pre>
                    </details>
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {error && (
          <Alert className="border-red-500 bg-red-900/20">
            <AlertDescription className="text-red-300">{error}</AlertDescription>
          </Alert>
        )}
      </div>
    </div>
  )
}