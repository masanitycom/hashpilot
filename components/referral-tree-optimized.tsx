"use client"

import { useState, useEffect, useCallback, useMemo, memo } from "react"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ChevronDown, ChevronRight, Users, TrendingUp, AlertCircle, Loader2 } from "lucide-react"

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

interface ReferralTreeProps {
  userId: string
}

// メモ化されたツリーノードコンポーネント
const TreeNode = memo(({ 
  node, 
  isExpanded, 
  onToggle,
  isMobile 
}: { 
  node: ReferralNode
  isExpanded: boolean
  onToggle: () => void
  isMobile: boolean
}) => {
  const hasChildren = node.children && node.children.length > 0
  const levelColors = ["bg-blue-600", "bg-green-600", "bg-purple-600", "bg-orange-600"]
  const bgColor = levelColors[node.level_num - 1] || "bg-gray-600"

  return (
    <div className="mb-2">
      <div 
        className={`flex items-center justify-between p-2 md:p-3 rounded-lg bg-gray-800 border border-gray-700 ${
          hasChildren ? 'cursor-pointer hover:bg-gray-750' : ''
        }`}
        onClick={hasChildren ? onToggle : undefined}
      >
        <div className="flex items-center space-x-2 flex-1 min-w-0">
          {hasChildren && (
            <button className="p-1" aria-label="Toggle">
              {isExpanded ? 
                <ChevronDown className="h-4 w-4 text-gray-400" /> : 
                <ChevronRight className="h-4 w-4 text-gray-400" />
              }
            </button>
          )}
          {!hasChildren && <div className="w-6" />}
          
          <div className={`px-2 py-1 rounded text-white text-xs font-medium ${bgColor}`}>
            L{node.level_num}
          </div>
          
          <div className="flex-1 min-w-0">
            <div className="flex items-center space-x-2">
              <span className="text-white font-medium text-sm truncate">
                {node.user_id}
              </span>
              {node.nft_count > 0 && (
                <span className="text-green-400 text-xs">
                  {node.nft_count} NFT
                </span>
              )}
            </div>
            {!isMobile && (
              <div className="text-gray-400 text-xs truncate">
                {node.email}
              </div>
            )}
          </div>
        </div>
        
        {!isMobile && (
          <div className="text-right ml-2">
            <div className="text-green-400 font-semibold text-sm">
              ${(node.total_investment || 0).toLocaleString()}
            </div>
            {hasChildren && (
              <div className="text-gray-400 text-xs">
                {node.children?.length} 人
              </div>
            )}
          </div>
        )}
      </div>
      
      {isExpanded && hasChildren && (
        <div className="ml-4 md:ml-6 mt-1">
          <MemoizedTreeNodeList 
            nodes={node.children || []} 
            isMobile={isMobile}
          />
        </div>
      )}
    </div>
  )
})

TreeNode.displayName = 'TreeNode'

// メモ化されたツリーノードリスト
const MemoizedTreeNodeList = memo(({ 
  nodes, 
  isMobile 
}: { 
  nodes: ReferralNode[]
  isMobile: boolean 
}) => {
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  
  const toggleNode = useCallback((nodeId: string) => {
    setExpandedNodes(prev => {
      const newSet = new Set(prev)
      if (newSet.has(nodeId)) {
        newSet.delete(nodeId)
      } else {
        newSet.add(nodeId)
      }
      return newSet
    })
  }, [])

  return (
    <>
      {nodes.map(node => (
        <TreeNode
          key={node.user_id}
          node={node}
          isExpanded={expandedNodes.has(node.user_id)}
          onToggle={() => toggleNode(node.user_id)}
          isMobile={isMobile}
        />
      ))}
    </>
  )
})

MemoizedTreeNodeList.displayName = 'MemoizedTreeNodeList'

export function ReferralTreeOptimized({ userId }: ReferralTreeProps) {
  const [treeData, setTreeData] = useState<ReferralNode[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isMobile, setIsMobile] = useState(false)
  const [showTree, setShowTree] = useState(false)
  const [showDescription, setShowDescription] = useState(true)

  useEffect(() => {
    const checkIsMobile = () => {
      if (typeof window !== 'undefined') {
        setIsMobile(window.innerWidth < 768)
      }
    }
    
    checkIsMobile()
    
    if (typeof window !== 'undefined') {
      const handleResize = () => setIsMobile(window.innerWidth < 768)
      window.addEventListener("resize", handleResize)
      return () => window.removeEventListener("resize", handleResize)
    }
  }, [])

  const fetchReferralTree = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)

      // 一度のクエリで全ユーザーを取得（最適化）
      const { data: allUsers, error: fetchError } = await supabase
        .from("users")
        .select("user_id, email, full_name, coinw_uid, total_purchases, referrer_user_id")
        .gt("total_purchases", 0)

      if (fetchError) throw fetchError

      if (!allUsers || allUsers.length === 0) {
        setTreeData([])
        return
      }

      // メモリ上でツリーを構築（クエリを繰り返さない）
      const userMap = new Map<string, ReferralNode>()
      const rootNodes: ReferralNode[] = []

      // まず全ノードを作成
      allUsers.forEach(user => {
        const totalPurchases = parseFloat(user.total_purchases) || 0
        const nftCount = Math.floor(totalPurchases / 1100)
        const operationalAmount = nftCount * 1000

        const node: ReferralNode = {
          user_id: user.user_id,
          email: user.email,
          full_name: user.full_name,
          coinw_uid: user.coinw_uid,
          level_num: 0, // 後で計算
          total_investment: operationalAmount,
          nft_count: nftCount,
          path: user.user_id,
          parent_user_id: user.referrer_user_id,
          children: []
        }

        userMap.set(user.user_id, node)
      })

      // 親子関係を構築しつつ、レベルを計算
      const calculateLevel = (node: ReferralNode, currentUserId: string, level: number = 1): number => {
        if (node.parent_user_id === currentUserId) {
          node.level_num = level
          return level
        }
        if (node.parent_user_id && userMap.has(node.parent_user_id)) {
          const parent = userMap.get(node.parent_user_id)!
          const parentLevel = calculateLevel(parent, currentUserId, level)
          if (parentLevel > 0) {
            node.level_num = parentLevel + 1
            return parentLevel + 1
          }
        }
        return 0
      }

      // ユーザーIDから直接の子を見つける
      userMap.forEach(node => {
        const level = calculateLevel(node, userId)
        if (level === 1) {
          rootNodes.push(node)
        } else if (level > 1 && level <= 3 && node.parent_user_id) {
          const parent = userMap.get(node.parent_user_id)
          if (parent && parent.level_num < 3) {
            parent.children = parent.children || []
            parent.children.push(node)
          }
        }
      })

      // レベルでソート
      const sortNodes = (nodes: ReferralNode[]) => {
        nodes.sort((a, b) => b.total_investment - a.total_investment)
        nodes.forEach(node => {
          if (node.children && node.children.length > 0) {
            sortNodes(node.children)
          }
        })
      }

      sortNodes(rootNodes)
      setTreeData(rootNodes)

    } catch (err) {
      console.error("Error fetching referral tree:", err)
      setError(err instanceof Error ? err.message : "Unknown error occurred")
    } finally {
      setLoading(false)
    }
  }, [userId])

  // 統計情報の計算（メモ化）
  const stats = useMemo(() => {
    let totalReferrals = 0
    let totalInvestment = 0
    const levelCounts = [0, 0, 0]

    const countNodes = (nodes: ReferralNode[]) => {
      nodes.forEach(node => {
        totalReferrals++
        totalInvestment += node.total_investment
        if (node.level_num <= 3) {
          levelCounts[node.level_num - 1]++
        }
        if (node.children) {
          countNodes(node.children)
        }
      })
    }

    countNodes(treeData)

    return { totalReferrals, totalInvestment, levelCounts }
  }, [treeData])

  // 初期表示は「表示」ボタンのみ
  if (!showTree) {
    return (
      <Card className="bg-gray-900 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-lg text-white flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Users className="h-5 w-5 text-blue-400" />
              <span>紹介ネットワーク</span>
            </div>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {/* 説明文 */}
          {showDescription && (
            <div className="mb-4 p-3 bg-blue-900/20 border border-blue-600/30 rounded-lg">
              <div className="flex items-start space-x-2">
                <div className="text-blue-400 text-sm flex-shrink-0 mt-0.5">ℹ️</div>
                <div className="text-blue-200 text-sm leading-relaxed">
                  <p className="mb-2">紹介ネットワークは<span className="font-semibold text-blue-100">自身より三段目まで</span>が表示されます。</p>
                  <div className="text-xs text-blue-300 space-y-1 mb-2">
                    <div>・Lv.1: あなたが直接紹介した方</div>
                    <div>・Lv.2: Lv.1の方が紹介した方</div>
                    <div>・Lv.3: Lv.2の方が紹介した方</div>
                  </div>
                  <button 
                    onClick={() => setShowDescription(false)}
                    className="text-xs text-blue-400 hover:text-blue-300 underline"
                  >
                    非表示にする
                  </button>
                </div>
              </div>
            </div>
          )}
          
          <div className="text-center py-6">
            <p className="text-gray-400 mb-4">
              紹介ネットワークを表示するには、下のボタンをクリックしてください
            </p>
            <Button
              onClick={() => {
                setShowTree(true)
                fetchReferralTree()
              }}
              className="bg-blue-600 hover:bg-blue-700 text-white"
            >
              <Users className="h-4 w-4 mr-2" />
              組織図を表示
            </Button>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (loading) {
    return (
      <Card className="bg-gray-900 border-gray-700">
        <CardContent className="py-8">
          <div className="flex flex-col items-center justify-center">
            <Loader2 className="h-8 w-8 text-blue-400 animate-spin mb-4" />
            <p className="text-gray-400">組織図を読み込み中...</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="bg-gray-900 border-gray-700">
        <CardContent className="py-8">
          <div className="flex flex-col items-center justify-center text-center">
            <AlertCircle className="h-8 w-8 text-red-400 mb-4" />
            <p className="text-red-400 mb-4">エラーが発生しました</p>
            <Button 
              onClick={fetchReferralTree}
              className="bg-blue-600 hover:bg-blue-700 text-white"
            >
              再試行
            </Button>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-900 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-lg text-white flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Users className="h-5 w-5 text-blue-400" />
            <span>紹介ネットワーク</span>
          </div>
          <Button
            onClick={() => setShowTree(false)}
            size="sm"
            variant="outline"
            className="text-gray-400 border-gray-600"
          >
            閉じる
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent>
        {/* 統計サマリー */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mb-4">
          <div className="bg-gray-800 rounded-lg p-2 text-center">
            <div className="text-xs text-gray-400">総紹介数</div>
            <div className="text-lg font-bold text-white">{stats.totalReferrals}</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-2 text-center">
            <div className="text-xs text-gray-400">総投資額</div>
            <div className="text-lg font-bold text-green-400">
              ${(stats.totalInvestment || 0).toLocaleString()}
            </div>
          </div>
          <div className="bg-gray-800 rounded-lg p-2 text-center">
            <div className="text-xs text-gray-400">L1: {stats.levelCounts[0]}人</div>
            <div className="text-xs text-gray-400">L2: {stats.levelCounts[1]}人</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-2 text-center">
            <div className="text-xs text-gray-400">L3: {stats.levelCounts[2]}人</div>
            <div className="text-xs text-gray-400">　</div>
          </div>
        </div>

        {/* ツリー表示 */}
        <div className="max-h-96 overflow-y-auto">
          {treeData.length > 0 ? (
            <MemoizedTreeNodeList nodes={treeData} isMobile={isMobile} />
          ) : (
            <div className="text-center py-8 text-gray-400">
              まだ紹介者がいません
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}