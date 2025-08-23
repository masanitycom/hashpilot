"use client"

import { useState, useEffect } from "react"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ChevronDown, ChevronRight, Users, TrendingUp, AlertCircle, Layers } from "lucide-react"

interface ReferralNode {
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  level_num: number
  total_investment: number
  nft_count: number
  path: string
  parent_user_id: string | null
  children?: ReferralNode[]
}

interface ReferralStats {
  level1: { count: number; investment: number }
  level2: { count: number; investment: number }
  level3: { count: number; investment: number }
  level4Plus: { count: number; investment: number }
  total: { count: number; investment: number }
}

export function ReferralTreeImproved({ userId }: { userId: string }) {
  const [treeData, setTreeData] = useState<ReferralNode[]>([])
  const [stats, setStats] = useState<ReferralStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [showLevel4Plus, setShowLevel4Plus] = useState(false)
  const [maxLevel, setMaxLevel] = useState(3) // デフォルトはLevel 3まで表示

  const fetchCompleteReferralTree = async () => {
    try {
      setLoading(true)
      setError(null)

      if (!supabase) {
        throw new Error("Supabase client is not configured")
      }

      // 全ユーザーを一度に取得
      const { data: allUsers, error: fetchError } = await supabase
        .from("users")
        .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
        .order("created_at", { ascending: true })

      if (fetchError) {
        throw fetchError
      }

      const treeNodes: ReferralNode[] = []
      const stats: ReferralStats = {
        level1: { count: 0, investment: 0 },
        level2: { count: 0, investment: 0 },
        level3: { count: 0, investment: 0 },
        level4Plus: { count: 0, investment: 0 },
        total: { count: 0, investment: 0 }
      }

      // レベル別にユーザーを収集
      const processedUsers = new Set<string>()
      const levelUsers: Map<number, any[]> = new Map()

      // Level 1
      const level1 = allUsers.filter(u => u.referrer_user_id === userId)
      levelUsers.set(1, level1)

      // Level 2以降を構築
      let currentLevel = 1
      while (currentLevel <= 500) { // 最大500レベルまで
        const parentUsers = levelUsers.get(currentLevel) || []
        if (parentUsers.length === 0) break

        const nextLevelUsers: any[] = []
        for (const parent of parentUsers) {
          const children = allUsers.filter(u => 
            u.referrer_user_id === parent.user_id && 
            !processedUsers.has(u.user_id)
          )
          children.forEach(child => {
            processedUsers.add(child.user_id)
            nextLevelUsers.push(child)
          })
        }

        if (nextLevelUsers.length > 0) {
          levelUsers.set(currentLevel + 1, nextLevelUsers)
        }
        currentLevel++
      }

      // ツリー構造を構築（表示レベルに応じて）
      const buildNode = (user: any, level: number): ReferralNode => {
        const totalPurchases = parseFloat(user.total_purchases) || 0
        const nftCount = Math.floor(totalPurchases / 1100)
        const operationalAmount = nftCount * 1000

        // 統計を更新
        if (totalPurchases > 0) {
          if (level === 1) {
            stats.level1.count++
            stats.level1.investment += operationalAmount
          } else if (level === 2) {
            stats.level2.count++
            stats.level2.investment += operationalAmount
          } else if (level === 3) {
            stats.level3.count++
            stats.level3.investment += operationalAmount
          } else {
            stats.level4Plus.count++
            stats.level4Plus.investment += operationalAmount
          }
          stats.total.count++
          stats.total.investment += operationalAmount
        }

        const node: ReferralNode = {
          user_id: user.user_id,
          email: user.email,
          full_name: user.full_name,
          coinw_uid: user.coinw_uid,
          level_num: level,
          total_investment: operationalAmount,
          nft_count: nftCount,
          path: `Level ${level}`,
          parent_user_id: user.referrer_user_id,
          children: []
        }

        // 子ノードを追加（maxLevelまで）
        if (level < maxLevel || showLevel4Plus) {
          const children = levelUsers.get(level + 1)?.filter(u => u.referrer_user_id === user.user_id) || []
          node.children = children.map(child => buildNode(child, level + 1))
        }

        return node
      }

      // Level 1から開始してツリーを構築
      level1.forEach(user => {
        treeNodes.push(buildNode(user, 1))
      })

      setTreeData(treeNodes)
      setStats(stats)
    } catch (err) {
      console.error("Error fetching referral tree:", err)
      setError(err instanceof Error ? err.message : "Unknown error occurred")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchCompleteReferralTree()
  }, [userId, maxLevel, showLevel4Plus])

  const toggleNode = (nodeId: string) => {
    setExpandedNodes(prev => {
      const newSet = new Set(prev)
      if (newSet.has(nodeId)) {
        newSet.delete(nodeId)
      } else {
        newSet.add(nodeId)
      }
      return newSet
    })
  }

  const renderNode = (node: ReferralNode, depth: number = 0) => {
    const hasChildren = node.children && node.children.length > 0
    const isExpanded = expandedNodes.has(node.user_id)

    return (
      <div key={node.user_id} className={`${depth > 0 ? 'ml-6' : ''}`}>
        <div className="flex items-start space-x-2 py-2">
          {hasChildren && (
            <button
              onClick={() => toggleNode(node.user_id)}
              className="mt-1 text-gray-400 hover:text-white transition-colors"
            >
              {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
            </button>
          )}
          {!hasChildren && <div className="w-4" />}
          
          <div className="flex-1 bg-gray-800 rounded-lg p-3 hover:bg-gray-750 transition-colors">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <Badge 
                  variant="outline" 
                  className={`
                    ${node.level_num === 1 ? 'bg-blue-600' : ''}
                    ${node.level_num === 2 ? 'bg-green-600' : ''}
                    ${node.level_num === 3 ? 'bg-purple-600' : ''}
                    ${node.level_num >= 4 ? 'bg-orange-600' : ''}
                    text-white
                  `}
                >
                  Lv.{node.level_num}
                </Badge>
                <div>
                  <div className="font-semibold text-white">{node.user_id}</div>
                  <div className="text-sm text-gray-300">{node.email}</div>
                </div>
              </div>
              <div className="text-right">
                {node.nft_count > 0 ? (
                  <>
                    <div className="text-lg font-bold text-green-400">${node.total_investment}</div>
                    <div className="text-xs text-gray-400">NFT: {node.nft_count}個</div>
                  </>
                ) : (
                  <div className="text-sm text-gray-500">未購入</div>
                )}
              </div>
            </div>
          </div>
        </div>
        
        {isExpanded && hasChildren && (
          <div className="border-l-2 border-gray-600 ml-2">
            {node.children!.map(child => renderNode(child, depth + 1))}
          </div>
        )}
      </div>
    )
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center justify-center space-x-2">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
            <span className="text-white">紹介ツリーを読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center space-x-2 text-red-400">
            <AlertCircle className="w-5 h-5" />
            <span>エラー: {error}</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="text-white flex items-center">
            <Users className="w-5 h-5 mr-2" />
            紹介ツリー（改善版）
          </CardTitle>
          <div className="flex items-center space-x-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setMaxLevel(maxLevel === 3 ? 10 : 3)}
              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
            >
              <Layers className="w-4 h-4 mr-1" />
              {maxLevel === 3 ? 'Level 10まで表示' : 'Level 3まで表示'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowLevel4Plus(!showLevel4Plus)}
              className="bg-purple-600 hover:bg-purple-700 text-white border-purple-600"
            >
              {showLevel4Plus ? 'Level 4+を非表示' : 'Level 4+を表示'}
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {/* 統計情報 */}
        {stats && (
          <div className="mb-6 grid grid-cols-5 gap-4">
            <div className="bg-gray-700 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold text-blue-400">{stats.level1.count}</div>
              <div className="text-xs text-gray-300">Level 1</div>
              <div className="text-sm text-green-400">${stats.level1.investment}</div>
            </div>
            <div className="bg-gray-700 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold text-green-400">{stats.level2.count}</div>
              <div className="text-xs text-gray-300">Level 2</div>
              <div className="text-sm text-green-400">${stats.level2.investment}</div>
            </div>
            <div className="bg-gray-700 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold text-purple-400">{stats.level3.count}</div>
              <div className="text-xs text-gray-300">Level 3</div>
              <div className="text-sm text-green-400">${stats.level3.investment}</div>
            </div>
            <div className="bg-gray-700 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold text-orange-400">{stats.level4Plus.count}</div>
              <div className="text-xs text-gray-300">Level 4+</div>
              <div className="text-sm text-green-400">${stats.level4Plus.investment}</div>
            </div>
            <div className="bg-gray-700 rounded-lg p-3 text-center border-2 border-yellow-500">
              <div className="text-2xl font-bold text-yellow-400">{stats.total.count}</div>
              <div className="text-xs text-gray-300">合計</div>
              <div className="text-sm text-green-400 font-bold">${stats.total.investment}</div>
            </div>
          </div>
        )}

        {/* ツリー表示 */}
        <div className="max-h-96 overflow-y-auto">
          {treeData.length === 0 ? (
            <div className="text-center py-8 text-gray-400">
              <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>紹介者がいません</p>
            </div>
          ) : (
            <div className="space-y-1">
              {treeData.map(node => renderNode(node))}
            </div>
          )}
        </div>

        {/* レベル4+の詳細情報 */}
        {stats && stats.level4Plus.count > 0 && (
          <div className="mt-4 p-3 bg-orange-900 bg-opacity-20 rounded-lg border border-orange-600">
            <div className="flex items-center space-x-2 text-orange-400">
              <AlertCircle className="w-4 h-4" />
              <span className="text-sm">
                Level 4以降に{stats.level4Plus.count}人（${stats.level4Plus.investment}）の紹介者がいます
              </span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}