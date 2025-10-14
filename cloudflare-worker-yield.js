// Cloudflare Worker for hashpilot.biz/yield
// このコードをCloudflare Workerにデプロイするだけ

const HTML_CONTENT = `<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HASH PILOT - 運用実績</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', sans-serif;
            background: #000000;
            min-height: 100vh;
            padding: 16px;
            color: #ffffff;
        }
        .container {
            max-width: 100%;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            color: #ffffff;
            margin-bottom: 24px;
            font-size: 1.75rem;
            font-weight: 700;
            letter-spacing: -0.5px;
        }
        .loading {
            text-align: center;
            color: #888888;
            font-size: 1rem;
            padding: 40px 20px;
        }
        .error {
            background: #dc2626;
            color: white;
            padding: 16px;
            border-radius: 12px;
            text-align: center;
            margin: 16px 0;
            font-size: 0.9rem;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: #1a1a1a;
            padding: 16px;
            border-radius: 12px;
            border: 1px solid #2a2a2a;
        }
        .stat-card h3 {
            color: #888888;
            font-size: 0.75rem;
            margin-bottom: 8px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-weight: 600;
        }
        .stat-card .value {
            font-size: 1.5rem;
            font-weight: 700;
            color: #ffffff;
        }
        .stat-card .positive {
            color: #22c55e;
        }
        .stat-card .negative {
            color: #ef4444;
        }
        .table-wrapper {
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
        }
        table {
            width: 100%;
            background: #1a1a1a;
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid #2a2a2a;
            border-collapse: separate;
            border-spacing: 0;
        }
        thead {
            background: #0a0a0a;
        }
        th {
            padding: 12px 8px;
            text-align: left;
            font-weight: 600;
            font-size: 0.75rem;
            color: #888888;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 1px solid #2a2a2a;
        }
        td {
            padding: 12px 8px;
            text-align: left;
            font-size: 0.875rem;
            border-bottom: 1px solid #2a2a2a;
        }
        tbody tr:last-child td {
            border-bottom: none;
        }
        tbody tr {
            transition: background-color 0.15s;
        }
        tbody tr:active {
            background-color: #222222;
        }
        .positive-value {
            color: #22c55e;
            font-weight: 600;
        }
        .negative-value {
            color: #ef4444;
            font-weight: 600;
        }
        .date-cell {
            font-weight: 600;
            color: #ffffff;
            white-space: nowrap;
        }

        /* スマホ最適化 */
        @media (max-width: 640px) {
            body {
                padding: 12px;
            }
            h1 {
                font-size: 1.5rem;
                margin-bottom: 20px;
            }
            .stats {
                gap: 10px;
                margin-bottom: 20px;
            }
            .stat-card {
                padding: 12px;
            }
            .stat-card h3 {
                font-size: 0.7rem;
            }
            .stat-card .value {
                font-size: 1.25rem;
            }
            th {
                padding: 10px 6px;
                font-size: 0.7rem;
            }
            td {
                padding: 10px 6px;
                font-size: 0.8rem;
            }
        }

        /* 超小型デバイス */
        @media (max-width: 380px) {
            h1 {
                font-size: 1.25rem;
            }
            .stats {
                grid-template-columns: 1fr;
            }
            th, td {
                padding: 8px 4px;
                font-size: 0.75rem;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 HASH PILOT 運用実績</h1>
        <div class="stats" id="stats"></div>
        <div id="loading" class="loading">データを読み込み中...</div>
        <div id="error" class="error" style="display: none;">データの取得に失敗しました</div>
        <div class="table-wrapper">
            <table id="yieldTable" style="display: none;">
                <thead>
                    <tr>
                        <th>日付</th>
                        <th>日利率 (%)</th>
                        <th>ユーザー受取率 (%)</th>
                        <th>増加率 (%)</th>
                    </tr>
                </thead>
                <tbody id="tableBody"></tbody>
            </table>
        </div>
    </div>
    <script>
        const API_URL = 'https://soghqozaxfswtxxbgeer.supabase.co/functions/v1/get-daily-yields';

        async function loadYieldData() {
            try {
                const response = await fetch(API_URL + '?limit=30');

                // データがない場合（401, 404など）は空データを表示
                if (!response.ok) {
                    console.warn('API Error:', response.status);
                    showNoData();
                    return;
                }

                const result = await response.json();

                if (!result.success || !result.data || result.data.length === 0) {
                    showNoData();
                    return;
                }

                displayData(result.data);
                displayStats(result.data);
            } catch (error) {
                console.error('Error:', error);
                showNoData();
            }
        }

        function showNoData() {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('error').style.display = 'block';
            document.getElementById('error').style.background = '#1a1a1a';
            document.getElementById('error').style.border = '1px solid #2a2a2a';
            document.getElementById('error').textContent = '📊 まだ日利データがありません。日利設定後にデータが表示されます。';
        }

        function displayStats(data) {
            const statsDiv = document.getElementById('stats');
            const totalRecords = data.length;
            const positiveCount = data.filter(d => d.yield_rate > 0).length;
            const negativeCount = data.filter(d => d.yield_rate < 0).length;
            const avgYieldRate = (data.reduce((sum, d) => sum + d.yield_rate, 0) / totalRecords).toFixed(3);
            const avgUserRate = (data.reduce((sum, d) => sum + d.user_rate, 0) / totalRecords * 100).toFixed(3);
            statsDiv.innerHTML = \`
                <div class="stat-card"><h3>総レコード数</h3><div class="value">\${totalRecords}</div></div>
                <div class="stat-card"><h3>プラス日数</h3><div class="value positive">\${positiveCount}日</div></div>
                <div class="stat-card"><h3>マイナス日数</h3><div class="value negative">\${negativeCount}日</div></div>
                <div class="stat-card"><h3>平均日利率</h3><div class="value \${avgYieldRate > 0 ? 'positive' : 'negative'}">\${avgYieldRate > 0 ? '+' : ''}\${avgYieldRate}%</div></div>
                <div class="stat-card"><h3>平均ユーザー受取率</h3><div class="value">\${avgUserRate}%</div></div>
            \`;
        }

        function displayData(data) {
            const tableBody = document.getElementById('tableBody');
            const loading = document.getElementById('loading');
            const table = document.getElementById('yieldTable');
            loading.style.display = 'none';
            table.style.display = 'table';
            tableBody.innerHTML = data.map(item => {
                const yieldClass = item.yield_rate > 0 ? 'positive-value' : 'negative-value';
                const yieldSign = item.yield_rate > 0 ? '+' : '';
                return \`
                    <tr>
                        <td class="date-cell">\${formatDate(item.date)}</td>
                        <td class="\${yieldClass}">\${yieldSign}\${item.yield_rate.toFixed(3)}%</td>
                        <td>\${item.profit_percentage}%</td>
                        <td class="\${yieldClass}">\${yieldSign}\${item.profit_percentage}%</td>
                    </tr>
                \`;
            }).join('');
        }

        function formatDate(dateString) {
            const date = new Date(dateString);
            return date.toLocaleDateString('ja-JP', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit'
            });
        }

        loadYieldData();
    </script>
</body>
</html>`;

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // ルート (/) または /yield にアクセスした場合にHTMLを返す
    if (url.pathname === '/' || url.pathname === '/yield' || url.pathname === '/yield/') {
      return new Response(HTML_CONTENT, {
        headers: {
          'content-type': 'text/html;charset=UTF-8',
        },
      });
    }

    // その他のパスは404
    return new Response('Not Found', { status: 404 });
  },
};
