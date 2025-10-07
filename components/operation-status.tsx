"use client"

import { Badge } from "@/components/ui/badge"
import { CalendarDays, TrendingUp, Clock, AlertCircle } from "lucide-react"

interface OperationStatusProps {
  approvalDate: string | null
  variant?: "default" | "compact"
}

export function OperationStatus({ approvalDate, variant = "default" }: OperationStatusProps) {
  if (!approvalDate) {
    if (variant === "compact") {
      return (
        <div className="text-xs">
          <span className="text-gray-500">未承認</span>
        </div>
      )
    }
    return (
      <div className="flex items-center gap-2">
        <Badge variant="secondary" className="flex items-center gap-1 text-xs">
          <Clock className="h-3 w-3" />
          未承認
        </Badge>
      </div>
    )
  }

  // 日本時間（JST）で承認日を取得
  const approvalUTC = new Date(approvalDate)
  const approvalJST = new Date(approvalUTC.toLocaleString('en-US', { timeZone: 'Asia/Tokyo' }))
  const approvalDay = approvalJST.getDate()
  const approvalMonth = approvalJST.getMonth()
  const approvalYear = approvalJST.getFullYear()

  // 運用開始日の計算（日本時間基準）
  let operationStart: Date
  if (approvalDay <= 5) {
    // 5日までに承認 → 当月15日より運用開始
    operationStart = new Date(approvalYear, approvalMonth, 15)
  } else if (approvalDay <= 20) {
    // 20日までに承認 → 翌月1日より運用開始
    operationStart = new Date(approvalYear, approvalMonth + 1, 1)
  } else {
    // 20日以降に承認 → 翌々月1日より運用開始
    operationStart = new Date(approvalYear, approvalMonth + 2, 1)
  }

  // 今日の日付（日本時間）
  const todayUTC = new Date()
  const todayJST = new Date(todayUTC.toLocaleString('en-US', { timeZone: 'Asia/Tokyo' }))

  // 日付のみで比較（時間を無視）
  const approvalDateOnly = new Date(approvalYear, approvalMonth, approvalDay)
  const operationStartDateOnly = new Date(operationStart.getFullYear(), operationStart.getMonth(), operationStart.getDate())
  const todayDateOnly = new Date(todayJST.getFullYear(), todayJST.getMonth(), todayJST.getDate())
  
  const isOperating = todayDateOnly >= operationStartDateOnly
  const daysUntilStart = Math.ceil((operationStartDateOnly.getTime() - todayDateOnly.getTime()) / (1000 * 60 * 60 * 24))
  
  // システム準備中フラグ（実際の運用開始まで）
  const isSystemPreparing = process.env.NEXT_PUBLIC_SYSTEM_PREPARING === 'true'
  
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('ja-JP', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric'
    })
  }

  if (variant === "compact") {
    return (
      <div className="text-xs">
        {isSystemPreparing ? (
          <span className="text-blue-600 font-medium">準備中</span>
        ) : isOperating ? (
          <span className="text-green-600 font-medium">運用中</span>
        ) : (
          <span className="text-orange-600">{formatDate(operationStart)}開始</span>
        )}
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <CalendarDays className="h-4 w-4 text-gray-300" />
        <span className="text-sm font-medium text-white">運用ステータス</span>
      </div>
      
      <div className="flex items-center gap-3">
        {isSystemPreparing ? (
          <>
            <Badge variant="outline" className="border-blue-400 text-blue-400 bg-blue-900/20 flex items-center gap-1">
              <AlertCircle className="h-3 w-3" />
              システム準備中
            </Badge>
            <span className="text-sm text-gray-300">
              運用開始予定: {formatDate(operationStart)}
              {isOperating && (
                <span className="text-yellow-400 font-medium ml-1">
                  (15日経過済み)
                </span>
              )}
            </span>
          </>
        ) : isOperating ? (
          <>
            <Badge variant="default" className="bg-green-600 flex items-center gap-1">
              <TrendingUp className="h-3 w-3" />
              運用中
            </Badge>
            <span className="text-sm text-gray-300">
              {formatDate(operationStart)}より運用開始済み
            </span>
          </>
        ) : (
          <>
            <Badge variant="outline" className="border-orange-300 text-orange-300 bg-orange-900/20 flex items-center gap-1">
              <Clock className="h-3 w-3" />
              運用待機中
            </Badge>
            <span className="text-sm text-gray-300">
              {formatDate(operationStart)}より運用開始
              {daysUntilStart > 0 && (
                <span className="text-orange-300 font-medium ml-1">
                  (あと{daysUntilStart}日)
                </span>
              )}
            </span>
          </>
        )}
      </div>
      
      <div className="text-xs text-gray-400">
        承認日: {formatDate(approvalDate)}
      </div>
      
      {isSystemPreparing && (
        <div className="mt-2 p-2 bg-blue-900/20 border border-blue-500/30 rounded-lg">
          <p className="text-xs text-blue-300">
            ※ 現在メインシステムの準備を進めています。運用開始日ルールは適用されますが、実際の運用開始はシステム準備完了後となります。
          </p>
          <p className="text-xs text-green-300 mt-2 font-bold">
            🚀 運用開始日：2025年10月15日
          </p>
          <p className="text-xs text-yellow-300 mt-2 font-semibold">
            ⚠️ 現在、反映テストを行っています。実際の数値ではありません。日利設定をしていって実際に計算が合っているか確認中です。
          </p>
        </div>
      )}
    </div>
  )
}